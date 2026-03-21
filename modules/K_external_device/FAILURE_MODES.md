# Module K: External Device - Failure Modes

## F-K01: Bluetooth Not Available

**Condition**:
- Device does not have Bluetooth capability
- Bluetooth hardware disabled (airplane mode, settings)
- Bluetooth permissions not granted (user denies at runtime)
- Bluetooth subsystem failed (OS-level error)

**Detection Method**:
1. Call platform Bluetooth API: check if BLE capability available
2. Check OS settings: isBluetoothEnabled()
3. Check user permissions: hasBluetoothScanPermission()
4. If any check fails, Bluetooth unavailable

**Recovery Action**:
- startScan() throws DeviceError with code `BLUETOOTH_NOT_AVAILABLE`
- Emit error to UI: "Enable Bluetooth in Settings"
- No scan initiated
- User must enable Bluetooth + grant permissions, then retry

**Test Case**:
```
Setup: Bluetooth disabled (OS settings)
Command: startScan()
Expected: Throws DeviceError { code: "BLUETOOTH_NOT_AVAILABLE" }
Verify: No scan attempt made, no device enumeration
```

---

## F-K02: Device Not Found

**Condition**:
- Device ID passed to connect() not in discovered list
- Device was discovered but powered off before connection attempt
- Device out of range (< 10 meters effective)
- Wrong device ID format (invalid MAC or UUID)

**Detection Method**:
1. Query device registry from previous scan: if id not found, "not found"
2. Attempt connection: if timeout (10 sec), treat as "not found"
3. Check format: if MAC not valid format, "not found"

**Recovery Action**:
- connect(deviceId) returns `{ ok: false, error: { code: "DEVICE_NOT_FOUND" } }`
- Do not create Connection object
- User can rescan to rediscover device

**Test Case - ID Not in List**:
```
Setup: No devices connected
Command: connect("INVALID-MAC-ADDRESS")
Expected: { ok: false, error: { code: "DEVICE_NOT_FOUND" } }
```

**Test Case - Device Turned Off**:
```
Setup: Device discovered but user powers it off before connect()
Command: connect(deviceId)
Expected: Timeout after 10 seconds, return { ok: false, error: { code: "DEVICE_NOT_FOUND" } }
```

---

## F-K03: Connection Lost Mid-Session

**Condition**:
- Bluetooth connection drops after successful connection
- Device out of range (> 10 meters)
- Device powered off or disconnected by user
- RF interference, weak signal
- Connection timeout due to inactivity

**Detection Method**:
1. Monitor onAction stream: if no keep-alive signal for 30 seconds, assume lost
2. Platform callback: Bluetooth stack notifies connection terminated
3. Action transmission fails: send returns error

**Recovery Action**:
- Mark Connection.isConnected = false
- Stop emitting onAction from this device
- Attempt automatic reconnect with exponential backoff: 1s, 2s, 4s, 8s (total 15s)
- If reconnect fails: log error, device remains offline
- User can manually reconnect via UI

**Test Case**:
```
Setup: Device connected and emitting actions
Action: Simulate Bluetooth disconnect (kill connection on device end)
Expected:
  - Connection.isConnected → false within 5 seconds
  - onAction stops emitting
  - Automatic reconnect attempts start
  - After 15 seconds: give up
```

---

## F-K04: Duplicate Button Press (Debounce)

**Condition**:
- Same button pressed twice within debounce window (50 ms)
- Mechanical button bounce (multiple contact transitions)
- Software sending duplicate HID reports
- User attempts rapid repeated presses within 50 ms

**Detection Method**:
1. Track last action from device: `lastAction = { action, timestamp }`
2. Incoming action: check if `action == lastAction.action && timestamp - lastAction.timestamp < 50ms`
3. If true: duplicate detected

**Recovery Action**:
- Drop duplicate action (do not emit)
- Silently ignore (no error, no logging, no user notification)
- After 50 ms, same action can be emitted again if received

**Test Case**:
```
Setup: Pedal button (nextPage) pressed, release, pressed again quickly
Event stream: [T=0: press, T=10: bounce, T=20: release, T=30: press]
Expected emissions:
  - T=0: emit nextPage
  - T=10: drop (within 50ms of T=0, same action)
  - T=30: emit nextPage (> 50ms from T=0)
Result: 2 nextPage actions, not 3
```

---

## F-K05: Conflicting Inputs (Simultaneous)

**Condition**:
- Multiple input sources press buttons within 100 ms
- Pedal button + keyboard key pressed simultaneously
- Touch UI tap + pedal button at same time
- Two pedals on different devices pressed within 100 ms

**Detection Method**:
1. Timestamp incoming action from each source
2. Check: if multiple actions within 100 ms window, conflict detected
3. Determine priority: user > device > auto-advance

**Recovery Action**:
- User input always wins: drop device action
- Device 1 + Device 2: order by timestamp (first one emitted, second dropped after debounce)
- Device + auto-advance: device wins
- Implementation: filter onAction stream by user input state

**Test Case - User Override**:
```
Setup: Device connected, emitting actions
Action: Pedal pressed + simultaneously user taps "next" button on UI
Expected:
  - nextPage action emitted (from user tap, not pedal)
  - Pedal action dropped
  - Debounce applies to pedal for 100 ms
```

**Test Case - Two Devices**:
```
Setup: Device A (pedal) + Device B (keyboard)
Action: Device A presses nextPage at T=0, Device B presses nextPage at T=50 ms
Expected:
  - T=0: emit nextPage (from Device A)
  - T=50: drop nextPage (from Device B, within 100 ms of Device A)
  - Either debounce applies to both devices, or per-device
Result: Single nextPage action
```

---

## F-K06: Bluetooth Pairing Failure

**Condition**:
- Device rejects pairing request (security policy, incompatible)
- User cancels pairing dialog (on device or phone)
- Device requires PIN/passcode (not supported by app)
- Pairing timeout (> 30 seconds without response)

**Detection Method**:
1. Attempt pairing (GATT handshake)
2. Platform callback: pairing rejected or timeout
3. No active GATT connection established

**Recovery Action**:
- connect(deviceId) returns `{ ok: false, error: { code: "CONNECTION_REJECTED" } }`
- Do not retry automatically (user action required)
- Message: "Device rejected pairing. Check device settings or try again."
- User must approve pairing on device side

**Test Case**:
```
Setup: Device with strict pairing policy
Command: connect(deviceId) → device rejects
Expected: { ok: false, error: { code: "CONNECTION_REJECTED" } }
Verify: No connection object created
```

---

## F-K07: Invalid MIDI CC Mapping

**Condition**:
- mapMidiCC() called with cc < 0 or cc > 127
- mapMidiCC() called with invalid action enum value
- MIDI CC 64 (Sustain) received but no mapping defined

**Detection Method**:
1. Validate cc: if cc < 0 || cc > 127, invalid
2. Validate action: if action not in DeviceAction enum, invalid

**Recovery Action**:
- **Invalid cc**: Log warning, ignore mapping (do not store)
- **Invalid action**: Throw error or return error Result
- **Unmapped CC**: Silently ignore (no action emitted)
- No exception, graceful degradation

**Test Case - Invalid CC**:
```
Command: mapMidiCC(200, DeviceAction.nextPage)
Expected: No mapping stored, warning logged
Result: MIDI CC 200 later ignored
```

**Test Case - Invalid Action**:
```
Command: mapMidiCC(64, "invalidAction")
Expected: Error returned or exception thrown
```

---

## F-K08: Device No Longer Discoverable

**Condition**:
- Device paired previously (bonded) but not discoverable in current scan
- Device powered off but cached in memory
- Device changed name or address
- Scan filter excludes device

**Detection Method**:
1. Check bonded devices list (persisted from previous session)
2. Attempt reconnect to bonded device even if not in current scan results
3. If reconnect fails, treat as "device not found"

**Recovery Action**:
- If bonded but not discoverable: attempt auto-reconnect on app launch
- If auto-reconnect fails after 30 seconds: remove from active connection list
- User can rescan to discover again or forget device

**Test Case**:
```
Setup: Device was bonded in previous session, now offline
Action: App launches
Expected: Attempt reconnect to bonded device for 30 seconds
Result: Reconnect succeeds OR device marked offline, user prompted
```

---

## F-K09: MIDI Input Not Available

**Condition**:
- Platform does not support MIDI API (some Android versions)
- MIDI hardware driver not installed
- MIDI permissions not granted

**Detection Method**:
1. Check platform support: MIDI API available?
2. Check permissions: hasMIDIPermission()?
3. If either fails: MIDI disabled

**Recovery Action**:
- MIDI inputs ignored (no error)
- Non-MIDI devices (Bluetooth, USB) still work
- User cannot map MIDI CC events
- Graceful fallback: log warning, continue with available device types

**Test Case**:
```
Setup: Android device without MIDI support
Action: User tries to map MIDI CC
Expected: mapMidiCC() succeeds but no MIDI events received
Result: Keyboard + Bluetooth devices work, MIDI unavailable
```

---

## F-K10: Action Stream Overflow (Backpressure)

**Condition**:
- Device sending too many actions (> 100 actions/sec)
- Subscriber slow to consume (e.g., UI rendering blocked)
- Buffer of 100 queued actions exceeded

**Detection Method**:
1. Count actions enqueued: if > 100, overflow detected
2. Measure subscriber latency: if > 50 ms delay, slow subscriber

**Recovery Action**:
- Drop oldest (FIFO) actions when buffer exceeds 100
- Log warning once per overflow event (avoid spam)
- Continue emitting latest actions to subscriber
- Subscriber responsibility to keep up

**Test Case**:
```
Setup: Device rapidly sending nextPage (100+ times per second)
Subscriber: Slow consumer (50 ms latency per action)
Expected:
  - Buffer fills to 100 actions
  - Oldest action dropped
  - Latest action kept
  - No exception, continue processing
```

---

## Summary Table

| Code | Condition | Detection | Recovery | Test |
|------|-----------|-----------|----------|------|
| F-K01 | Bluetooth unavailable | Check API, permissions | Throw error, user enables BT | Disable Bluetooth |
| F-K02 | Device not found | ID not in list, timeout | Return error | connect() invalid ID |
| F-K03 | Connection lost | Bluetooth callback, timeout | Reconnect backoff | Disconnect device |
| F-K04 | Duplicate press | Same action < 50ms | Drop silently | Button bounce |
| F-K05 | Conflicting inputs | Multiple actions < 100ms | User > device > auto | Pedal + tap UI |
| F-K06 | Pairing rejection | Platform callback | Return error, user retry | Reject pairing |
| F-K07 | Invalid MIDI mapping | Validate cc/action | Ignore, log warning | Invalid CC value |
| F-K08 | Device not discoverable | Check bonded list | Auto-reconnect or offline | Unbond device |
| F-K09 | MIDI unavailable | Check platform support | Fallback, ignore MIDI | Android no MIDI |
| F-K10 | Action overflow | Count > 100 | Drop oldest actions | Rapid fire events |
