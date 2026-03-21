# Module K: External Device - Contract

## Module Purpose
Manages Bluetooth device discovery, connection, and input mapping. Converts hardware inputs (pedal buttons, keyboard keys, MIDI CC events) into high-level actions (page turn, hold, sync marker). Enforces input priority hierarchy to prevent conflicting actions.

## Input Specifications

### Bluetooth Scan Results
```
BluetoothDevice {
  id: string,                    // MAC address or UUID
  name: string,                  // Human-readable (e.g., "Bluetooth Pedal XYZ")
  rssi: int,                     // Signal strength (-127 to 0 dBm)
  advertisedServices: List<UUID>, // Service UUIDs
  bonded: bool                   // Previously paired
}
```

### Bluetooth HID Events
```
HIDEvent {
  reportId: int,                 // Report ID from HID descriptor
  buttons: byte,                 // Bitmask of button states
  // Example: byte = 0b00000011 → buttons 0 and 1 pressed
}
```

### Keyboard Events
- **Type**: Platform-specific key event
- **Code**: Physical key code (not character)
- **State**: pressed, released
- **Modifier**: shift, control, alt, meta

### MIDI CC Events
```
MIDIControlChange {
  cc: int,                       // CC number (0–127)
  value: int,                    // CC value (0–127)
  channel: int                   // MIDI channel (1–16)
}
```

---

## Output Specifications

### DeviceAction Enum
```
enum DeviceAction {
  previousPage,                  // Turn page backward
  nextPage,                      // Turn page forward
  hold,                          // Hold current page (stop auto-advance)
  syncMarker,                    // Sync playback position
  // Extension point for future actions
}
```

### Device Connection Object
```
Connection {
  deviceId: string,
  deviceName: string,
  isConnected: bool,
  connectionType: enum ["bluetooth", "usb", "network"],
  lastActionTime: DateTime?,
  actionCount: int,              // Total actions received
  signalStrength?: int           // RSSI in dBm (Bluetooth only)
}
```

---

## API Contract

### startScan() → Stream<BluetoothDevice>
**Behavior**:
- Initiate Bluetooth LE scan on platform
- Emit BluetoothDevice for each discovered device
- Filter by name or service UUID (optional, hardcoded list of known pedal manufacturers)
- Scan timeout: 30 seconds automatic stop
- Return Stream that emits devices continuously during scan

**Known Device Filters**:
```
Manufacturer IDs: 0x0415 (SoftStep), 0x0199 (IK Multimedia), etc.
Service UUIDs: 0xFFF0 (Generic HID-like), standard BLE HID UUID
Device name patterns: "*Pedal*", "*Foot*", "*Page*"
```

**Preconditions**:
- Bluetooth available on platform
- User permission granted (requested if needed)
- Not already scanning

**Error handling**:
- If Bluetooth not available: throw DeviceError with code `BLUETOOTH_NOT_AVAILABLE`
- If permissions denied: throw DeviceError with code `PERMISSIONS_DENIED`
- If already scanning: return empty stream or throw

**Complexity**: Real-time stream, O(1) per device discovery

### connect(deviceId: string) → Result<Connection, DeviceError>
**Behavior**:
- Establish connection to device by id
- Attempt GATT connection (Bluetooth) or direct socket (USB/network)
- On success: emit `onAction` stream for input events from this device
- On failure: return error with reason

**Connection Timeout**: 10 seconds per connection attempt

**Preconditions**:
- Device discovered (from startScan or cached list)
- Not already connected

**Error Codes**:
- `DEVICE_NOT_FOUND`: Device id not in discovered list
- `CONNECTION_TIMEOUT`: Could not establish connection within 10 seconds
- `CONNECTION_REJECTED`: Device rejected pairing request
- `CONNECTION_FAILED`: Connection lost before fully established
- `DEVICE_NOT_COMPATIBLE`: Device does not support required protocol

**Return**: `{ ok: true, value: Connection }` or `{ ok: false, error: DeviceError }`

**Postconditions**:
- Connection.isConnected == true
- onAction stream begins emitting events
- Can call disconnect(deviceId)

**Complexity**: O(1) per device

### disconnect(deviceId: string) → bool
**Behavior**:
- Terminate connection to device
- Stop listening to input events from this device
- Clean up resources
- Return true if disconnected, false if not connected

**Preconditions**: Device must be connected (or previously was)

**Error handling**: No exception on already-disconnected device, returns false

**Complexity**: O(1)

### onAction → Stream<DeviceAction>
**Behavior**:
- Real-time stream of device actions
- Emits DeviceAction whenever mapped input received
- Respects priority hierarchy (see Priority Rules below)
- Filters duplicate presses within debounce window

**Input Mapping** (default, configurable):
- **Pedal button 1** → nextPage
- **Pedal button 2** → previousPage
- **Pedal button 3** → hold
- **Keyboard Page Down** → nextPage
- **Keyboard Page Up** → previousPage
- **Keyboard Space** → hold
- **MIDI CC 64** (Sustain) → hold
- **MIDI CC 102** (custom) → syncMarker

**Debounce**: 50 ms minimum between same action from same device

**Preconditions**: At least one device connected

**Backpressure**: If subscriber slow, buffer up to 100 actions; older actions dropped

**Complexity**: O(1) per event

### mapMidiCC(cc: int, action: DeviceAction) → void
**Behavior**:
- Set custom mapping: when MIDI CC `cc` is received, emit `action`
- Override default mapping if cc already mapped
- Mapping persists for lifetime of application session

**Preconditions**:
- `cc` ∈ [0, 127] (valid MIDI CC range)
- `action` is valid DeviceAction enum value

**Error handling**:
- Invalid cc: ignored (logged)
- Invalid action: throw error or log warning

**Complexity**: O(1)

### getConnectedDevices() → List<Connection>
**Behavior**:
- Return list of all currently connected devices
- Sorted by connection time (earliest first)
- Include signal strength (RSSI) for Bluetooth
- Include action count since connection

**Preconditions**: None (returns empty list if no devices)

**Return**: List (may be empty), always succeeds

**Complexity**: O(n) where n = connected devices (typically ≤ 3)

---

## Input Priority Hierarchy

Enforced order when multiple inputs received simultaneously (within 100 ms):

1. **User manual override** (touch/swipe on UI) → Always highest priority
2. **External device input** (Bluetooth pedal, USB keyboard, MIDI)
3. **Auto-advance** (from Module K's timer-based page turn)

**Behavior**:
- If user taps "next page" button, ignore simultaneous pedal press
- If pedal pressed first, then user touches UI: next input from pedal ignored (debounced)
- If auto-advance timer fires + pedal pressed: pedal takes precedence

**Implementation**:
```
onAction.where(
  (action) => !userInputReceivedWithin(100ms) && !autoAdvanceActive()
).listen((action) {
  handleDeviceAction(action);
})
```

---

## Debounce Rules

All button inputs debounced to prevent accidental double presses.

| Event Type | Debounce Window | Notes |
|-----------|-----------------|-------|
| Same button repeated | 50 ms | Physical button bounce |
| Different button from same device | 100 ms | User cannot press 2 pedals simultaneously |
| Same button, different device | 100 ms | Two users in same room unlikely to press in unison |
| Keyboard key repeat | OS-dependent (100–500 ms) | Controlled by OS settings |

**Handling**:
- Within window: drop event
- After window: emit event normally
- User can press button once, wait 100 ms, press again

---

## Storage & Persistence

### Device Bonding
- **Bonded devices**: Automatically reconnect on app launch
- **Storage**: Platform keychain (iOS), secure storage (Android)
- **Timeout**: Attempt reconnect for 30 seconds on app start
- **Failure**: Log warning, user can manually reconnect via scan

### Action History
- **Logged**: Device ID, action, timestamp, source (Bluetooth/keyboard/MIDI)
- **Retention**: Last 100 actions in memory (not persisted)
- **Use**: Debugging, testing, metrics

---

## Dependencies
- **Bluetooth LE API**: Platform-specific (CoreBluetooth on iOS, android.bluetooth on Android)
- **HID descriptor parser**: Decode HID reports according to USB HID spec
- **Keyboard event listener**: Platform accessibility or direct OS integration
- **MIDI API**: CoreMIDI (iOS/macOS), Android MIDI API, Windows MME/WASAPI

---

## Error Recovery

All transient failures should attempt reconnection:
- **Connection lost mid-session**: Attempt automatic reconnect (exponential backoff: 1s, 2s, 4s, 8s)
- **Device no longer discoverable**: Stop attempting after 8 seconds
- **Permission revoked at runtime**: Graceful fallback (no crash), log error

---

## Multi-Device Behavior

Up to 3 devices can be connected simultaneously.

**Conflict resolution**:
- Device 1 sends nextPage
- Device 2 sends nextPage (within 100 ms)
- **Result**: Single nextPage action emitted (not two)
- Second device's input dropped due to debounce

**No coordination between devices**: Actions from all devices treated independently in real-time stream.

---

## Constraints

- **Bluetooth range**: Assume 10 meters effective range (drops signal below -80 dBm)
- **Connection stability**: Expect occasional dropouts on noisy RF environment
- **Latency**: End-to-end from device button press to onAction stream emission: < 100 ms (p95)
- **Battery**: Assume Bluetooth BLE (low energy), connection does not significantly drain battery
