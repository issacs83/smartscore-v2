# Module K: External Device - Test Plan

## Test Infrastructure
- **Framework**: Flutter test (unit) + platform channel mocks
- **Mocks**: Simulated Bluetooth stack, HID reports, MIDI events
- **Setup**: Each test initializes device manager with mock platform
- **Teardown**: Disconnect all devices, clear connection state
- **Timeout**: 10 seconds per test

---

## Unit Tests: startScan()

### T-K-SCAN-001: Bluetooth available, devices found
**Setup**: Mock Bluetooth stack with 2 discoverable devices
**Command**: `startScan()`
**Assertions**:
- Stream emits 2 BluetoothDevice objects
- Each has id, name, rssi, bonded fields
- rssi ∈ [-127, 0] dBm
- Scan continues until timeout or stop

### T-K-SCAN-002: Bluetooth available, no devices
**Setup**: Mock Bluetooth stack, no nearby devices
**Command**: `startScan()`
**Assertions**:
- Stream opens but emits no devices
- Scan runs for full timeout (30 seconds) or user stops

### T-K-SCAN-003: Bluetooth not available
**Setup**: Mock returns Bluetooth disabled
**Command**: `startScan()`
**Assertions**:
- Throws DeviceError { code: "BLUETOOTH_NOT_AVAILABLE" }
- No stream created

### T-K-SCAN-004: Permissions denied
**Setup**: Mock returns permission denied
**Command**: `startScan()`
**Assertions**:
- Throws DeviceError { code: "PERMISSIONS_DENIED" }
- User prompted to grant permissions

### T-K-SCAN-005: Scan already in progress
**Setup**: startScan() called, stream not completed
**Command**: startScan() called again
**Assertions**:
- Returns error or empty stream (implementation-dependent)
- No duplicate scan

### T-K-SCAN-006: Device appears during scan
**Setup**: Mock emits device at T=5 seconds
**Command**: Stream listening
**Assertions**:
- Stream emits new device immediately upon discovery

### T-K-SCAN-007: Device disappears during scan
**Setup**: Device goes out of range at T=10 seconds
**Command**: Stream listening
**Assertions**:
- Device not re-emitted (stream only reports new discoveries)

---

## Unit Tests: connect()

### T-K-CONN-001: Successful connection
**Setup**: Device discovered, Bluetooth stack ready
**Command**: `connect(deviceId)`
**Assertions**:
- Returns { ok: true, value: Connection }
- Connection.isConnected == true
- Connection.deviceId matches input
- onAction stream begins accepting events

### T-K-CONN-002: Device not found
**Setup**: Invalid device ID
**Command**: `connect("INVALID-ID")`
**Assertions**:
- Returns { ok: false, error: { code: "DEVICE_NOT_FOUND" } }
- No Connection object created
- onAction not affected

### T-K-CONN-003: Connection timeout
**Setup**: Device discovered, GATT connection hangs for > 10 seconds
**Command**: `connect(deviceId)`
**Assertions**:
- Timeout after 10 seconds
- Returns { ok: false, error: { code: "DEVICE_NOT_FOUND" } }
- No partial connection state left

### T-K-CONN-004: Connection rejected (pairing)
**Setup**: Device rejects pairing
**Command**: `connect(deviceId)`
**Assertions**:
- Returns { ok: false, error: { code: "CONNECTION_REJECTED" } }

### T-K-CONN-005: Already connected
**Setup**: Device already connected
**Command**: `connect(deviceId)` again
**Assertions**:
- Returns error or returns existing Connection (implementation-dependent)
- Only one active connection per device

### T-K-CONN-006: Multiple devices connected
**Setup**: Device A connected, connect Device B
**Command**: `connect(deviceBId)`
**Assertions**:
- Device B connected successfully
- Both devices in getConnectedDevices()
- Actions from both devices in onAction stream

### T-K-CONN-007: Connection at max capacity (3 devices)
**Setup**: 3 devices already connected
**Command**: `connect(fourthDeviceId)`
**Assertions**:
- Returns error { code: "MAX_CONNECTIONS_REACHED" } or queues
- Implementation-dependent behavior

---

## Unit Tests: disconnect()

### T-K-DISC-001: Successful disconnect
**Setup**: Device connected
**Command**: `disconnect(deviceId)`
**Assertions**:
- Returns true
- Connection.isConnected == false
- Device removed from getConnectedDevices()
- onAction no longer emits from this device

### T-K-DISC-002: Disconnect non-existent device
**Setup**: No device with ID
**Command**: `disconnect("INVALID-ID")`
**Assertions**:
- Returns false
- No error thrown

### T-K-DISC-003: Disconnect already disconnected
**Setup**: Device previously disconnected
**Command**: `disconnect(deviceId)`
**Assertions**:
- Returns false
- No error

---

## Unit Tests: onAction Stream

### T-K-ACT-001: Pedal button press (nextPage)
**Setup**: Device connected with default mapping (Button 1 → nextPage)
**Command**: Emit HID button 1 pressed
**Assertions**:
- onAction emits DeviceAction.nextPage
- emitted < 100 ms after button press

### T-K-ACT-002: Pedal button 2 (previousPage)
**Setup**: Same setup
**Command**: Emit HID button 2 pressed
**Assertions**:
- onAction emits DeviceAction.previousPage

### T-K-ACT-003: Pedal button 3 (hold)
**Setup**: Same setup
**Command**: Emit HID button 3 pressed
**Assertions**:
- onAction emits DeviceAction.hold

### T-K-ACT-004: Keyboard Page Down (nextPage)
**Setup**: Keyboard device connected
**Command**: Keyboard event Page Down
**Assertions**:
- onAction emits DeviceAction.nextPage

### T-K-ACT-005: Keyboard Page Up (previousPage)
**Setup**: Same setup
**Command**: Keyboard event Page Up
**Assertions**:
- onAction emits DeviceAction.previousPage

### T-K-ACT-006: Keyboard Space (hold)
**Setup**: Same setup
**Command**: Keyboard event Space bar pressed
**Assertions**:
- onAction emits DeviceAction.hold

### T-K-ACT-007: MIDI CC 64 Sustain (hold)
**Setup**: MIDI device connected
**Command**: MIDI CC 64 value 127 (pedal down)
**Assertions**:
- onAction emits DeviceAction.hold

### T-K-ACT-008: MIDI CC 64 release (no action)
**Setup**: Same setup
**Command**: MIDI CC 64 value 0 (pedal up)
**Assertions**:
- No action emitted (sustain release is implicit)

### T-K-ACT-009: No device connected
**Setup**: No device connected
**Command**: Try to listen to onAction
**Assertions**:
- Stream exists but emits nothing (empty)
- No error

### T-K-ACT-010: Action emitted from multiple devices
**Setup**: 2 pedal devices connected
**Command**: Device A button 1 pressed, then Device B button 1 pressed at T=20 ms
**Assertions**:
- T=0: onAction emits nextPage (Device A)
- T=20: onAction emits nextPage (Device B) if outside debounce window

### T-K-ACT-011: Rapid button press (debounce)
**Setup**: Device connected, Button 1 → nextPage
**Command**: Emit button press at T=0, release T=5, press T=10
**Assertions**:
- T=0: onAction emits nextPage
- T=10: drop (within 50 ms of T=0, same action)
- No second action emitted

### T-K-ACT-012: Different button (no debounce)
**Setup**: Same setup
**Command**: Button 1 at T=0, Button 2 at T=30 ms
**Assertions**:
- T=0: emit nextPage (Button 1)
- T=30: emit previousPage (Button 2, different action)
- Both emitted (no debounce between different actions)

### T-K-ACT-013: Button bounce (debounce)
**Setup**: Mechanical button with bounce
**Signals**: T=0 press, T=5 release (bounce), T=8 press, T=15 release
**Assertions**:
- T=0: emit nextPage
- T=5: drop (bounce, too fast)
- T=8: drop (still within 50 ms)
- Result: 1 action emitted (bounce filtered)

### T-K-ACT-014: Slow repeated presses
**Setup**: User presses button, waits 100 ms, presses again
**Command**: Press at T=0, release T=10, press T=120
**Assertions**:
- T=0: emit nextPage
- T=120: emit nextPage (> 50 ms debounce window)
- Both actions emitted

### T-K-ACT-015: Stream backpressure (slow subscriber)
**Setup**: Subscriber processing takes 100 ms per action
**Command**: Device sends 10 actions rapidly (10 ms apart)
**Assertions**:
- Buffer holds up to 100 actions
- First action processed, 9 queued
- No exception, stream handles backpressure

---

## Unit Tests: mapMidiCC()

### T-K-MAP-001: Valid mapping
**Setup**: MIDI device connected
**Command**: `mapMidiCC(102, DeviceAction.syncMarker)`
**Assertions**:
- Mapping stored
- Future MIDI CC 102 events emit syncMarker

### T-K-MAP-002: Override default mapping
**Setup**: MIDI CC 64 default = hold
**Command**: `mapMidiCC(64, DeviceAction.nextPage)`
**Assertions**:
- Override applied
- MIDI CC 64 now emits nextPage (not hold)

### T-K-MAP-003: Invalid CC (< 0)
**Setup**: None
**Command**: `mapMidiCC(-1, DeviceAction.nextPage)`
**Assertions**:
- Mapping not stored
- Warning logged
- No exception

### T-K-MAP-004: Invalid CC (> 127)
**Setup**: None
**Command**: `mapMidiCC(200, DeviceAction.nextPage)`
**Assertions**:
- Mapping not stored
- Warning logged

### T-K-MAP-005: Invalid action
**Setup**: None
**Command**: `mapMidiCC(100, "invalidAction")`
**Assertions**:
- Error returned or exception thrown

### T-K-MAP-006: Multiple CC to same action
**Setup**: None
**Command**: `mapMidiCC(64, DeviceAction.hold)` + `mapMidiCC(67, DeviceAction.hold)`
**Assertions**:
- Both mapped to hold
- Either CC triggers hold

---

## Unit Tests: getConnectedDevices()

### T-K-DEV-001: No devices connected
**Setup**: Fresh app state
**Command**: `getConnectedDevices()`
**Assertions**:
- Returns empty list []
- No error

### T-K-DEV-002: One device connected
**Setup**: Device A connected
**Command**: `getConnectedDevices()`
**Assertions**:
- Returns list with 1 Connection object
- Connection.isConnected == true
- Connection.deviceName matches device A

### T-K-DEV-003: Multiple devices
**Setup**: Device A, B, C connected (in that order)
**Command**: `getConnectedDevices()`
**Assertions**:
- Returns list with 3 Connection objects
- Sorted by connection time (A, B, C order)
- All have isConnected == true

### T-K-DEV-004: Bluetooth signal strength (RSSI)
**Setup**: Device connected via Bluetooth
**Command**: `getConnectedDevices()`
**Assertions**:
- Connection.signalStrength populated (RSSI in dBm)
- Value ∈ [-127, 0]

### T-K-DEV-005: Action count incremented
**Setup**: Device connected, emit 5 actions
**Command**: `getConnectedDevices()`
**Assertions**:
- Connection.actionCount == 5
- Updated in real-time

---

## Integration Tests: Connection Lifecycle

### T-K-INT-001: Scan → Connect → Disconnect
**Setup**: None
**Command**: startScan() → wait for device → connect() → disconnect()
**Assertions**:
- All operations succeed
- Device transitions: discoverable → connected → disconnected

### T-K-INT-002: Bonded device auto-reconnect
**Setup**: Device previously bonded, now offline
**Command**: App restart
**Assertions**:
- Attempt auto-reconnect within 30 seconds
- If successful: device back online
- If unsuccessful: device marked offline

### T-K-INT-003: Connection lost and recovered
**Setup**: Device connected, emitting actions
**Action**: Simulate connection loss at T=5s
**Assertions**:
- Connection.isConnected → false
- Automatic reconnect starts (1s, 2s, 4s, 8s backoff)
- If device turns back on: reconnect succeeds

### T-K-INT-004: User priority override
**Setup**: Device connected, pedal ready to send nextPage
**Action**: User taps "next" button on UI at same time as pedal press
**Assertions**:
- Only user action emitted
- Pedal action dropped
- Pedal debounced for 100 ms

---

## Performance Tests

### T-K-PERF-001: Scan time
**Threshold**: Complete scan within 30 seconds
**Setup**: 5 devices in range
**Command**: startScan() → wait until 5 devices discovered
**Metric**: Seconds elapsed

### T-K-PERF-002: Connection time
**Threshold**: < 2 seconds
**Setup**: Device discovered
**Command**: connect() timed
**Metric**: ms

### T-K-PERF-003: Action latency (Bluetooth)
**Threshold**: < 100 ms (p95)
**Setup**: Device connected, button press simulated
**Command**: Measure time from button press to onAction emission
**Metric**: ms

### T-K-PERF-004: Action latency (Keyboard)
**Threshold**: < 50 ms (p95)
**Setup**: Keyboard device connected
**Command**: Measure time from key event to onAction
**Metric**: ms

### T-K-PERF-005: Action latency (MIDI)
**Threshold**: < 100 ms (p95)
**Setup**: MIDI device connected
**Command**: Measure time from MIDI CC event to onAction
**Metric**: ms

### T-K-PERF-006: Memory overhead per device
**Threshold**: < 5 MB per device
**Setup**: 3 devices connected
**Command**: Measure resident memory
**Metric**: MB

---

## Concurrent/Stress Tests

### T-K-STRESS-001: Rapid device connect/disconnect
**Setup**: None
**Command**: Connect device, disconnect, connect, disconnect × 10 in rapid sequence
**Assertions**:
- All operations succeed
- No dangling connections
- Final state clean

### T-K-STRESS-002: Rapid action emission
**Setup**: Device connected
**Command**: Emit 1000 actions per second for 10 seconds
**Assertions**:
- Buffer overflow handled (old actions dropped)
- No crash
- Subscriber keeps up or gracefully handles backpressure

### T-K-STRESS-003: Multiple devices simultaneous actions
**Setup**: 3 devices connected
**Command**: All 3 send action at T=0
**Assertions**:
- onAction emits all 3 actions (or debounces correctly)
- No race conditions
- All actions processed in order

---

## Test Execution Checklist
- [ ] Scan tests: 7 tests
- [ ] Connect tests: 7 tests
- [ ] Disconnect tests: 3 tests
- [ ] onAction tests: 15 tests
- [ ] mapMidiCC tests: 6 tests
- [ ] getConnectedDevices tests: 5 tests
- [ ] Integration tests: 4 tests
- [ ] Performance tests: 6 tests
- [ ] Stress tests: 3 tests
- [ ] **Total: 56 test cases**

**Pass Criteria**: 56/56 pass, 0 failures, 0 timeouts, all latency targets met
