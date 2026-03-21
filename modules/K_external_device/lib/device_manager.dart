/// Central orchestrator for multiple device adapters.
///
/// Manages connections to multiple device types (Bluetooth, keyboard, MIDI)
/// and filters/prioritizes their inputs using [InputPrioritizer].

import 'dart:async';
import 'device_action.dart';
import 'device_adapter.dart';
import 'input_prioritizer.dart';

/// Manages all connected devices and their input streams.
///
/// Orchestrates multiple [DeviceAdapter] instances, applies priority
/// and debounce filtering, and provides unified access to device actions.
class DeviceManager {
  final Map<DeviceType, DeviceAdapter> _adapters;
  final InputPrioritizer _prioritizer;
  final Map<String, DeviceInfo> _connectedDevices = {};

  StreamController<DeviceAction>? _actionController;
  StreamSubscription<DeviceAction>? _prioritizerSubscription;

  /// Create a new device manager.
  ///
  /// [adapters] maps device types to their adapter implementations.
  /// [logger] is used for logging decisions (optional).
  DeviceManager({
    required Map<DeviceType, DeviceAdapter> adapters,
    PrioritizerLogger? logger,
  })
      : _adapters = adapters,
        _prioritizer = InputPrioritizer(logger: logger) {
    _initializeActionStream();
  }

  void _initializeActionStream() {
    _actionController = StreamController<DeviceAction>.broadcast();

    // Wire up the prioritizer stream to the action controller
    _prioritizerSubscription =
        _prioritizer.onAction.listen(_actionController!.add);

    // Wire up all adapters to the prioritizer
    for (final adapter in _adapters.values) {
      adapter.onEvent.listen(_prioritizer.processEvent);
    }
  }

  /// Stream of processed device actions.
  ///
  /// Emits [DeviceAction] for inputs from all connected devices,
  /// with debounce and priority filtering applied.
  Stream<DeviceAction> get onAction => _actionController!.stream;

  /// Scan for devices of a specific type.
  ///
  /// Returns a stream of discovered [DeviceInfo].
  /// Throws [DeviceException] if scanning fails.
  Stream<DeviceInfo> scan(DeviceType deviceType) {
    final adapter = _adapters[deviceType];
    if (adapter == null) {
      throw DeviceException(
        code: DeviceErrorCode.unknown,
        message: 'No adapter registered for device type $deviceType',
      );
    }
    return adapter.scan();
  }

  /// Connect to a specific device.
  ///
  /// [deviceType] specifies which adapter to use.
  /// [deviceId] is the device identifier from scanning.
  ///
  /// Returns [DeviceInfo] if successful.
  /// Throws [DeviceException] if connection fails.
  Future<DeviceInfo> connect(
    DeviceType deviceType,
    String deviceId,
  ) async {
    final adapter = _adapters[deviceType];
    if (adapter == null) {
      throw DeviceException(
        code: DeviceErrorCode.unknown,
        message: 'No adapter registered for device type $deviceType',
      );
    }

    try {
      final deviceInfo = await adapter.connect(deviceId);
      _connectedDevices['${deviceType.name}:$deviceId'] = deviceInfo;
      return deviceInfo;
    } catch (e) {
      rethrow;
    }
  }

  /// Disconnect from a specific device.
  ///
  /// Returns true if the device was connected and is now disconnected,
  /// false if the device was not connected.
  Future<bool> disconnect(
    DeviceType deviceType,
    String deviceId,
  ) async {
    final adapter = _adapters[deviceType];
    if (adapter == null) {
      return false;
    }

    try {
      final result = await adapter.disconnect(deviceId);
      if (result) {
        _connectedDevices.remove('${deviceType.name}:$deviceId');
      }
      return result;
    } catch (e) {
      return false;
    }
  }

  /// Get all currently connected devices.
  ///
  /// Returns a list sorted by last seen time (most recent first).
  List<DeviceInfo> getConnectedDevices() {
    final devices = _connectedDevices.values.toList();
    devices.sort((a, b) {
      final timeA = a.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
      final timeB = b.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
      return timeB.compareTo(timeA); // Most recent first
    });
    return devices;
  }

  /// Get information about a specific connected device.
  DeviceInfo? getDevice(DeviceType deviceType, String deviceId) {
    return _connectedDevices['${deviceType.name}:$deviceId'];
  }

  /// Dispose of all resources.
  ///
  /// Closes all adapter connections and streams.
  Future<void> dispose() async {
    await _prioritizerSubscription?.cancel();
    await _actionController?.close();
    await _prioritizer.dispose();

    for (final adapter in _adapters.values) {
      await adapter.dispose();
    }

    _connectedDevices.clear();
  }
}
