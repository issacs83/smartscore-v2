# Module A: App Shell - Failure Modes

## F-A01: Navigation Route Not Found

**Condition**:
- Deep link to non-existent route (e.g., `/viewer/invalid-id`)
- Route parameter missing (e.g., `/viewer/` without ID)
- Typo in route name (e.g., `/setings` instead of `/settings`)

**Detection Method**:
1. GoRouter matches route against defined routes
2. If no match: route not found error

**Recovery Action**:
- Display "Page not found" error page
- Offer navigation back to `/library`
- Log invalid route attempt
- No app crash

**Test Case**:
```
Command: Navigate to /viewerr/:id (typo)
Expected: Error page displayed, user can return to home
```

---

## F-A02: Provider State Corruption

**Condition**:
- ChangeNotifier emits during widget rebuild (infinite loop)
- Provider accessed before initialization
- State shared between multiple navigator contexts

**Detection Method**:
1. Flutter detects listener changed during build phase
2. Provider initialization check (null access)

**Recovery Action**:
- Catch BuildContext error, show error boundary
- Reset provider to default state
- Log state corruption event
- Prompt user to restart app

**Test Case**:
```
Setup: Manually trigger infinite notifyListeners()
Expected: Error boundary catches, app recovers
```

---

## F-A03: Storage Permission Denied

**Condition**:
- User denies camera permission → /capture unavailable
- User denies file access → import from files unavailable
- Permission revoked at OS level after app launch

**Detection Method**:
1. Check permission before each operation
2. Android/iOS permission API returns denied

**Recovery Action**:
- Disable feature UI (gray out buttons)
- Show explanatory message
- Offer link to Settings (OS settings)
- Continue with other features

**Test Case**:
```
Setup: Deny camera permission on Android
Command: Try to launch /capture
Expected: Permissions prompt or error message, feature disabled
```

---

## F-A04: Memory Pressure (Low Memory)

**Condition**:
- Device memory < 100 MB available
- Loading large score (100+ pages)
- Multiple pages cached simultaneously

**Detection Method**:
1. Monitor available memory via platform API
2. Watch for malloc failures from Module F

**Recovery Action**:
- Release cache (drop old pages)
- Reduce zoom level automatically
- Show warning: "Low memory, some features disabled"
- Graceful degradation (single page at a time)

**Test Case**:
```
Setup: Reduce app memory limit to 150 MB
Command: Load large score, navigate multiple pages
Expected: App continues, features degrade, no crash
```

---

## F-A05: Dark Mode Toggle Failure

**Condition**:
- Dark mode toggle fails to rebuild UI
- Theme data incomplete or missing
- Platform dark mode changed (system event)

**Detection Method**:
1. Theme.of(context) returns null
2. MediaQuery.of().platformBrightness doesn't match state

**Recovery Action**:
- Force full rebuild of MaterialApp
- Fallback to light theme if dark theme unavailable
- Log theme error, continue with default

**Test Case**:
```
Command: Toggle dark mode, then rotate device
Expected: Theme persists correctly across orientation change
```

---

## F-A06: Module Initialization Failure

**Condition**:
- Module B (library) fails to initialize SQLite
- Module F (renderer) missing font resources
- Module K (device) Bluetooth unavailable

**Detection Method**:
1. Each module reports initialization status
2. ProviderContainer catches initialization exceptions

**Recovery Action**:
- Show splash screen with "Initializing..." message
- Retry initialization with exponential backoff (3 attempts)
- If all fail: show error screen, offer to clear app data and restart
- Degrade to offline mode for affected module

**Test Case**:
```
Setup: Delete fonts directory, launch app
Expected: Graceful fallback, app launches with warning
```

---

## F-A07: Route Parameter Parsing Error

**Condition**:
- Score ID parameter not valid UUID (e.g., `/viewer/not-a-uuid`)
- Zoom level not a number (in URL query param)
- Measure number negative or out of range

**Detection Method**:
1. Parse route parameter with strict validation
2. Regex/format check before routing

**Recovery Action**:
- Reject invalid parameter, return to safe route (`/library`)
- Log invalid parameter for debugging
- No error dialog (silent recovery)

**Test Case**:
```
Command: Navigate to /viewer/123-not-uuid
Expected: Redirect to /library silently
```

---

## F-A08: Device Orientation Change Mid-Render

**Condition**:
- User rotates device while score page rendering
- Canvas size changes during Module F.renderPage()
- UI layout changes (portrait → landscape)

**Detection Method**:
1. MediaQuery detects size change
2. Widget rebuilds with new dimensions

**Recovery Action**:
- Cancel ongoing render operation
- Recalculate layout with new dimensions
- Re-render page asynchronously
- Show loading indicator briefly

**Test Case**:
```
Command: Rotate device while /viewer loaded
Expected: Page re-renders correctly, no visual artifacts
```

---

## F-A09: Route Navigation During Module Operation

**Condition**:
- User navigates away while import in progress (Module B)
- User taps home while /capture active (camera still recording)
- Navigation while Module F rendering

**Detection Method**:
1. Navigation request detected
2. Check if background operation in progress

**Recovery Action**:
- Cancel/interrupt background operation (graceful shutdown)
- Show confirmation dialog: "Cancel import?" if critical
- Clean up resources
- Navigate to new route

**Test Case**:
```
Setup: Start importing PDF, immediately navigate to /settings
Expected: Import cancelled cleanly, no partial data left
```

---

## F-A10: Navigator State Inconsistency

**Condition**:
- GoRouter state doesn't match widget tree
- Multiple navigation contexts (nested routes)
- Pop operation on empty navigation stack

**Detection Method**:
1. Navigator stack tracking
2. Route change event mismatch

**Recovery Action**:
- Reset navigator to home (`/library`)
- Clear navigation stack
- Log state inconsistency
- Show brief message to user (toast)

**Test Case**:
```
Setup: Nested navigator with custom route guards
Command: Navigate, pop multiple times
Expected: Stack never underflows, home reachable
```

---

## Summary Table

| Code | Condition | Detection | Recovery | Test |
|------|-----------|-----------|----------|------|
| F-A01 | Route not found | GoRouter match fail | Error page + home | Navigate invalid route |
| F-A02 | Provider state corrupt | Build phase listener change | Error boundary, reset | Trigger infinite notify |
| F-A03 | Permission denied | OS permission API | Disable feature, warn | Deny camera permission |
| F-A04 | Low memory | Available memory check | Release cache, degrade | Fill device memory |
| F-A05 | Dark mode toggle fail | Theme data null | Force rebuild, fallback | Toggle + rotate |
| F-A06 | Module init fail | Init exception catch | Retry, degrade, clear data | Delete font files |
| F-A07 | Route param invalid | Format validation | Reject, redirect silently | Invalid UUID param |
| F-A08 | Orientation change mid-render | MediaQuery size change | Cancel render, re-render | Rotate device mid-page |
| F-A09 | Nav during operation | Background op check | Cancel op, confirm dialog | Nav while importing |
| F-A10 | Navigator state inconsistent | Stack tracking mismatch | Reset to home | Pop empty stack |
