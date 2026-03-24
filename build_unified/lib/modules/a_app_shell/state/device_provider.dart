import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../k_external_device/device_manager.dart';
import '../../k_external_device/device_action.dart';

/// Device provider - wraps Module K
class DeviceProvider extends ChangeNotifier {
  final DeviceManager? moduleK;
  List<Map<String, dynamic>> _connectedDevices = [];
  Map<String, dynamic>? _lastAction;
  bool _isScanning = false;
  String? _lastError;

  // Broadcast stream for device actions consumed by UI screens.
  final StreamController<DeviceAction> _actionBroadcast =
      StreamController<DeviceAction>.broadcast();

  /// Stream of device actions (page-turn pedal, MIDI, keyboard).
  Stream<DeviceAction> get onDeviceAction => _actionBroadcast.stream;

  DeviceProvider(this.moduleK);

  // Getters
  List<Map<String, dynamic>> get connectedDevices => _connectedDevices;
  Map<String, dynamic>? get lastAction => _lastAction;
  bool get isScanning => _isScanning;
  String? get lastError => _lastError;

  /// Initialize device listening
  void initialize() {
    if (moduleK == null) {
      debugPrint('[DeviceProvider] Module K not initialized');
      return;
    }

    // Listen to device actions from Module K
    try {
      moduleK!.onAction.listen(
        (action) {
          _lastAction = {
            'type': action.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          };
          debugPrint('[DeviceProvider] Action: $action');
          // Broadcast to subscribers (e.g. ScoreViewerScreen)
          _actionBroadcast.add(action);
          notifyListeners();
        },
        onError: (error) {
          _lastError = error.toString();
          debugPrint('[DeviceProvider] Device stream error: $error');
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('[DeviceProvider] Failed to listen to device actions: $e');
    }
  }

  /// Scan for devices
  Future<void> scanDevices(DeviceType deviceType) async {
    _isScanning = true;
    _lastError = null;
    notifyListeners();

    try {
      if (moduleK == null) {
        throw Exception('Module K not initialized');
      }

      // Scan via Module K
      moduleK!.scan(deviceType).listen(
        (device) {
          // Device found - can be connected by UI
          debugPrint('[DeviceProvider] Found device: ${device.name}');
        },
        onError: (error) {
          _lastError = error.toString();
          notifyListeners();
        },
        onDone: () {
          _isScanning = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _lastError = e.toString();
      _isScanning = false;
      debugPrint('[DeviceProvider] Scan error: $e');
      notifyListeners();
    }
  }

  /// Connect to a device
  Future<bool> connectDevice(DeviceType deviceType, String deviceId) async {
    try {
      if (moduleK == null) {
        throw Exception('Module K not initialized');
      }

      final device = await moduleK!.connect(deviceType, deviceId);
      _connectedDevices.add({
        'id': device.id,
        'name': device.name,
        'type': deviceType.toString(),
        'connectedAt': DateTime.now().toIso8601String(),
      });
      _lastError = null;
      debugPrint('[DeviceProvider] Connected to device: ${device.name}');
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[DeviceProvider] Connection error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Disconnect a device
  Future<bool> disconnectDevice(DeviceType deviceType, String deviceId) async {
    try {
      if (moduleK == null) {
        throw Exception('Module K not initialized');
      }

      final result = await moduleK!.disconnect(deviceType, deviceId);
      if (result) {
        _connectedDevices.removeWhere((d) => d['id'] == deviceId);
        _lastError = null;
        debugPrint('[DeviceProvider] Disconnected device: $deviceId');
        notifyListeners();
      }
      return result;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[DeviceProvider] Disconnect error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Get connected devices
  List<Map<String, dynamic>> getConnectedDevices() {
    try {
      if (moduleK == null) {
        return [];
      }

      final devices = moduleK!.getConnectedDevices();
      return devices
          .map((d) => {
                'id': d.id,
                'name': d.name,
                'type': d.type.toString(),
              })
          .toList();
    } catch (e) {
      debugPrint('[DeviceProvider] getConnectedDevices error: $e');
      return [];
    }
  }

  /// Clear error
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _actionBroadcast.close();
    super.dispose();
  }

  /// Dump state for debugging
  Map<String, dynamic> dumpState() {
    return {
      'connectedDeviceCount': _connectedDevices.length,
      'connectedDevices': _connectedDevices,
      'lastAction': _lastAction,
      'isScanning': _isScanning,
      'lastError': _lastError,
    };
  }
}
