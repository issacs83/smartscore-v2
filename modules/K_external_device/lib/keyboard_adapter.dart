/// Keyboard input adapter.
///
/// Handles keyboard shortcuts on desktop platforms (iOS/Android ignored).
/// Provides default mappings and allows customization.

import 'dart:async';
import 'device_action.dart';
import 'device_adapter.dart';

/// Keyboard key event representation.
class KeyEvent {
  /// Physical key code (platform-dependent).
  final int keyCode;

  /// Key name if available (e.g., 'Enter', 'Space').
  final String? keyName;

  /// Whether key is pressed (true) or released (false).
  final bool isPressed;

  /// Timestamp of the event.
  final DateTime timestamp;

  /// Modifier keys held during event.
  final Set<String> modifiers;

  KeyEvent({
    required this.keyCode,
    this.keyName,
    required this.isPressed,
    required this.timestamp,
    this.modifiers = const {},
  });
}

/// Abstract keyboard service interface (for testability).
abstract class KeyboardService {
  /// Stream of keyboard events.
  ///
  /// Only emits key down events; key up is tracked internally.
  /// Desktop only - returns empty stream on mobile.
  Stream<KeyEvent> get keyEvents;

  /// Check if platform supports keyboard input.
  bool get isSupported;
}

/// Adapter for keyboard input.
///
/// Listens for keyboard shortcuts and maps them to device actions.
/// Desktop only; mobile platforms ignored.
class KeyboardAdapter implements DeviceAdapter {
  final KeyboardService _keyboardService;
  final StreamController<DeviceEvent> _eventController;

  /// Default key mappings.
  static const defaultKeyMappings = {
    'ArrowRight': DeviceAction.nextPage,
    'Space': DeviceAction.nextPage,
    'PageDown': DeviceAction.nextPage,
    'ArrowLeft': DeviceAction.previousPage,
    'PageUp': DeviceAction.previousPage,
    'Home': DeviceAction.previousPage,
    'End': DeviceAction.nextPage,
  };

  /// Debounce window for keyboard events.
  static const debounceWindow = Duration(milliseconds: 150);

  /// Maps key names to actions (mutable - allows configuration).
  final Map<String, DeviceAction> keyMappings;

  /// Track last key press time for debounce.
  final Map<String, DateTime> _lastKeyPress = {};

  /// Device info for keyboard.
  late final DeviceInfo _keyboardInfo;

  bool _scanning = false;
  StreamSubscription<KeyEvent>? _keyboardSubscription;

  KeyboardAdapter({
    KeyboardService? keyboardService,
    Map<String, DeviceAction>? customKeyMappings,
  })
      : _keyboardService = keyboardService ?? _DefaultKeyboardService(),
        keyMappings = {...defaultKeyMappings, ...(customKeyMappings ?? {})},
        _eventController = StreamController<DeviceEvent>.broadcast() {
    _keyboardInfo = DeviceInfo(
      id: 'keyboard:default',
      name: 'Keyboard',
      type: DeviceType.keyboard,
      isConnected: _keyboardService.isSupported,
      lastSeen: DateTime.now(),
    );
  }

  @override
  DeviceType get deviceType => DeviceType.keyboard;

  @override
  Stream<DeviceEvent> get onEvent => _eventController.stream;

  @override
  Stream<DeviceInfo> scan() async* {
    if (!_keyboardService.isSupported) {
      throw DeviceException(
        code: DeviceErrorCode.unknown,
        message: 'Keyboard input not supported on this platform',
      );
    }

    _scanning = true;

    // Keyboard is always "discovered" on desktop
    yield _keyboardInfo;

    // Keep scanning until cancelled
    while (_scanning) {
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  @override
  Future<DeviceInfo> connect(String deviceId) async {
    if (!_keyboardService.isSupported) {
      throw DeviceException(
        code: DeviceErrorCode.deviceNotCompatible,
        message: 'Keyboard input not supported on this platform',
      );
    }

    if (deviceId != 'keyboard:default') {
      throw DeviceException(
        code: DeviceErrorCode.deviceNotFound,
        message: 'Unknown keyboard device: $deviceId',
      );
    }

    // Subscribe to keyboard events
    if (_keyboardSubscription == null) {
      _keyboardSubscription = _keyboardService.keyEvents.listen(
        _handleKeyEvent,
        onError: (error) {
          print('Keyboard event error: $error');
          _keyboardSubscription = null;
        },
      );
    }

    return _keyboardInfo.copyWith(isConnected: true);
  }

  void _handleKeyEvent(KeyEvent event) {
    if (!event.isPressed) return; // Ignore key up events

    final keyName = event.keyName ?? _keyCodeToName(event.keyCode);
    if (keyName == null) return;

    final action = keyMappings[keyName];
    if (action == null) return; // Unmapped key

    final now = event.timestamp;

    // Apply debounce
    final lastPress = _lastKeyPress[keyName];
    if (lastPress != null && now.difference(lastPress) < debounceWindow) {
      return; // Debounced
    }

    _lastKeyPress[keyName] = now;

    _eventController.add(
      DeviceEvent(
        action: action,
        source: DeviceType.keyboard,
        timestamp: now,
        rawData: {
          'keyCode': event.keyCode,
          'keyName': keyName,
          'modifiers': event.modifiers.toList(),
        },
      ),
    );
  }

  /// Get standard key name from key code.
  String? _keyCodeToName(int keyCode) {
    // Common key codes (simplified)
    const keyMap = {
      37: 'ArrowLeft',
      39: 'ArrowRight',
      33: 'PageUp',
      34: 'PageDown',
      32: 'Space',
      36: 'Home',
      35: 'End',
      13: 'Enter',
    };
    return keyMap[keyCode];
  }

  /// Configure custom key mapping.
  ///
  /// [keyName] should be a standard key name (e.g., 'ArrowRight', 'Space').
  /// [action] is the action to trigger when this key is pressed.
  void setKeyMapping(String keyName, DeviceAction action) {
    keyMappings[keyName] = action;
  }

  /// Remove a key mapping.
  void removeKeyMapping(String keyName) {
    keyMappings.remove(keyName);
  }

  /// Reset to default key mappings.
  void resetToDefaults() {
    keyMappings.clear();
    keyMappings.addAll(defaultKeyMappings);
  }

  @override
  Future<bool> disconnect(String deviceId) async {
    if (deviceId != 'keyboard:default') {
      return false;
    }

    _scanning = false;
    await _keyboardSubscription?.cancel();
    _keyboardSubscription = null;
    return true;
  }

  @override
  List<DeviceInfo> getConnectedDevices() {
    return _keyboardSubscription != null ? [_keyboardInfo.copyWith(isConnected: true)] : [];
  }

  @override
  Future<void> dispose() async {
    _scanning = false;
    await _keyboardSubscription?.cancel();
    await _eventController.close();
  }
}

/// Default keyboard service stub.
class _DefaultKeyboardService implements KeyboardService {
  @override
  Stream<KeyEvent> get keyEvents {
    // Stub implementation - would integrate with platform channels
    return Stream.empty();
  }

  @override
  bool get isSupported => false; // Would check platform in real implementation
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
