/// Bluetooth HID device adapter.
///
/// Handles discovery and connection to Bluetooth page turner pedals and similar
/// HID devices. Maps common device profiles (AirTurn, PageFlip, generic HID)
/// to standard actions.

import 'dart:async';
import 'device_action.dart';
import 'device_adapter.dart';

/// Configuration for a Bluetooth device profile.
class BluetoothProfile {
  final String name;
  final List<String> namePatterns;
  final Map<int, DeviceAction> buttonMapping;

  const BluetoothProfile({
    required this.name,
    required this.namePatterns,
    required this.buttonMapping,
  });
}

/// Known Bluetooth device profiles.
final bluetoothProfiles = [
  BluetoothProfile(
    name: 'AirTurn',
    namePatterns: ['*AirTurn*', '*air turn*'],
    buttonMapping: {
      // Arrow keys from AirTurn: up=prev, down=next
      0: DeviceAction.previousPage,
      1: DeviceAction.nextPage,
      2: DeviceAction.hold,
    },
  ),
  BluetoothProfile(
    name: 'PageFlip',
    namePatterns: ['*PageFlip*', '*page flip*'],
    buttonMapping: {
      // Left/Right buttons: left=prev, right=next
      0: DeviceAction.previousPage,
      1: DeviceAction.nextPage,
      2: DeviceAction.hold,
    },
  ),
];

/// Abstract interface for Bluetooth operations (for testability).
abstract class BluetoothService {
  /// Start scanning for Bluetooth devices.
  Stream<BluetoothScanResult> startScan({Duration timeout = const Duration(seconds: 30)});

  /// Connect to a device.
  Future<BluetoothConnection> connect(String deviceId);

  /// Disconnect from a device.
  Future<void> disconnect(String deviceId);

  /// Check if Bluetooth is available.
  Future<bool> isAvailable();

  /// Request Bluetooth permission.
  Future<bool> requestPermission();
}

/// Result from a Bluetooth scan.
class BluetoothScanResult {
  final String id;
  final String name;
  final int rssi;
  final List<String> advertisedServices;
  final bool bonded;

  BluetoothScanResult({
    required this.id,
    required this.name,
    required this.rssi,
    required this.advertisedServices,
    required this.bonded,
  });
}

/// Active Bluetooth connection.
class BluetoothConnection {
  final String deviceId;
  final String deviceName;
  final Stream<List<int>> characteristicUpdates;

  BluetoothConnection({
    required this.deviceId,
    required this.deviceName,
    required this.characteristicUpdates,
  });
}

/// Adapter for Bluetooth HID devices.
///
/// Wraps platform-specific Bluetooth APIs (flutter_blue_plus on mobile,
/// platform channels) and translates HID reports into [DeviceEvent].
class BluetoothAdapter implements DeviceAdapter {
  final BluetoothService _bluetoothService;
  final StreamController<DeviceEvent> _eventController;
  final Map<String, BluetoothConnection> _activeConnections = {};
  final Map<String, StreamSubscription<List<int>>> _connectionSubscriptions = {};
  final Map<String, DeviceInfo> _discoveredDevices = {};
  final Map<String, ({DateTime time, DeviceAction action})> _lastEventPerDevice = {};

  /// Debounce window for Bluetooth HID reports.
  static const debounceWindow = Duration(milliseconds: 100);

  /// Auto-reconnect configuration.
  static const maxReconnectAttempts = 3;

  BluetoothAdapter({BluetoothService? bluetoothService})
      : _bluetoothService = bluetoothService ?? _DefaultBluetoothService(),
        _eventController = StreamController<DeviceEvent>.broadcast();

  @override
  DeviceType get deviceType => DeviceType.bluetoothPedal;

  @override
  Stream<DeviceEvent> get onEvent => _eventController.stream;

  @override
  Stream<DeviceInfo> scan() async* {
    // Check if Bluetooth is available
    if (!await _bluetoothService.isAvailable()) {
      throw DeviceException(
        code: DeviceErrorCode.bluetoothNotAvailable,
        message: 'Bluetooth not available on this device',
      );
    }

    // Request permission if needed
    if (!await _bluetoothService.requestPermission()) {
      throw DeviceException(
        code: DeviceErrorCode.permissionsDenied,
        message: 'User denied Bluetooth permission',
      );
    }

    try {
      await for (final result in _bluetoothService.startScan()) {
        // Create device info from scan result
        final deviceInfo = DeviceInfo(
          id: result.id,
          name: result.name.isNotEmpty ? result.name : 'Unknown Device',
          type: DeviceType.bluetoothPedal,
          isConnected: false,
          lastSeen: DateTime.now(),
        );

        _discoveredDevices[result.id] = deviceInfo;
        yield deviceInfo;
      }
    } catch (e) {
      throw DeviceException(
        code: DeviceErrorCode.unknown,
        message: 'Bluetooth scan failed: $e',
        cause: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<DeviceInfo> connect(String deviceId) async {
    // Check if device was discovered
    final discoveredDevice = _discoveredDevices[deviceId];
    if (discoveredDevice == null) {
      throw DeviceException(
        code: DeviceErrorCode.deviceNotFound,
        message: 'Device $deviceId not found in scan results',
      );
    }

    // Already connected
    if (_activeConnections.containsKey(deviceId)) {
      return discoveredDevice.copyWith(isConnected: true);
    }

    try {
      // Attempt connection with retries
      BluetoothConnection? connection;
      DeviceException? lastError;

      for (int attempt = 0; attempt < maxReconnectAttempts; attempt++) {
        try {
          connection = await _bluetoothService.connect(deviceId)
              .timeout(const Duration(seconds: 10));
          break;
        } catch (e) {
          lastError = e is DeviceException
              ? e
              : DeviceException(
                  code: DeviceErrorCode.connectionFailed,
                  message: 'Connection attempt ${attempt + 1} failed: $e',
                  cause: e is Exception ? e : null,
                );

          // Exponential backoff: 1s, 2s, 4s
          if (attempt < maxReconnectAttempts - 1) {
            await Future.delayed(Duration(seconds: 1 << attempt));
          }
        }
      }

      if (connection == null) {
        throw lastError ??
            DeviceException(
              code: DeviceErrorCode.connectionFailed,
              message: 'Failed to connect to $deviceId',
            );
      }

      // Store connection and subscribe to events
      _activeConnections[deviceId] = connection;
      _subscribeToDevice(deviceId, connection);

      return discoveredDevice.copyWith(isConnected: true);
    } catch (e) {
      throw e is DeviceException
          ? e
          : DeviceException(
              code: DeviceErrorCode.connectionFailed,
              message: 'Connection failed: $e',
              cause: e is Exception ? e : null,
            );
    }
  }

  void _subscribeToDevice(String deviceId, BluetoothConnection connection) {
    final subscription = connection.characteristicUpdates.listen(
      (data) => _handleHidReport(deviceId, connection.deviceName, data),
      onError: (error) {
        print('Error on device $deviceId: $error');
        _activeConnections.remove(deviceId);
        _connectionSubscriptions.remove(deviceId);
      },
    );

    _connectionSubscriptions[deviceId] = subscription;
  }

  void _handleHidReport(String deviceId, String deviceName, List<int> report) {
    // Parse HID report - simplified button detection
    // HID reports typically have a byte for button states
    if (report.isEmpty) return;

    final buttonByte = report[0];

    // Check which buttons are pressed
    for (int i = 0; i < 8; i++) {
      if ((buttonByte & (1 << i)) != 0) {
        // Button i is pressed
        final action = _getActionForButton(deviceId, i);
        if (action != null) {
          final now = DateTime.now();

          // Apply debounce: same device, same action
          final lastEvent = _lastEventPerDevice[deviceId];
          if (lastEvent != null &&
              lastEvent.action == action &&
              now.difference(lastEvent.time) < debounceWindow) {
            return; // Debounced
          }

          _lastEventPerDevice[deviceId] = (time: now, action: action);

          _eventController.add(
            DeviceEvent(
              action: action,
              source: DeviceType.bluetoothPedal,
              timestamp: now,
              rawData: {'deviceId': deviceId, 'buttonByte': buttonByte},
            ),
          );
        }
      }
    }
  }

  DeviceAction? _getActionForButton(String deviceId, int buttonIndex) {
    // Try to find device profile from discovered devices
    final device = _discoveredDevices[deviceId];
    if (device != null) {
      // Match against known profiles
      for (final profile in bluetoothProfiles) {
        for (final pattern in profile.namePatterns) {
          if (_matchPattern(device.name, pattern)) {
            return profile.buttonMapping[buttonIndex];
          }
        }
      }
    }

    // Default mapping if no profile matches
    switch (buttonIndex) {
      case 0:
        return DeviceAction.previousPage;
      case 1:
        return DeviceAction.nextPage;
      case 2:
        return DeviceAction.hold;
      default:
        return null;
    }
  }

  bool _matchPattern(String text, String pattern) {
    final regex = pattern
        .replaceAll('.', r'\.')
        .replaceAll('*', '.*');
    return RegExp('^$regex\$', caseSensitive: false).hasMatch(text);
  }

  @override
  Future<bool> disconnect(String deviceId) async {
    final connection = _activeConnections.remove(deviceId);
    final subscription = _connectionSubscriptions.remove(deviceId);

    await subscription?.cancel();
    if (connection != null) {
      await _bluetoothService.disconnect(deviceId);
      return true;
    }
    return false;
  }

  @override
  List<DeviceInfo> getConnectedDevices() {
    return [
      for (final deviceId in _activeConnections.keys)
        _discoveredDevices[deviceId]?.copyWith(isConnected: true) ??
            DeviceInfo(
              id: deviceId,
              name: 'Unknown',
              type: DeviceType.bluetoothPedal,
              isConnected: true,
            ),
    ];
  }

  @override
  Future<void> dispose() async {
    // Disconnect all devices
    final deviceIds = _activeConnections.keys.toList();
    for (final deviceId in deviceIds) {
      await disconnect(deviceId);
    }

    await _eventController.close();
  }
}

/// Default Bluetooth service stub for testing/development.
class _DefaultBluetoothService implements BluetoothService {
  @override
  Stream<BluetoothScanResult> startScan({Duration timeout = const Duration(seconds: 30)}) {
    // Stub implementation - would use flutter_blue_plus in real app
    return Stream.empty();
  }

  @override
  Future<BluetoothConnection> connect(String deviceId) {
    throw UnimplementedError('Use real Bluetooth service implementation');
  }

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> requestPermission() async => false;
}

/// Extension to copy DeviceInfo with modifications.
extension DeviceInfoCopy on DeviceInfo {
  DeviceInfo copyWith({
    String? id,
    String? name,
    DeviceType? type,
    bool? isConnected,
    int? batteryLevel,
    DateTime? lastSeen,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      isConnected: isConnected ?? this.isConnected,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
