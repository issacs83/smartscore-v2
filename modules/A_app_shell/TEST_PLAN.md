# Module A: App Shell - Test Plan

## Test Infrastructure
- **Framework**: Flutter test (widget tests + integration tests)
- **Mock modules**: Stub implementations of B, C, F, K
- **State management**: testable ChangeNotifier instances
- **Navigation**: GoRouter test harness
- **Setup**: Create test app with mock providers
- **Timeout**: 10 seconds per test

---

## Unit Tests: Routing

### T-A-ROUTE-001: Navigation to /library
**Command**: GoRouter.push("/library")
**Assertions**:
- Current route == "/library"
- Library page widget built
- Score list visible

### T-A-ROUTE-002: Navigation to /viewer/:id with valid ID
**Command**: GoRouter.push("/viewer/550e8400-e29b-41d4-a716-446655440000")
**Assertions**:
- Current route contains viewer
- Viewer page widget built
- Score rendered (Module F called)

### T-A-ROUTE-003: Navigation to /viewer/:id with invalid ID
**Command**: GoRouter.push("/viewer/invalid-id")
**Assertions**:
- Redirect to /library
- No error dialog
- Silent recovery

### T-A-ROUTE-004: Navigation to /settings
**Command**: GoRouter.push("/settings")
**Assertions**:
- Settings page displayed
- Device list visible
- Display settings accessible

### T-A-ROUTE-005: Navigation to /capture
**Command**: GoRouter.push("/capture")
**Assertions**:
- Capture page displayed
- Camera button visible

### T-A-ROUTE-006: Navigation to /debug (dev mode)
**Setup**: enableDebugMode = true
**Command**: GoRouter.push("/debug")
**Assertions**:
- Debug page displayed (only in dev)
- Shows app state, metrics, logs

### T-A-ROUTE-007: Navigation to /debug (production)
**Setup**: enableDebugMode = false
**Command**: GoRouter.push("/debug")
**Assertions**:
- Redirect to /library
- No debug page

### T-A-ROUTE-008: Deep link to score viewer
**Command**: Launch app with deep link: `smartscore:///viewer/550e8400...`
**Assertions**:
- App opens directly to viewer
- Score loaded and rendered

### T-A-ROUTE-009: Deep link to non-existent route
**Command**: Launch with deep link: `smartscore:///invalid`
**Assertions**:
- App opens to /library (safe default)
- No error

### T-A-ROUTE-010: Pop navigation (back button)
**Setup**: Viewer open, viewer was opened from library
**Command**: Tap back button
**Assertions**:
- Return to /library
- Navigation stack properly maintained

### T-A-ROUTE-011: Multiple pushes then pop
**Command**: Push /settings, push /capture, pop
**Assertions**:
- Back to /settings
- Navigation stack correct

---

## Unit Tests: State Management

### T-A-STATE-001: ScoreLibraryProvider initialization
**Command**: Create provider
**Assertions**:
- allScores is not null (empty list or loaded from Module B)
- selectedScoreId is null
- No errors during init

### T-A-STATE-002: Load score library
**Command**: scoreLibraryProvider.loadLibrary() (mock Module B)
**Assertions**:
- allScores populated with test scores
- Listeners notified
- UI updated

### T-A-STATE-003: Select score
**Command**: scoreLibraryProvider.selectScore("id-123")
**Assertions**:
- selectedScoreId == "id-123"
- Listeners notified
- Viewer can use selectedScoreId to load score

### T-A-STATE-004: Delete score
**Setup**: 3 scores in library
**Command**: scoreLibraryProvider.deleteScore("id-2")
**Assertions**:
- allScores.length == 2
- Deleted score removed
- selectedScoreId reset if it was deleted

### T-A-STATE-005: ScoreRendererProvider page change
**Command**: rendererProvider.goToPage(5)
**Assertions**:
- currentPage == 5
- Listeners notified
- renderPage(scoreJson, 5, config) would be called (mocked)

### T-A-STATE-006: UI preferences (dark mode)
**Command**: uiProvider.toggleDarkMode()
**Assertions**:
- darkMode state flipped
- Listeners notified
- Widgets rebuild with new theme

### T-A-STATE-007: UI preferences (zoom)
**Command**: uiProvider.setZoom(1.5)
**Assertions**:
- zoomLevel == 1.5
- Within range [0.5, 2.0]
- Renderer re-renders with new zoom

### T-A-STATE-008: DeviceProvider connection update
**Command**: Mock DeviceProvider.addConnection(Connection)
**Assertions**:
- connectedDevices updated
- Listeners notified
- UI reflects new device

### T-A-STATE-009: Multiple state changes in sequence
**Command**: Load library, select score, go to page 2, toggle dark mode
**Assertions**:
- All state changes applied
- UI consistent (no conflicting states)
- No listener errors

---

## Widget Tests: UI Components

### T-A-UI-001: Library page displays score list
**Setup**: 3 test scores in library provider
**Command**: Build library widget
**Assertions**:
- All 3 scores displayed
- Score title, composer, source icon visible
- Each score tappable (navigate to viewer)

### T-A-UI-002: Library page empty state
**Setup**: No scores in library
**Command**: Build library widget
**Assertions**:
- "No scores yet" message displayed
- "Import score" button visible

### T-A-UI-003: Viewer page displays score
**Setup**: Score loaded in mock Module F
**Command**: Build viewer widget for score "id-1"
**Assertions**:
- Score rendered on canvas
- Page number displayed
- Navigation buttons visible (prev/next)

### T-A-UI-004: Viewer page navigation buttons
**Setup**: Viewer open, page 0 of 3
**Command**: Tap next button
**Assertions**:
- Current page changes to 1
- Canvas re-rendered
- Page number updated

### T-A-UI-005: Settings page displays device list
**Setup**: 2 devices connected (mock DeviceProvider)
**Command**: Build settings widget
**Assertions**:
- Both devices listed
- Device name, connection status visible
- Disconnect button available

### T-A-UI-006: Settings page display options
**Command**: Build settings display tab
**Assertions**:
- Zoom slider (0.5–2.0) visible and functional
- Dark mode toggle visible
- Measures per system dropdown visible

### T-A-UI-007: Capture page camera button
**Command**: Build capture widget
**Assertions**:
- Camera button visible and enabled
- File picker button visible
- Gallery button visible

### T-A-UI-008: Dark mode theme application
**Setup**: uiProvider.darkMode = true
**Command**: Build app with dark theme
**Assertions**:
- Background is dark color
- Text is light color
- All components use dark palette

---

## Integration Tests: Full Workflows

### T-A-INT-001: Import and view score
**Workflow**:
1. Start at /library (empty)
2. Tap import button
3. Navigate to /capture
4. Mock select image file
5. Module B returns new ScoreEntry
6. Navigate to /viewer/:id
7. Score renders (Module F called)
**Assertions**:
- Entire workflow succeeds
- Score visible in library and viewer
- No errors

### T-A-INT-002: Navigate between scores
**Workflow**:
1. Library with 3 scores
2. Tap score 1 → /viewer/id-1
3. Back to /library
4. Tap score 2 → /viewer/id-2
5. Back to /library
**Assertions**:
- Navigation smooth
- Correct score displayed each time
- No state leakage

### T-A-INT-003: Device input while viewing score
**Workflow**:
1. Open /viewer/:id
2. Mock device pedal input (nextPage)
3. Module K emits DeviceAction.nextPage
4. Page increments
5. Canvas re-renders
**Assertions**:
- Device input triggers page change
- Render completes
- No lag or stutter

### T-A-INT-004: Orientation change during viewing
**Workflow**:
1. Open /viewer/:id (portrait)
2. Rotate to landscape
3. Page re-renders with new dimensions
**Assertions**:
- Layout adapts to new size
- Score still visible and correct
- No black bars or stretching

### T-A-INT-005: Memory pressure recovery
**Workflow**:
1. Load large score (50+ pages)
2. Simulate low memory warning
3. App should degrade gracefully
4. Continue navigation
**Assertions**:
- App doesn't crash
- Performance may degrade
- User can still navigate

### T-A-INT-006: Navigation while import in progress
**Workflow**:
1. Start import (long operation, mocked)
2. Immediately navigate to /settings
3. Import should be interrupted
4. No partial data
**Assertions**:
- Navigation succeeds
- Import cancelled cleanly
- Library consistency maintained

---

## Error Handling Tests

### T-A-ERR-001: Invalid route parameter
**Command**: Navigate to /viewer/not-a-uuid
**Assertions**:
- Redirect to /library
- No error dialog
- No exception thrown

### T-A-ERR-002: Module initialization failure
**Setup**: Mock Module B throws on init
**Command**: App startup
**Assertions**:
- Error boundary catches
- Error message shown
- User can retry

### T-A-ERR-003: Permission denied (camera)
**Setup**: Mock permission denied
**Command**: Navigate to /capture
**Assertions**:
- Camera button disabled
- Explanation message: "Camera permission required"
- Link to settings offered

### T-A-ERR-004: Storage full during import
**Setup**: Mock storage write failure
**Command**: Try to import score
**Assertions**:
- Error message: "Not enough storage"
- User prompted to free space
- Import cancelled

### T-A-ERR-005: Renderer crash recovery
**Setup**: Mock Module F throws exception
**Command**: Navigate to viewer
**Assertions**:
- Error boundary catches exception
- Error displayed (not full crash)
- Can navigate away

---

## Performance Tests

### T-A-PERF-001: App startup time
**Threshold**: < 2 seconds
**Command**: Launch app from cold start
**Metric**: Time to first screen

### T-A-PERF-002: Library loading (100 scores)
**Threshold**: < 1 second
**Setup**: 100 scores in mock library
**Command**: loadLibrary()
**Metric**: Time to completion

### T-A-PERF-003: Route navigation latency
**Threshold**: < 100 ms
**Command**: Navigate from /library to /viewer
**Metric**: ms from navigation call to widget build complete

### T-A-PERF-004: Provider listener notification
**Threshold**: < 50 ms
**Command**: notifyListeners() → rebuild UI
**Metric**: ms from notify to widget repaint

### T-A-PERF-005: Memory overhead (baseline)
**Threshold**: < 200 MB
**Command**: App startup, no scores, no devices
**Metric**: Resident memory MB

### T-A-PERF-006: Memory overhead (100 scores)
**Threshold**: < 300 MB
**Command**: Load library with 100 scores
**Metric**: Resident memory MB

---

## Accessibility Tests

### T-A-ACC-001: Text scaling
**Command**: Set device font scaling to 200%
**Assertions**:
- All text readable and not clipped
- UI still navigable

### T-A-ACC-002: High contrast mode
**Command**: Enable high contrast (system setting)
**Assertions**:
- Text and buttons have sufficient contrast
- Colors adjusted for high contrast

### T-A-ACC-003: Screen reader compatibility
**Command**: Enable TalkBack (Android) / VoiceOver (iOS)
**Assertions**:
- All interactive elements labeled
- Reading order logical
- Buttons, lists announced correctly

---

## Test Execution Checklist
- [ ] Routing tests: 11 tests
- [ ] State management tests: 9 tests
- [ ] Widget UI tests: 8 tests
- [ ] Integration workflow tests: 6 tests
- [ ] Error handling tests: 5 tests
- [ ] Performance tests: 6 tests
- [ ] Accessibility tests: 3 tests
- [ ] **Total: 48 test cases**

**Pass Criteria**: 48/48 pass, 0 failures, 0 timeouts, all performance targets met
