# Module F: Score Renderer - Quick Start Guide

## Installation

Add to pubspec.yaml:
```yaml
dependencies:
  smartscore_v2:
    path: ./modules/F_score_renderer
```

## Basic Usage

### 1. Parse Score and Configure Layout

```dart
import 'package:smartscore_v2/models.dart';
import 'package:smartscore_v2/layout_engine.dart';

// Parse Score JSON
final scoreJson = jsonDecode(scoreString);
final score = Score.fromJson(scoreJson);

// Create layout configuration
final config = LayoutConfig(
  measuresPerSystem: 4,
  systemsPerPage: 6,
  zoom: 1.0,
  darkMode: false,
);
```

### 2. Compute Page Layout

```dart
// Get page 0 for first part
final pageLayout = computePageLayout(
  score,
  partIndex: 0,
  pageNumber: 0,
  config,
);

print('Page ${pageLayout.pageNumber} of ${pageLayout.totalPages}');
print('Systems: ${pageLayout.systems.length}');
```

### 3. Generate Render Commands

```dart
import 'package:smartscore_v2/render_commands.dart';

final state = RenderState(
  currentMeasure: 5,
  highlightColor: 'blue',
  darkMode: false,
);

final commands = generateRenderCommands(score, pageLayout, state);
```

### 4. Render with Flutter

```dart
import 'package:smartscore_v2/score_painter.dart';
import 'package:flutter/material.dart';

@override
Widget build(BuildContext context) {
  return ScoreView(
    commands: commands,
    width: pageLayout.canvasWidth,
    height: pageLayout.canvasHeight,
  );
}
```

## Hit Testing

### Detect Clicked Element

```dart
import 'package:smartscore_v2/hit_test.dart';

void onScoreTap(Offset position, PageLayout layout) {
  final result = hitTest(position.dx, position.dy, layout);

  if (result?.type == HitType.note) {
    print('Clicked note: ${result!.noteId}');
    print('Pitch: ${result.pitch}');
    print('Measure: ${result.measureNumber}');
  } else if (result?.type == HitType.measure) {
    print('Clicked measure: ${result!.measureNumber}');
  }
}
```

### Get Beat Position

```dart
final withBeat = hitTestWithBeat(
  x, y, pageLayout,
  {'0': '4/4', '1': '3/4'}, // measure -> time signature map
);

print('Beat: ${withBeat?.beat}'); // 0.0-4.0
```

### Query Region

```dart
// Select multiple notes
final selectionRect = Rect(x: 100, y: 200, width: 300, height: 100);
final notes = notesInRegion(selectionRect, pageLayout);

for (final note in notes) {
  print('${note.pitch} in measure ${note.elementId}');
}
```

## Page Navigation

### Get Total Pages

```dart
import 'package:smartscore_v2/page_calculator.dart';

final totalPages = getTotalPages(score.totalMeasures, config);
print('Total pages: $totalPages');
```

### Get Page for Measure

```dart
final page = getPageForMeasure(measureNumber, config, score.totalMeasures);
print('Measure $measureNumber is on page $page');
```

### Get Measures for Page

```dart
final (start, end) = getMeasureRange(pageNumber, config, score.totalMeasures);
print('Page $pageNumber contains measures $start-${end-1}');
```

### Cache Strategy

```dart
final strategy = calculateCacheStrategy(currentPage, totalPages);

// Pages to keep in memory
for (final page in strategy.pagesToKeep) {
  loadPageIfNotCached(page);
}

// Pages to prerender in background
for (final page in strategy.pagesToPrerender) {
  prerender(page);
}

// Pages to evict from cache
for (final page in strategy.pagesToEvict) {
  evictFromCache(page);
}
```

## Configuration Examples

### A4 Paper, 3 Systems per Page

```dart
final config = LayoutConfig(
  paperSize: 'A4',
  measuresPerSystem: 4,
  systemsPerPage: 3,
  zoom: 1.0,
  leftMargin: 50,
  rightMargin: 50,
  topMargin: 50,
  bottomMargin: 50,
);
```

### Dark Mode

```dart
final config = LayoutConfig(
  darkMode: true,
  currentPositionColor: 'yellow',
  currentPositionOpacity: 0.3,
);
```

### Zoom Out (50%)

```dart
final config = LayoutConfig(zoom: 0.5);
```

### Zoom In (200%)

```dart
final config = LayoutConfig(zoom: 2.0);
```

## Common Patterns

### Listen to Score Taps

```dart
class ScoreWidget extends StatelessWidget {
  final Score score;
  final LayoutConfig config;

  @override
  Widget build(BuildContext context) {
    final layout = computePageLayout(score, 0, 0, config);
    final commands = generateRenderCommands(score, layout, RenderState());

    return GestureDetector(
      onTapDown: (details) {
        final result = hitTest(
          details.localPosition.dx,
          details.localPosition.dy,
          layout,
        );

        if (result?.type == HitType.note) {
          onNoteSelected(result!);
        }
      },
      child: ScoreView(
        commands: commands,
        width: layout.canvasWidth,
        height: layout.canvasHeight,
      ),
    );
  }
}
```

### Highlight Current Measure During Playback

```dart
void updatePlaybackPosition(int measureNumber) {
  final layout = computePageLayout(score, 0, 0, config);

  final state = RenderState(
    currentMeasure: measureNumber,
    highlightColor: 'green',
    darkMode: false,
  );

  final commands = generateRenderCommands(score, layout, state);

  setState(() {
    _commands = commands;
  });
}
```

### Multi-Page Viewer

```dart
class ScoreViewer extends StatefulWidget {
  final Score score;

  @override
  State<ScoreViewer> createState() => _ScoreViewerState();
}

class _ScoreViewerState extends State<ScoreViewer> {
  late int currentPage = 0;
  late LayoutConfig config;
  late PageLayout currentLayout;

  @override
  void initState() {
    super.initState();
    config = LayoutConfig();
    _updatePage(0);
  }

  void _updatePage(int page) {
    setState(() {
      currentPage = page;
      currentLayout = computePageLayout(widget.score, 0, page, config);
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = getTotalPages(widget.score.totalMeasures, config);
    final commands = generateRenderCommands(
      widget.score, currentLayout, RenderState(),
    );

    return Column(
      children: [
        ScoreView(
          commands: commands,
          width: currentLayout.canvasWidth,
          height: currentLayout.canvasHeight,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: currentPage > 0 ? () => _updatePage(currentPage - 1) : null,
            ),
            Text('Page ${currentPage + 1} of $totalPages'),
            IconButton(
              icon: Icon(Icons.arrow_forward),
              onPressed: currentPage < totalPages - 1 ? () => _updatePage(currentPage + 1) : null,
            ),
          ],
        ),
      ],
    );
  }
}
```

## Test Examples

### Test Proportional Spacing

```dart
test('Measures have proportional widths', () {
  final config = LayoutConfig(measuresPerSystem: 4);

  // Create score with measures of equal duration
  final score = Score(
    format: '1.0',
    parts: [Part(id: 'P1', name: 'Test', instrument: 'test', staves: ['S1'], clef: 'treble')],
    measures: [
      Measure(number: 0, notes: [Note(id: 'N1', step: 'C', octave: 4, duration: 1.0, ...)], ...),
      Measure(number: 1, notes: [Note(id: 'N2', step: 'D', octave: 4, duration: 1.0, ...)], ...),
    ],
  );

  final layout = computePageLayout(score, 0, 0, config);
  final measures = layout.systems[0].measures;

  // Equal duration should produce equal widths
  expect(measures[0].bounds.width, equals(measures[1].bounds.width));
});
```

### Test Hit Detection

```dart
test('Hit on note returns note type', () {
  final layout = computePageLayout(score, 0, 0, config);
  final note = layout.systems[0].measures[0].notes[0];

  final result = hitTest(
    note.bounds.x + (note.bounds.width / 2),
    note.bounds.y + (note.bounds.height / 2),
    layout,
  );

  expect(result?.type, HitType.note);
  expect(result?.noteId, 'N1');
});
```

## Troubleshooting

### Empty Score

```dart
if (layout.isEmpty) {
  print('Score has no measures');
}
```

### Invalid Page

```dart
if (pageNumber < 0 || pageNumber >= getTotalPages(...)) {
  print('Page out of range');
  return;
}
```

### Hit Test Returns Null

```dart
final result = hitTest(x, y, layout);
if (result == null) {
  print('No element at ($x, $y)');
} else if (result.type == HitType.empty) {
  print('Clicked empty space');
}
```

## API Reference Quick Links

- **Layout**: `computePageLayout()` → `PageLayout`
- **Hit Testing**: `hitTest()` → `HitTestResult?`
- **Rendering**: `generateRenderCommands()` → `List<RenderCommand>`
- **Pages**: `getTotalPages()`, `getPageForMeasure()`, `getMeasureRange()`
- **Flutter**: `ScoreView`, `ScorePainter`

## Performance Tips

1. **Cache pages**: Keep 3-page cache (current ± 1)
2. **Prerender**: Background render next/previous pages
3. **Debounce**: Don't hit test on every mouse move
4. **Zoom levels**: Precompute common zoom levels
5. **Large scores**: Consider spatial indexing (future)

## See Also

- **README.md** - Full documentation with examples
- **IMPLEMENTATION_SUMMARY.md** - Implementation details
- **MODULE_OVERVIEW.md** - Complete module overview
- **CONTRACT.md** - Original specification
