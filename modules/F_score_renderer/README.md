# Module F: Score Renderer

## Module Purpose
Real-time visual rendering of music notation from normalized Score JSON. Provides layout metrics for page/system/measure boundaries, hit test support for interactive element selection, and configurable appearance (zoom, dark mode, custom fonts).

**Responsibility**: Parse JSON → Layout calculation → Canvas rendering → Geometry queries
**Consumers**: Module A (UI display), Module C (pre/post comparison), Module K (position tracking)

---

## Architecture Overview

```
Score JSON (Module B/E)
    ↓
Validation & Parsing
    ↓
Layout Calculation (pages, systems, measures, notes)
    ↓
Canvas Rendering (draw calls)
    ↓
PageLayout + Interactive Query (hit test, page lookup)
    ↓
UI Display (Module A) / Comparison (Module C) / Position Tracking (Module K)
```

---

## Input/Output Summary

### Accepted Inputs
- **Score JSON**: Conforming to SCORE_JSON_SCHEMA.md (1+ parts, 1+ measures)
- **Render config**: zoom (0.5–4.0×), darkMode (bool), paper size (A4/Letter), custom margins
- **Current position**: Optional page/system/measure/beat for highlight overlay
- **Hit test queries**: (x, y) pixel coordinates for interactive hit testing

### Output Formats
- **PageLayout**: Page geometry with systems, measures, notes, bounds, text positions
- **HitTestResult**: Element type (note/rest/measure/staff), pitch, beat, confidence
- **Canvas commands**: Platform-agnostic draw commands (fill, stroke, text)
- **Metrics**: Render time, layout bounds, note positions for module integration

### Supported Notation
- **Clefs**: Treble, bass, alto, tenor, grand staff
- **Keys**: Up to 7 sharps/flats (C, F, G, D, A, E, B, Bb, Eb, Ab, Db, Gb, Cb)
- **Time signatures**: All simple/compound (2/4, 3/4, 4/4, 6/8, 12/8, 5/4, 7/8, etc.)
- **Notes**: A0–C8 range, all durations (whole to thirty-second)
- **Rests**: Corresponding all durations
- **Symbols**: Barlines, repeats, measure numbers, rehearsal marks, accidentals, stems, beams, dots
- **Articulations**: Staccato, accent, tenuto, marcato (rendered as symbols)
- **Dynamics**: ppp–fff text indicators
- **Special**: Clef changes, key changes, time changes (mid-score supported)

---

## API Quick Reference

### Rendering Functions
```dart
// Render single page to layout
PageLayout renderPage(String scoreJson, int page, RenderConfig config)

// Get total page count for score
int getTotalPages(String scoreJson, RenderConfig config)

// Find which page contains measure
int getPageForMeasure(int measureNumber, RenderConfig config)
```

### Interactive Functions
```dart
// Hit test at pixel coordinates
HitTestResult? hitTest(Point position, PageLayout pageLayout)
```

---

## Configuration Example

```dart
const config = RenderConfig(
  zoom: 1.0,                            // 100% size
  darkMode: false,                      // Light background
  measuresPerSystem: 4,                 // 4 measures per line
  systemsPerPage: 6,                    // 6 systems per page
  showMeasureNumbers: true,             // Show measure numbers
  showRehearsalMarks: true,             // Show rehearsal marks
  currentPositionColor: '#0066FF',      // Blue highlight
  currentPositionOpacity: 0.5,          // 50% opacity
  paperSize: PaperSize.A4,              // A4 dimensions
  marginTop: 40,                        // Pixels
  marginBottom: 40,
  marginLeft: 40,
  marginRight: 40
);
```

---

## Usage Example

```dart
import 'package:smartscore/modules/f_score_renderer.dart';

final renderer = ScoreRenderer();

// Get total page count
final totalPages = renderer.getTotalPages(scoreJsonString, config);
print('Score has $totalPages pages');

// Render first page
final layout = renderer.renderPage(scoreJsonString, 0, config);
print('Page 0: ${layout.systems.length} systems');

// Draw to canvas
canvas.drawPageLayout(layout, config);

// Handle user tap
final hitResult = renderer.hitTest(tapPosition, layout);
if (hitResult?.type == HitTestResultType.note) {
  print('Tapped note: ${hitResult?.pitch}');
  // Update current position in Module K
}

// Navigate to measure
final page = renderer.getPageForMeasure(measureNumber, config);
final layout2 = renderer.renderPage(scoreJsonString, page, config);
```

---

## Dependencies
- **Canvas abstraction**: Custom or platform-specific (Skia, Metal, Direct2D, WebCanvas)
- **Font engine**: SMuFL-compliant music fonts (e.g., Bravura, MusScore)
- **Geometry library**: Rectangles, paths, transforms
- **Score JSON parser**: Internal to Module F, conforms to schema

---

## Error Handling

All functions return results or null gracefully.

```dart
// Render non-existent page
final layout = renderer.renderPage(scoreJson, 999, config);
if (layout.systems.isEmpty) {
  print('Page out of range');
}

// Hit test outside bounds
final hit = renderer.hitTest({x: 9999, y: 9999}, layout);
if (hit?.type == HitTestResultType.none) {
  print('Clicked outside all elements');
}
```

**No exceptions thrown**. All error cases return empty/default values.

---

## Performance Characteristics

**Target SLAs** (p95):
- Single-measure page: < 20 ms
- Typical page (24 measures): < 100 ms
- Hit test: < 10 ms
- Memory per page: < 100 MB

See METRICS.md for detailed benchmarks by score complexity, device hardware, and zoom level.

---

## Known Limitations

1. **Clef vertical position**: Assumed at standard position; custom positions not supported
2. **Font coverage**: Only SMuFL-compliant fonts; other music fonts may not render correctly
3. **Ledger lines**: Limited to ±3 octaves from staff; extreme pitches render without ledger lines
4. **Bezier curves**: Not supported for advanced articulation shapes
5. **Colored notes**: Assuming monochrome; colored notation not fully supported
6. **Text rotation**: Rehearsal marks not rotated; always horizontal
7. **Grace notes**: Not distinguished from regular notes; rendered at full size
8. **Tuplets**: Visual brackets not rendered; notation only
9. **Page breaks**: Hard page breaks in JSON not respected; calculated by measuresPerSystem/systemsPerPage

---

## Integration with Other Modules

### Module B (Score Input)
- **Input**: Score JSON from B's versions
- **Dependency**: B.getScore(id) → retrieves active version for rendering

### Module C (Comparison)
- **Input**: Two Score JSONs (original + edited)
- **Output**: Layout geometry for side-by-side rendering
- **Interaction**: Hit test coordinates mapped to comparison highlights

### Module K (External Devices)
- **Input**: Current measure/beat from device
- **Output**: PageLayout to calculate highlight position
- **Interaction**: getPageForMeasure() determines which page to display

### Module A (App Shell)
- **Input**: Score ID from library
- **Output**: PageLayout for UI rendering
- **Interaction**: renderPage() on demand for current page

---

## Testing

Run module tests with:
```bash
flutter test test/modules/f_score_renderer_test.dart
```

See TEST_PLAN.md for 67 test cases covering:
- Render correctness (clefs, keys, times, notes, rests, articulations)
- Layout algorithms (pagination, measure spacing, system breaks)
- Hit test accuracy (note/measure/staff/barline detection)
- Visual regression (golden image comparison)
- Performance benchmarks
- Edge cases (empty scores, extreme zoom, invalid JSON)

---

## Debugging

Enable debug logging:
```dart
renderer.enableDebugLogging = true;
```

Logs include:
- Layout calculation timing and measurements
- Render phase breakdown (clef, notes, text, etc.)
- Hit test candidate searching
- Performance metrics per page

Logs written to:
```
iOS/macOS:   ~/Library/Logs/smartscore/f_renderer.log
Android:     /data/user/0/com.smartscore/logs/f_renderer.log
```

---

## Optimization Tips

1. **Cache PageLayouts**: Reuse PageLayout from previous renders if config unchanged
2. **Spatial indexing**: Use quadtree for hit tests on dense pages (> 100 notes)
3. **Prerender adjacent pages**: Background render page ±1 while user views current page
4. **Limit font sizes**: Use fixed font sizes (not dynamic scaling) for faster text rendering
5. **Batch canvas calls**: Collect draw commands and flush in single batch

---

## Version History

**v1.0.0**: Initial release
- Standard music notation support
- Configurable layout (zoom, margins, measures per system)
- Hit test support
- 67 test cases passing
- All target SLAs met

---

## Roadmap (Future Releases)

- [ ] Tablature notation (guitar tabs)
- [ ] Ancient notation (mensural, Gregorian chant)
- [ ] Colored notes and highlights
- [ ] Grace note special rendering
- [ ] Tuplet bracket visualization
- [ ] Bezier curve support for slurs
- [ ] Text rotation (rehearsal marks, dynamics)
- [ ] Custom font support (non-SMuFL)
- [ ] Export to PDF
- [ ] SVG output
