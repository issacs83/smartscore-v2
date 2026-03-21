# SmartScore Stage 1 - Completion Criteria

## Scope
Five modules (A, B, F, K) fully integrated and tested. Core functionality operational end-to-end. User can import, view, and navigate scores using touch or external devices.

---

## Success Criteria - Feature Complete

### C1: User can open PDF or image in app
**Definition**: User can select PDF file or camera image and import into SmartScore library.

**Acceptance Tests**:
- [ ] `/capture` page accessible from home
- [ ] Camera button launches camera app, returns image
- [ ] File picker shows PDF files, allows selection
- [ ] Module B.importPdf() called, score added to library
- [ ] Module B.importImage() called, score added to library
- [ ] Error handling: shows "File not found" if file deleted
- [ ] Error handling: shows "Invalid PDF" if corrupted file selected
- [ ] Success: new score appears in `/library` list
- [ ] Score metadata (title, composer) visible in library

**Test coverage**: Module B TEST_PLAN.md tests B-PDF-001 through B-IMG-012

---

### C2: User can manually turn pages (touch/swipe)
**Definition**: User can navigate between pages of imported score using touch controls.

**Acceptance Tests**:
- [ ] `/viewer/:id` page displays first page of score
- [ ] Module F.renderPage() renders page correctly
- [ ] "Previous" button visible and functional (decrements page)
- [ ] "Next" button visible and functional (increments page)
- [ ] Swipe left/right gestures recognized (optional, not required)
- [ ] Page number indicator shows "Page N of M"
- [ ] Cannot go below page 0 (first page) — button disabled or no-op
- [ ] Cannot go above last page — button disabled or no-op
- [ ] Page change latency < 150 ms (p95)
- [ ] Canvas re-renders without visible artifacts

**Test coverage**: Module A TEST_PLAN.md tests A-UI-003, A-UI-004; Module F TEST_PLAN.md tests F-RENDER-002 through F-RENDER-004

---

### C3: External device (BT pedal / keyboard) can turn pages
**Definition**: Bluetooth pedal or USB keyboard input triggers page navigation.

**Acceptance Tests**:
- [ ] `/settings#devices` tab accessible
- [ ] "Scan for devices" button launches Bluetooth scan
- [ ] Discovered pedal/keyboard appears in list
- [ ] User can tap device to connect
- [ ] Module K.startScan() returns stream of devices
- [ ] Module K.connect() succeeds within 2 seconds (p95)
- [ ] Module K.onAction emits DeviceAction.nextPage on pedal button 1
- [ ] Module K.onAction emits DeviceAction.previousPage on pedal button 2
- [ ] Pedal press triggers page change (Module A listens to onAction)
- [ ] Keyboard Page Down / Page Up also triggers navigation
- [ ] Device input latency < 100 ms (p95)
- [ ] Multiple presses within 50 ms debounced (no duplicate page turns)

**Test coverage**: Module K TEST_PLAN.md tests K-SCAN-001 through K-ACT-015; Module A integration test A-INT-003

---

### C4: Library management works (add, list, delete)
**Definition**: User can manage imported scores: list all scores, view details, delete scores.

**Acceptance Tests**:
- [ ] `/library` displays all imported scores in list
- [ ] Each score shows: title, composer, source type icon, date imported
- [ ] Tap score → navigate to `/viewer/:id`
- [ ] Long-press score → delete confirmation dialog
- [ ] Confirm delete → Module B.deleteScore() called, score removed
- [ ] Cancel delete → score remains
- [ ] Library list sorted by import date (newest first)
- [ ] Empty library shows "No scores yet" message
- [ ] Floating action button navigates to `/capture`
- [ ] Persistence: close app, reopen → all scores still present
- [ ] Module B.getLibrary() returns all scores correctly
- [ ] Library query time < 100 ms (p95) for 100 scores

**Test coverage**: Module B TEST_PLAN.md tests B-LIB-001 through B-LIB-008; Module A TEST_PLAN.md tests A-UI-001, A-UI-002, A-INT-001

---

### C5: Pre/post comparison display works
**Definition**: (Optional, not required for minimum Stage 1 but module structure supports it) User can view before/after versions of edited scores side-by-side.

**Acceptance Tests**:
- [ ] If Module C fully implemented: comparison toggle button visible
- [ ] Clicking toggle shows original + edited score side-by-side
- [ ] Changes highlighted visually (e.g., red outline)
- [ ] If Module C not implemented: graceful no-op (button greyed out or hidden)
- [ ] If implemented: rendering latency < 200 ms for comparison

**Test coverage**: Module A TEST_PLAN.md integration test (conditional); Module C contract skeleton exists

---

### C6: Debug panel shows internal state (dev mode)
**Definition**: In development builds, `/debug` page displays app state for testing/debugging.

**Acceptance Tests**:
- [ ] Build flavor = "dev" makes `/debug` route accessible
- [ ] Build flavor = "prod" hides `/debug` (redirect to `/library`)
- [ ] Debug page shows:
  - [ ] Current route
  - [ ] Provider state (library size, current page, devices)
  - [ ] Recent input events (last 20)
  - [ ] FPS / memory usage
  - [ ] Module B: score count, DB size
  - [ ] Module F: last render time, current zoom
  - [ ] Module K: connected devices, last action
- [ ] Debug logs accessible (enable debug logging toggle)
- [ ] State values human-readable (JSON format acceptable)

**Test coverage**: Module A TEST_PLAN.md tests A-ROUTE-006, A-ROUTE-007

---

## Success Criteria - Testing Complete

### C7: All module tests pass
**Definition**: Complete test suite for all 5 modules passes without failures.

**Acceptance Tests**:
- [ ] Module A: 48/48 test cases pass (routing, state, UI, integration)
- [ ] Module B: 54/54 test cases pass (import, library, storage, concurrency)
- [ ] Module F: 67/67 test cases pass (render, layout, hit test, visual regression)
- [ ] Module K: 56/56 test cases pass (scan, connect, action, debounce)
- [ ] Total: 225/225 tests pass
- [ ] No flaky tests (all pass consistently)
- [ ] All timeouts < configured threshold (typically 10 seconds per test)
- [ ] Coverage report generated (target: > 80% code coverage per module)

**Test execution**:
```bash
flutter test test/modules/a_app_shell_test.dart        # 48 tests
flutter test test/modules/b_score_input_test.dart      # 54 tests
flutter test test/modules/f_score_renderer_test.dart   # 67 tests
flutter test test/modules/k_external_device_test.dart  # 56 tests
# Total: 225 tests
```

**Pass criteria**: 225/225 pass, 0 failures

---

### C8: All module metrics collected
**Definition**: Performance and resource metrics established for all modules.

**Acceptance Tests**:
- [ ] Module B metrics: import time (PDF, image, MusicXML), library query time, storage usage
  - [ ] Single-page PDF: p95 < 500 ms
  - [ ] Image import: p95 < 500 ms
  - [ ] MusicXML parse: p95 < 1000 ms
  - [ ] Library query (100 scores): p95 < 100 ms
- [ ] Module F metrics: render time, hit test latency, memory per page
  - [ ] Single-measure page: p95 < 20 ms
  - [ ] 24-measure page: p95 < 100 ms
  - [ ] Hit test: p95 < 10 ms
- [ ] Module K metrics: action latency, connection time, debounce effectiveness
  - [ ] Bluetooth action latency: p95 < 100 ms
  - [ ] Keyboard action latency: p95 < 50 ms
  - [ ] Connection establish: p95 < 3 s
- [ ] Module A metrics: startup time, route navigation, FPS
  - [ ] Cold startup: p95 < 2 seconds
  - [ ] Route navigation: p95 < 150 ms
  - [ ] FPS on typical device: 60 (or 55+ on slower devices)
- [ ] All metrics documented in respective METRICS.md files
- [ ] Baseline established for regression testing (CI/CD)

**Data collection**: Automated benchmarks run weekly, results tracked in spreadsheet/dashboard

---

## Success Criteria - Requirements Met

### C9: All module contracts fulfilled
**Definition**: Each module implements API exactly as specified in CONTRACT.md.

**Acceptance Tests**:
- [ ] Module B: importPdf(), importImage(), importMusicXml(), getLibrary(), getScore(), deleteScore(), exportMusicXml()
  - [ ] All return types match contract
  - [ ] All error codes match FAILURE_MODES.md
  - [ ] All constraints (file sizes, formats) enforced
- [ ] Module F: renderPage(), hitTest(), getPageForMeasure(), getTotalPages()
  - [ ] All return types match contract
  - [ ] Layout objects include all required fields
  - [ ] Hit test accuracy > 95%
- [ ] Module K: startScan(), connect(), disconnect(), onAction, mapMidiCC(), getConnectedDevices()
  - [ ] All return types match contract
  - [ ] Priority hierarchy enforced (user > device > auto)
  - [ ] Debounce rules applied correctly
- [ ] Module A: routes, state management, error boundary
  - [ ] All 6 routes accessible: /, /library, /viewer/:id, /settings, /capture, /debug
  - [ ] All providers initialized correctly
  - [ ] Error boundary catches unhandled exceptions

**Verification**: Code review + automated tests + manual testing

---

### C10: All failure modes tested
**Definition**: Every failure mode documented in FAILURE_MODES.md has corresponding test case.

**Acceptance Tests**:
- [ ] Module B: F-B01 through F-B07 each have test case (7 failure modes)
- [ ] Module F: F-F01 through F-F09 each have test case (9 failure modes)
- [ ] Module K: F-K01 through F-K10 each have test case (10 failure modes)
- [ ] Module A: F-A01 through F-A10 each have test case (10 failure modes)
- [ ] Total: 36+ failure mode tests
- [ ] Each test verifies:
  - [ ] Failure detected (logged, not silently ignored)
  - [ ] Recovery action taken (no crash, graceful degradation)
  - [ ] User informed (error message or silent UI change)

**Test coverage**: Documented in respective TEST_PLAN.md files

---

## Success Criteria - Documentation Complete

### C11: Contracts and specs are precise and testable
**Definition**: All CONTRACT.md, FAILURE_MODES.md, TEST_PLAN.md, METRICS.md are precise (no vague descriptions).

**Acceptance Tests**:
- [ ] Every input type has exact format specification (e.g., "UUID v4 36 chars, lowercase hex")
- [ ] Every output type has exact structure (JSON schema or typed object)
- [ ] Every API function has:
  - [ ] Exact input parameter types and constraints
  - [ ] Exact output type and range
  - [ ] All error codes explicitly listed
  - [ ] All preconditions and postconditions
  - [ ] Complexity notation (O(n), O(1), etc.)
- [ ] Every failure mode has:
  - [ ] Exact condition definition (testable)
  - [ ] Detection method (testable)
  - [ ] Recovery action (verifiable)
  - [ ] Test case with expected results
- [ ] Every metric has:
  - [ ] Exact measurement method
  - [ ] Target threshold
  - [ ] Units (ms, MB, %, etc.)
  - [ ] Sample configuration (device, input size, etc.)
- [ ] No subjective language ("fast", "slow", "good", "bad") — all quantified

**Review**: Specification review checklist (all vague language removed)

---

### C12: All modules inter-operate correctly
**Definition**: Modules communicate correctly and handle each other's errors gracefully.

**Acceptance Tests**:
- [ ] Module A → Module B: LibraryProvider calls B.getLibrary(), B.importPdf(), B.deleteScore()
  - [ ] Results correctly displayed in UI
  - [ ] Errors from B shown in snackbar/dialog
- [ ] Module A → Module F: ScoreRendererProvider calls F.renderPage()
  - [ ] PageLayout returned and rendered on canvas
  - [ ] Errors from F (e.g., invalid JSON) handled gracefully
- [ ] Module A ← Module K: onAction stream listened, emits DeviceAction
  - [ ] Page navigation triggered by device input
  - [ ] Priority hierarchy enforced (user overrides device)
  - [ ] Connection loss doesn't crash app
- [ ] Module B ↔ Module F: Score JSON from B passed to F
  - [ ] Module F validates JSON (rejects if malformed)
  - [ ] Layout calculation correct for all score types
- [ ] Module C (if implemented): uses Score JSON from B, outputs to A
  - [ ] Comparison display works correctly

**Test coverage**: Integration tests in each module TEST_PLAN.md

---

## Deployment Checklist

### Before Release
- [ ] All 225 tests passing on iOS, Android, macOS, Windows, Web
- [ ] Performance metrics within target SLAs on all platforms
- [ ] Memory profiler shows no leaks (test with DevTools)
- [ ] Code coverage > 80% per module
- [ ] Security review complete (no hardcoded secrets, no SQL injection, etc.)
- [ ] Accessibility review complete (text scaling, high contrast, screen reader)
- [ ] Localization framework in place (strings in .arb files)
- [ ] CI/CD pipeline configured (automated tests on push)
- [ ] Release notes prepared
- [ ] App signing certificates configured

### During Release
- [ ] Build APK (Android), IPA (iOS), DMG (macOS), MSIX (Windows)
- [ ] Version bumped (1.0.0 for Stage 1)
- [ ] Git tag created (v1.0.0)
- [ ] Release notes published

### Post-Release Monitoring
- [ ] Crash logs monitored (Firebase Crashlytics or equivalent)
- [ ] User feedback collected (beta testers, store reviews)
- [ ] Performance metrics tracked (weekly benchmarks)
- [ ] Issue tracking updated (GitHub Issues or JIRA)

---

## Sign-Off

**Project Completion Date**: TBD (after all criteria met)

**Stakeholders**:
- [ ] Product Manager: Feature scope acceptable
- [ ] Engineering Lead: Code quality acceptable
- [ ] QA Lead: Testing complete, all tests pass
- [ ] Tech Lead: Architecture sound, no technical debt blockers

---

## Known Limitations (Planned for Stage 2+)

1. **Module C (Comparison)**: Skeleton only, full implementation Stage 2
2. **Module D (Restoration)**: Not included Stage 1
3. **Module E (OMR)**: Stub only, calls external API or returns error
4. **Cloud sync**: No iCloud/Google Drive sync (Stage 2)
5. **Annotation**: No drawing tools (Stage 2)
6. **Export**: No PDF export (Stage 2)
7. **Undo/redo**: Limited or no undo history (Stage 2)
8. **Localization**: English only (other languages Stage 2)
9. **Themes**: Material Design 3 default only (Stage 2)
10. **Plugins**: No plugin system (Stage 3+)

---

## Appendix: Test Execution Instructions

### Setup
```bash
cd /path/to/smartscore_v2
flutter pub get
```

### Run all tests
```bash
flutter test --coverage
```

### Run specific module
```bash
flutter test test/modules/b_score_input_test.dart
flutter test test/modules/f_score_renderer_test.dart
flutter test test/modules/k_external_device_test.dart
flutter test test/modules/a_app_shell_test.dart
```

### Generate coverage report
```bash
lcov --remove coverage/lcov.info 'lib/generated/*' -o coverage/lcov.info
genhtml -o coverage/html coverage/lcov.info
open coverage/html/index.html
```

### Run integration tests
```bash
flutter drive --target=integration_test/app_test.dart
```

### Collect metrics
```bash
# Run benchmark suite (output to metrics.csv)
dart test/benchmarks/run_all.dart > metrics.csv
```

---

## References

- [Module B: Score Input & Library](../modules/B_score_input/CONTRACT.md)
- [Module F: Score Renderer](../modules/F_score_renderer/CONTRACT.md)
- [Module K: External Device](../modules/K_external_device/CONTRACT.md)
- [Module A: App Shell](../modules/A_app_shell/CONTRACT.md)
- [Score JSON Schema](./SCORE_JSON_SCHEMA.md)
