/// Core types for external device integration module.
///
/// Defines the action enum, device types, and event/info data structures
/// used throughout the device management system.

/// High-level actions that external devices can trigger.
enum DeviceAction {
  /// Turn page backward
  previousPage,

  /// Turn page forward
  nextPage,

  /// Hold current page (stop auto-advance)
  hold,

  /// Sync playback position
  syncMarker,
}

/// Supported external device types.
enum DeviceType {
  /// Bluetooth HID pedal (page turner)
  bluetoothPedal,

  /// MIDI controller
  midiController,

  /// Keyboard input
  keyboard,

  /// Touch/UI input (highest priority)
  touch,
}

/// An event from an external device.
///
/// Contains the action triggered, the device source, timestamp,
/// and optional raw data for debugging or advanced processing.
class DeviceEvent {
  /// The action triggered by this event.
  final DeviceAction action;

  /// The type of device that generated this event.
  final DeviceType source;

  /// When this event occurred.
  final DateTime timestamp;

  /// Optional raw event data from the device (e.g., HID report, MIDI CC value).
  /// For Bluetooth: HID report data
  /// For MIDI: {cc: int, value: int, channel: int}
  /// For keyboard: {keyCode: int, state: String}
  final Map<String, dynamic>? rawData;

  /// Creates a new device event.
  DeviceEvent({
    required this.action,
    required this.source,
    required this.timestamp,
    this.rawData,
  });

  @override
  String toString() => 'DeviceEvent(action: $action, source: $source, '
      'timestamp: ${timestamp.toIso8601String()}, rawData: $rawData)';
}

/// Information about a connected or discovered device.
///
/// Represents a device's metadata and connection state.
class DeviceInfo {
  /// Unique identifier for the device (MAC address, UUID, or platform-specific ID).
  final String id;

  /// Human-readable device name.
  final String name;

  /// Type of device.
  final DeviceType type;

  /// Whether the device is currently connected.
  final bool isConnected;

  /// Battery level in percent (0-100), null if not supported.
  final int? batteryLevel;

  /// When the device was last seen or interacted with.
  final DateTime? lastSeen;

  /// Creates a new device info object.
  DeviceInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.isConnected,
    this.batteryLevel,
    this.lastSeen,
  });

  @override
  String toString() =>
      'DeviceInfo(id: $id, name: $name, type: $type, isConnected: $isConnected, '
      'batteryLevel: $batteryLevel, lastSeen: $lastSeen)';
}
