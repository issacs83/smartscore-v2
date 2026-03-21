/// Abstract interface for device adapters.
///
/// Each device type (Bluetooth, keyboard, MIDI) implements this interface
/// to provide a consistent API for scanning, connecting, and receiving events.

import 'device_action.dart';

/// Error codes for device operations.
enum DeviceErrorCode {
  /// Bluetooth/device connectivity not available on platform
  bluetoothNotAvailable,

  /// User permission denied for device access
  permissionsDenied,

  /// Device not found in discovered or connected list
  deviceNotFound,

  /// Connection attempt timed out
  connectionTimeout,

  /// Device explicitly rejected connection/pairing
  connectionRejected,

  /// Connection failed for other reasons
  connectionFailed,

  /// Device does not support required protocol
  deviceNotCompatible,

  /// Generic error
  unknown,
}

/// Exception for device operation failures.
class DeviceException implements Exception {
  /// Error code categorizing the failure.
  final DeviceErrorCode code;

  /// Human-readable error message.
  final String message;

  /// Optional underlying exception.
  final Exception? cause;

  DeviceException({
    required this.code,
    required this.message,
    this.cause,
  });

  @override
  String toString() => 'DeviceException($code): $message';
}

/// Abstract base class for device adapters.
///
/// Implementations handle specific device types (Bluetooth, keyboard, MIDI)
/// and translate their native events into [DeviceEvent] objects.
abstract class DeviceAdapter {
  /// The type of device this adapter handles.
  DeviceType get deviceType;

  /// Stream of events from this adapter.
  ///
  /// Emits [DeviceEvent] whenever input is received from any connected device.
  /// May emit events before [connect] is called if the adapter auto-discovers devices.
  Stream<DeviceEvent> get onEvent;

  /// Scan for discoverable devices.
  ///
  /// Returns a stream that emits [DeviceInfo] for each discovered device.
  /// Scanning stops automatically after 30 seconds or can be cancelled via subscription.
  ///
  /// Throws [DeviceException] if:
  /// - Device connectivity not available
  /// - User permission denied
  /// - Already scanning
  Stream<DeviceInfo> scan();

  /// Connect to a device by ID.
  ///
  /// Attempts to establish connection to [deviceId].
  /// On success, the adapter begins emitting events for this device via [onEvent].
  ///
  /// Returns [DeviceInfo] if successful.
  /// Throws [DeviceException] if connection fails.
  Future<DeviceInfo> connect(String deviceId);

  /// Disconnect from a device.
  ///
  /// Closes the connection to [deviceId] and stops emitting events for this device.
  /// Returns true if the device was connected and has been disconnected,
  /// false if the device was not connected.
  Future<bool> disconnect(String deviceId);

  /// Get list of currently connected devices managed by this adapter.
  List<DeviceInfo> getConnectedDevices();

  /// Clean up resources used by this adapter.
  ///
  /// Called when the adapter is no longer needed.
  /// Should disconnect all devices and close streams.
  Future<void> dispose();
}
