# Module K Quick Start Guide

## Installation

Add to your `pubspec.yaml`:
```yaml
dependencies:
  smartscore_external_device:
    path: modules/K_external_device
```

## Basic Usage (3 Steps)

### 1. Create Manager
```dart
import 'package:smartscore_external_device/device_manager.dart';

final manager = DeviceManager(
  adapters: {
    DeviceType.bluetoothPedal: BluetoothAdapter(),
    DeviceType.keyboard: KeyboardAdapter(),
  },
);
```

### 2. Listen to Actions
```dart
manager.onAction.listen((action) {
  switch (action) {
    case DeviceAction.nextPage:
      // Navigate forward
      break;
    case DeviceAction.previousPage:
      // Navigate backward
      break;
    case DeviceAction.hold:
      // Stop auto-advance
      break;
    case DeviceAction.syncMarker:
      // Sync playback position
      break;
  }
});
```

### 3. Scan & Connect
```dart
// Scan for devices
manager.scan(DeviceType.bluetoothPedal).listen((device) {
  print('Found: ${device.name}');
  
  // Connect
  manager.connect(DeviceType.bluetoothPedal, device.id)
    .then((_) => print('Connected!'))
    .catchError((e) => print('Error: $e'));
});
```

## API Reference

### Core Enums
```dart
enum DeviceAction { previousPage, nextPage, hold, syncMarker }
enum DeviceType { bluetoothPedal, midiController, keyboard, touch }
```

### DeviceManager
```dart
// Scan for devices
Stream<DeviceInfo> scan(DeviceType type)

// Connect/disconnect
Future<DeviceInfo> connect(DeviceType type, String id)
Future<bool> disconnect(DeviceType type, String id)

// Get connected devices
List<DeviceInfo> getConnectedDevices()

// Listen to actions
Stream<DeviceAction> get onAction

// Cleanup
Future<void> dispose()
```

### Adapter-Specific Configuration

**Keyboard:**
```dart
final kb = KeyboardAdapter();
kb.setKeyMapping('KeyW', DeviceAction.nextPage);
kb.resetToDefaults();
```

**MIDI:**
```dart
final midi = MidiAdapter();
midi.setCCMapping(100, DeviceAction.hold);
final mappings = midi.getCCMappings();
```

## Input Behavior

### Debounce
Same action from same device within 150ms → ignored

### Priority (when same action within 200ms from different devices)
1. **touch** (highest) - UI buttons
2. **bluetoothPedal** - Physical page turner
3. **midiController** - MIDI CC events
4. **keyboard** (lowest) - Keyboard shortcuts

### Example: Which action wins?
- Time 0ms: Keyboard presses Right arrow (nextPage)
- Time 100ms: Bluetooth pedal button pressed (nextPage)
- **Result:** Keyboard action only (higher priority)

## Device Profiles

### Bluetooth Pedals
- **AirTurn**: Up/Down arrows
- **PageFlip**: Left/Right buttons
- **Generic**: Configurable button mapping

### Default Keyboard Mappings
| Key | Action |
|-----|--------|
| Right Arrow, Space, PageDown | nextPage |
| Left Arrow, PageUp | previousPage |

### Default MIDI Mappings
| CC | Name | Action |
|----|------|--------|
| 64 | Sustain Pedal | nextPage |
| 67 | Soft Pedal | previousPage |
| 102 | Custom | syncMarker |

## Error Handling

```dart
try {
  await manager.connect(DeviceType.bluetoothPedal, 'device-id');
} on DeviceException catch (e) {
  switch (e.code) {
    case DeviceErrorCode.bluetoothNotAvailable:
      print('Bluetooth not available');
      break;
    case DeviceErrorCode.permissionsDenied:
      print('User denied permission');
      break;
    case DeviceErrorCode.deviceNotFound:
      print('Device not discovered');
      break;
    case DeviceErrorCode.connectionTimeout:
      print('Connection timed out');
      break;
    default:
      print('Error: ${e.message}');
  }
}
```

## Logging

Access event decisions:
```dart
final manager = DeviceManager(
  adapters: {...},
  logger: DefaultPrioritizerLogger(),
);

// Later...
final logger = manager.logger as DefaultPrioritizerLogger;
final history = logger.getHistory();

for (final entry in history) {
  print(entry);
}
// Example: [2026-03-21T10:30:45.123Z] ACCEPTED: keyboard -> nextPage (reason: Passed all filters)
// Example: [2026-03-21T10:30:45.150Z] REJECTED: bluetoothPedal action nextPage (reason: Debounced...)
```

## Testing

```bash
# Run all tests
dart test

# Run specific test
dart test test/device_manager_test.dart

# With verbose output
dart test -v
```

## Common Patterns

### Auto-reconnect on app start
```dart
final bonded = deviceManager.getConnectedDevices();
for (final device in bonded) {
  try {
    await deviceManager.connect(device.type, device.id);
  } catch (e) {
    print('Failed to reconnect ${device.name}: $e');
  }
}
```

### Monitor battery level
```dart
manager.onAction.listen((_) {
  // Battery level updates after each action
  for (final device in manager.getConnectedDevices()) {
    if (device.batteryLevel != null) {
      print('${device.name}: ${device.batteryLevel}%');
    }
  }
});
```

### Disable keyboard on mobile
```dart
final adapters = {
  DeviceType.bluetoothPedal: BluetoothAdapter(),
  // Keyboard adapter not added on mobile
};
```

### Custom key binding
```dart
final kb = KeyboardAdapter(
  customKeyMappings: {
    'KeyA': DeviceAction.previousPage,
    'KeyD': DeviceAction.nextPage,
    'KeyS': DeviceAction.hold,
  },
);
```

## Performance Notes

- **Latency:** < 100ms (p95) from device button press to action
- **Memory:** Last 100 actions logged (rolling buffer)
- **Streams:** Broadcast streams support multiple listeners
- **Connections:** Up to 3 simultaneous devices supported

## Troubleshooting

**Q: Actions not working on Bluetooth?**
A: Check `getConnectedDevices()` returns the device. Verify device is in scan results first.

**Q: Duplicate actions?**
A: Normal - occurs outside 150ms debounce window. Increase debounce if needed.

**Q: Keyboard shortcuts not responding?**
A: Desktop only. Mobile platforms have no keyboard adapter by default.

**Q: MIDI CCs not working?**
A: Verify CC number is 0-127 and matches configured mapping.

**Q: Memory leak?**
A: Call `manager.dispose()` when done. Always cancel stream subscriptions.

## Next Steps

1. Integrate with page navigation in your app
2. Add UI for device discovery/pairing
3. Store bonded devices for auto-reconnect
4. Implement platform-specific BluetoothService (replace stub)
5. Monitor analytics via logger

See README.md for full documentation.
