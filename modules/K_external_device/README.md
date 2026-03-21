# Module K: External Device Integration

Manages discovery, connection, and input mapping for external devices (Bluetooth pedals, keyboard shortcuts, MIDI controllers). Enforces input priority hierarchy to resolve conflicts when multiple devices emit actions simultaneously.

## Overview

This module provides:

- **Device Discovery & Connection**: Scan for and connect to Bluetooth HID devices, with automatic reconnection and battery level monitoring
- **Multi-Adapter Architecture**: Support for Bluetooth, keyboard, MIDI, and touch input via pluggable adapter pattern
- **Priority-Based Conflict Resolution**: When multiple devices emit actions simultaneously, highest-priority source wins
- **Debounce Filtering**: Prevent accidental double-presses with configurable debounce windows
- **Real-Time Logging**: Every event decision logged with timestamp, source, action, and reason for debugging and metrics

## Architecture

### Core Components

```
┌─────────────────────────────────────────────────┐
│         DeviceManager (Orchestrator)            │
│  Manages multiple adapters, delegates scanning  │
└────────────┬────────────────────────────────────┘
             │
      ┌──────┼──────┐
      │      │      │
┌─────▼──┐  ┌──────▼──┐  ┌──────────┐
│Bluetooth│  │Keyboard │  │  MIDI    │
│Adapter  │  │Adapter  │  │ Adapter  │
└─────────┘  └─────────┘  └──────────┘
      │          │           │
      └──────────┼───────────┘
                 │
         ┌───────▼────────┐
         │InputPrioritizer│
         │ -Debounce      │
         │ -Priority      │
         │ -Logging       │
         └────────────────┘
                 │
         ┌───────▼────────┐
         │  onAction      │
         │  Stream        │
         └────────────────┘
```

## File Structure

```
lib/
  device_action.dart         # Core enums and data structures
  device_adapter.dart        # Abstract adapter interface
  device_manager.dart        # Central orchestrator
  input_prioritizer.dart     # Conflict resolution engine
  bluetooth_adapter.dart     # Bluetooth HID adapter
  keyboard_adapter.dart      # Keyboard input adapter
  midi_adapter.dart          # MIDI controller adapter

test/
  device_manager_test.dart   # Device manager tests
  input_prioritizer_test.dart # Prioritizer tests
```

## Usage

### Basic Setup

```dart
import 'package:smartscore_external_device/device_manager.dart';

final deviceManager = DeviceManager(
  adapters: {
    DeviceType.bluetoothPedal: BluetoothAdapter(),
    DeviceType.keyboard: KeyboardAdapter(),
  },
);

deviceManager.onAction.listen((action) {
  switch (action) {
    case DeviceAction.nextPage:
      // Handle next page
      break;
    case DeviceAction.previousPage:
      // Handle previous page
      break;
    case DeviceAction.hold:
      // Handle hold
      break;
    case DeviceAction.syncMarker:
      // Handle sync marker
      break;
  }
});
```

## Debounce & Priority

**Debounce**: Ignores same action from same source within 150ms
**Priority Order** (highest to lowest):
1. touch
2. bluetoothPedal
3. midiController
4. keyboard

When same action arrives from different sources within 200ms, only highest-priority source wins.

## Testing

Run tests:
```bash
flutter test
# or
dart test
```

Tests cover:
- Debounce timing and filtering
- Priority conflict resolution
- Device connection/disconnection
- Logging output
