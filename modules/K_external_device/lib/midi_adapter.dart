/// MIDI Control Change adapter.
///
/// Handles MIDI CC events and maps them to device actions.
/// Includes default mappings and user-configurable CC number -> action mapping.

import 'dart:async';
import 'device_action.dart';
import 'device_adapter.dart';

/// MIDI Control Change event.
class MidiCCEvent {
  /// CC number (0-127).
  final int cc;

  /// CC value (0-127).
  final int value;

  /// MIDI channel (1-16).
  final int channel;

  /// Timestamp of the event.
  final DateTime timestamp;

  MidiCCEvent({
    required this.cc,
    required this.value,
    required this.channel,
    required this.timestamp,
  });
}

/// Abstract MIDI service interface (for testability).
abstract class MidiService {
  /// Stream of MIDI CC events.
  Stream<MidiCCEvent> get midiEvents;

  /// Check if MIDI is available on platform.
  Future<bool> isAvailable();

  /// Request MIDI permissions if needed.
  Future<bool> requestPermission();
}

/// Adapter for MIDI input.
///
/// Listens for MIDI CC events and maps them to device actions.
/// Default mappings: CC64 (sustain) = next, CC67 (soft) = prev.
class MidiAdapter implements DeviceAdapter {
  final MidiService _midiService;
  final StreamController<DeviceEvent> _eventController;

  /// Default CC to action mappings.
  /// CC numbers: 64 = sustain pedal, 67 = soft pedal, 102 = custom sync marker
  static const defaultCCMappings = {
    64: DeviceAction.nextPage,   // Sustain pedal
    67: DeviceAction.previousPage, // Soft pedal
    102: DeviceAction.syncMarker,  // Custom MIDI CC
  };

  /// User-configurable CC mappings.
  final Map<int, DeviceAction> ccMappings;

  /// Track last CC event time for debounce.
  final Map<int, DateTime> _lastCCPress = {};

  /// Debounce window for MIDI events.
  static const debounceWindow = Duration(milliseconds: 100);

  /// MIDI device info.
  late final DeviceInfo _midiInfo;

  bool _connected = false;
  StreamSubscription<MidiCCEvent>? _midiSubscription;

  MidiAdapter({
    MidiService? midiService,
    Map<int, DeviceAction>? customCCMappings,
  })
      : _midiService = midiService ?? _DefaultMidiService(),
        ccMappings = {...defaultCCMappings, ...(customCCMappings ?? {})},
        _eventController = StreamController<DeviceEvent>.broadcast() {
    _midiInfo = DeviceInfo(
      id: 'midi:default',
      name: 'MIDI Input',
      type: DeviceType.midiController,
      isConnected: false,
      lastSeen: DateTime.now(),
    );
  }

  @override
  DeviceType get deviceType => DeviceType.midiController;

  @override
  Stream<DeviceEvent> get onEvent => _eventController.stream;

  @override
  Stream<DeviceInfo> scan() async* {
    // Check if MIDI is available
    if (!await _midiService.isAvailable()) {
      throw DeviceException(
        code: DeviceErrorCode.unknown,
        message: 'MIDI not available on this platform',
      );
    }

    // Request permission
    if (!await _midiService.requestPermission()) {
      throw DeviceException(
        code: DeviceErrorCode.permissionsDenied,
        message: 'User denied MIDI permission',
      );
    }

    // MIDI input is always "discovered" when available
    yield _midiInfo;

    // Keep scanning
    while (_connected || !_connected) {
      // Scan indefinitely until cancelled
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  Future<DeviceInfo> connect(String deviceId) async {
    if (deviceId != 'midi:default') {
      throw DeviceException(
        code: DeviceErrorCode.deviceNotFound,
        message: 'Unknown MIDI device: $deviceId',
      );
    }

    if (!await _midiService.isAvailable()) {
      throw DeviceException(
        code: DeviceErrorCode.deviceNotCompatible,
        message: 'MIDI not available on this platform',
      );
    }

    if (!await _midiService.requestPermission()) {
      throw DeviceException(
        code: DeviceErrorCode.permissionsDenied,
        message: 'MIDI permission denied',
      );
    }

    _connected = true;

    // Subscribe to MIDI events if not already subscribed
    if (_midiSubscription == null) {
      _midiSubscription = _midiService.midiEvents.listen(
        _handleMidiEvent,
        onError: (error) {
          print('MIDI event error: $error');
          _midiSubscription = null;
          _connected = false;
        },
      );
    }

    return _midiInfo.copyWith(isConnected: true);
  }

  void _handleMidiEvent(MidiCCEvent event) {
    final action = ccMappings[event.cc];
    if (action == null) {
      return; // Unmapped CC
    }

    // For sustain pedal (CC64), trigger on CC value >= 64
    // For other CCs, trigger on any value > 0
    final shouldTrigger = event.cc == 64 ? event.value >= 64 : event.value > 0;
    if (!shouldTrigger) {
      return;
    }

    final now = event.timestamp;

    // Apply debounce per CC number
    final lastPress = _lastCCPress[event.cc];
    if (lastPress != null && now.difference(lastPress) < debounceWindow) {
      return; // Debounced
    }

    _lastCCPress[event.cc] = now;

    _eventController.add(
      DeviceEvent(
        action: action,
        source: DeviceType.midiController,
        timestamp: now,
        rawData: {
          'cc': event.cc,
          'value': event.value,
          'channel': event.channel,
        },
      ),
    );
  }

  /// Configure custom CC to action mapping.
  ///
  /// [cc] should be a valid MIDI CC number (0-127).
  /// [action] is the action to trigger when this CC is received.
  void setCCMapping(int cc, DeviceAction action) {
    if (cc < 0 || cc > 127) {
      throw ArgumentError('Invalid MIDI CC number: $cc. Must be 0-127.');
    }
    ccMappings[cc] = action;
  }

  /// Remove a CC mapping.
  void removeCCMapping(int cc) {
    ccMappings.remove(cc);
  }

  /// Reset to default CC mappings.
  void resetToDefaults() {
    ccMappings.clear();
    ccMappings.addAll(defaultCCMappings);
  }

  /// Get all current CC mappings.
  Map<int, DeviceAction> getCCMappings() => Map.unmodifiable(ccMappings);

  @override
  Future<bool> disconnect(String deviceId) async {
    if (deviceId != 'midi:default') {
      return false;
    }

    _connected = false;
    await _midiSubscription?.cancel();
    _midiSubscription = null;
    return true;
  }

  @override
  List<DeviceInfo> getConnectedDevices() {
    return _connected ? [_midiInfo.copyWith(isConnected: true)] : [];
  }

  @override
  Future<void> dispose() async {
    _connected = false;
    await _midiSubscription?.cancel();
    await _eventController.close();
  }
}

/// Default MIDI service stub (for testing/development).
class _DefaultMidiService implements MidiService {
  @override
  Stream<MidiCCEvent> get midiEvents {
    // Stub implementation - would use platform MIDI API
    return Stream.empty();
  }

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
