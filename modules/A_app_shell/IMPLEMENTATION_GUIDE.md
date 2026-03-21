# Module A: App Shell - Implementation Guide

## Overview

This document describes the complete implementation of Module A (App Shell) for SmartScore, a Flutter-based music score viewer with integrated page-turning and device management.

## Architecture

### Entry Point: `lib/main.dart`

**Purpose**: Application bootstrap and initialization

**Key Features**:
- MultiProvider setup with all service providers
- Global error handling via FlutterError.onError
- Platform-specific configuration (SystemChrome)
- Boot logging and timing metrics
- ErrorBoundary wrapper for unhandled exceptions

**Flow**:
```
main()
  ├─ _initializeLogging()
  ├─ _configurePlatform()
  ├─ AppState.initialize()
  ├─ createProviders(appState)
  ├─ ErrorBoundary
  │  └─ MultiProvider
  │     └─ SmartScoreApp (MaterialApp.router)
  └─ Boot log: "Application ready in Xms"
```

### Configuration: `lib/config.dart`

**Purpose**: Centralized configuration and feature flags

**Key Constants**:
- `kDebugMode`: Debug builds only
- `enableDebugMode`: Dev flavor only
- `enableComparison`: Module C feature flag
- `enableExternalDevice`: Module K feature flag
- `PerformanceTargets`: SLA thresholds (ms)
- `MemoryLimits`: Memory usage targets (MB)

### Theme: `lib/theme.dart`

**Purpose**: Material Design 3 theme with score-optimized colors

**Light Theme**:
- Background: #FFFDE7 (scoreBackground)
- Foreground: #212121 (scoreForeground)
- Highlight: Blue with 40% opacity
- Accent: Amber (page turn indicator)

**Dark Theme**:
- Background: #1A1A1A
- Surfaces: #2A2A2A, #3A3A3A
- Highlight: Light Blue (#4A90FF)
- Accent: Light Amber

### Router: `lib/router.dart`

**Purpose**: GoRouter navigation configuration

**Routes**:
```
/                           → HomeScreen (library)
├─ /library                → HomeScreen (alias)
├─ /viewer/:id             → ScoreViewerScreen
├─ /settings               → SettingsScreen
├─ /capture                → CaptureScreen
└─ /debug                  → DebugScreen (dev only)
```

**Deep Link Support**:
```
smartscore:///library
smartscore:///viewer/550e8400-e29b-41d4-a716-446655440000
smartscore:///settings
smartscore:///capture
smartscore:///debug
```

### App Shell: `lib/app.dart`

**Purpose**: Root widget with theme and routing

**Features**:
- MaterialApp.router with GoRouter
- Theme switching via UIStateProvider
- Responsive across all platforms
- Localization framework (English baseline)

## State Management

### Central State: `lib/state/app_state.dart`

**Purpose**: Holds references to all modules and app-level state

**Key Fields**:
- `activeScoreId`: Currently loaded score
- `currentScoreJson`: Active score data
- `currentPage`: Current page in viewer
- `eventLog`: Last 100 app events

**Key Methods**:
- `setActiveScore(scoreId, scoreJson)`: Load score
- `goToPage(pageNumber)`: Navigate pages
- `logEvent(type, data)`: Record event
- `dumpState()`: JSON for debugging

### UI State: `lib/state/ui_state_provider.dart`

**Purpose**: App-level UI preferences

**State**:
- `darkMode`: Boolean theme toggle
- `zoomLevel`: 0.5x - 2.0x (default 1.0x)
- `debugMode`: Dev-only flag
- `systemsPerPage`: 1-4 (default 2)
- `measuresPerSystem`: 1-6 (default 4)

**Key Class**: `LayoutConfig`
- Combines layout settings with page dimensions
- Converts to JSON for Module F

### Providers

#### ScoreLibraryProvider: `lib/state/score_library_provider.dart`

**Purpose**: Wraps Module B (Score Input & Library)

**State**:
- `allScores`: List of library entries
- `selectedScoreId`: Current selection
- `isLoading`: Import/load status
- `lastError`: Error messages

**Key Methods**:
- `loadLibrary()`: Fetch all scores from Module B
- `getScore(id)`: Load single score JSON
- `deleteScore(id)`: Remove from library
- `selectScore(id)`: Track selection

**Integration with Module B**:
```dart
// Load library
final result = await moduleB.getLibrary();
// Returns: Result<List<ScoreEntry>, ImportError>

// Get single score (with scoreJson from Module E)
final result = await moduleB.getScore(scoreId);
// Returns: Result<ScoreEntry, ImportError>
// ScoreEntry.scoreJson comes from Module E

// Delete score
final result = await moduleB.deleteScore(scoreId);
// Returns: Result<bool, ImportError>
```

#### ScoreRendererProvider: `lib/state/score_renderer_provider.dart`

**Purpose**: Wraps Module F (Score Renderer)

**State**:
- `currentPage`: 0-based page index
- `totalPages`: Total pages in score
- `currentPageLayout`: PageLayout from Module F
- `isRendering`: Render in progress
- `lastError`: Error messages

**Key Methods**:
- `renderPage(scoreJson, pageNum, layoutConfig)`: Render via Module F
- `nextPage()`, `previousPage()`: Navigate
- `hitTest(scoreJson, x, y, config)`: Find element at position

**Integration with Module F**:
```dart
// Get total pages
final result = await moduleF.getTotalPages(scoreJson, layoutConfig);
// Returns: Result<int, RenderError>

// Render page
final result = await moduleF.renderPage(scoreJson, pageNum, layoutConfig);
// Returns: Result<PageLayout, RenderError>
// PageLayout contains: systems, measures, bounds, etc.

// Hit test
final result = await moduleF.hitTest(scoreJson, x, y, layoutConfig);
// Returns: Result<Map<string, dynamic>, RenderError>
// Contains: measureNumber, part, staff, etc.
```

#### DeviceProvider: `lib/state/device_provider.dart`

**Purpose**: Wraps Module K (External Device)

**State**:
- `connectedDevices`: List of DeviceInfo
- `lastAction`: Latest DeviceAction
- `isScanning`: Scan in progress
- `lastError`: Error messages

**Key Methods**:
- `initialize()`: Listen to Module K.onAction stream
- `scanDevices(type)`: Find devices
- `connectDevice(type, id)`: Establish connection
- `disconnectDevice(id)`: Close connection

**Integration with Module K**:
```dart
// Listen to actions (automatic in initialize())
moduleK.onAction.listen((action) {
  // action.type: "nextPage" | "previousPage" | "hold" | etc.
  // action.timestamp: when action occurred
  // action.data: optional extra data
});

// Scan for Bluetooth devices
moduleK.scan("bluetooth").listen((device) {
  // device.id, device.name, device.type
});

// Connect to device
final device = await moduleK.connect("bluetooth", deviceId);

// Disconnect
await moduleK.disconnect(deviceId);
```

#### ComparisonProvider: `lib/state/comparison_provider.dart`

**Purpose**: Wraps Module C (Score Comparison)

**State**:
- `showComparison`: Toggle visibility
- `originalJson`: Before-edit JSON
- `editedJson`: After-edit JSON
- `changes`: Detected differences

**Key Methods**:
- `enableComparison(orig, edited)`: Start comparison
- `disableComparison()`: Hide comparison
- `getChangeSummary()`: Count changes by type

## Screens

### Home Screen: `lib/screens/home_screen.dart`

**Purpose**: Library list and import entry point

**Features**:
- Loads library on first mount
- Lists all scores with metadata
- Long-press to delete with confirmation
- Tap to navigate to viewer
- FAB to import
- Settings button in app bar
- Error display with retry

**Widgets Used**:
- `ScoreCard`: Reusable score list item
- `LibraryProvider`: Consumer for state

### Score Viewer: `lib/screens/score_viewer_screen.dart`

**Purpose**: Display and interact with loaded score

**Features**:
- Loads score JSON on mount
- Tap zones: left 15% (previous), right 15% (next)
- Swipe left/right for page navigation
- Keyboard: Page Up/Down (if Module K enabled)
- Device actions from Module K trigger page turns
- Fullscreen mode (hides UI)
- Debug overlay shows:
  - Current/total pages
  - Render status
  - Device events
- Top bar: title, composer, fullscreen, debug toggle
- Bottom bar: prev/next buttons, page indicator, measure info

**Canvas Placeholder**:
- Currently shows simple placeholder (measures 800x1100)
- In production: Uses Module F's ScorePainter via renderCommands pipeline

**Device Integration**:
```dart
// Listen to device actions
Consumer<DeviceProvider>(builder: (context, devices, _) {
  final lastAction = devices.lastAction;
  if (lastAction?['type'] == 'nextPage') {
    _nextPage();
  }
});
```

### Settings Screen: `lib/screens/settings_screen.dart`

**Purpose**: App configuration and device management

**Tabs**:

1. **Display**
   - Dark mode toggle (updates theme in real-time)
   - Zoom level slider (0.5x - 2.0x)
   - Measures per system dropdown (1-6)
   - Systems per page dropdown (1-4)

2. **Devices**
   - "Scan for Devices" button
   - Connected devices list
   - Disconnect button per device
   - Supported device types info
   - Page turn mode info (manual only, Stage 1)

3. **About**
   - App version
   - App name
   - Build flavor
   - Credits
   - Legal info
   - Performance targets (SLAs)

### Capture Screen: `lib/screens/capture_screen.dart`

**Purpose**: Import scores from various sources

**Features**:
- Three import buttons:
  - PDF file picker
  - MusicXML file picker
  - Image/camera picker
- Shows loading indicator during import
- Calls Module B import methods:
  - `importPdf(filePath)` → Result<ScoreEntry, ImportError>
  - `importMusicXml(filePath)` → Result<ScoreEntry, ImportError>
  - `importImage(bytes)` → Result<ScoreEntry, ImportError>
- On success: navigates to viewer
- On error: shows snackbar with message
- Refreshes library after import

### Debug Screen: `lib/screens/debug_screen.dart`

**Purpose**: Internal state inspection (dev mode only)

**Tabs**:

1. **State**
   - Library state dump (scores, selection, loading)
   - Renderer state (current/total pages, layout, render status)
   - Device state (connections, last action)
   - UI state (theme, zoom, settings)
   - Comparison state (if Module C enabled)

2. **Events**
   - Last 50 events from event log
   - Format: type, timestamp, data
   - Shows latest first

3. **Modules**
   - Module status cards (A, B, E, F, K)
   - Status indicator (green = initialized)
   - Key features per module

4. **JSON**
   - Score JSON inspector
   - Shows raw Module E output for selected score
   - Selectable text for copy

5. **Performance**
   - Target SLAs (all metrics)
   - Memory limits
   - "Start Profiling" button (trigger metrics collection)

## Widgets

### ScoreCard: `lib/widgets/score_card.dart`

**Props**:
- `score`: Map with id, title, composer, sourceType, pageCount, measureCount, dateImported
- `onTap`: Navigate to viewer
- `onDelete`: Show delete confirmation

**Features**:
- Title + composer
- Source type icon (PDF red, Image orange, MusicXML blue)
- Page/measure counts
- Relative date ("2 hours ago")
- Long-press context menu (open/delete)

### ImportDialog: `lib/widgets/import_dialog.dart`

**Purpose**: Simple dialog to select import format

**Options**: PDF, MusicXML, Image

### PageIndicator: `lib/widgets/page_indicator.dart`

**Props**:
- `currentPage`: 0-based index
- `totalPages`: Total pages
- `onPageChanged`: Callback for slider

**Features**:
- Slider (0 to totalPages-1)
- Page label: "Page X of Y"
- Progress percentage (amber badge)

## Integration Points

### Module B (Score Input)

**On Home Screen**:
```dart
library.loadLibrary()  // Calls moduleB.getLibrary()
```

**On Capture Screen**:
```dart
moduleB.importPdf(path)
moduleB.importMusicXml(path)
moduleB.importImage(bytes)
```

**On Viewer Screen**:
```dart
library.getScore(scoreId)  // Get scoreJson from Module E
```

### Module E (Music Normalizer)

**Consumed indirectly through Module B**:
- Module B.importMusicXml() → calls Module E internally
- Module B.getScore() returns scoreJson from Module E
- Module E.parse(xml) → Score JSON

### Module F (Score Renderer)

**On Viewer Screen**:
```dart
// Get page count
moduleF.getTotalPages(scoreJson, layoutConfig)

// Render specific page
moduleF.renderPage(scoreJson, pageNum, layoutConfig)

// Hit test
moduleF.hitTest(scoreJson, x, y, layoutConfig)
```

**LayoutConfig from UIStateProvider**:
```dart
{
  measuresPerSystem: 4,
  systemsPerPage: 2,
  zoomLevel: 1.0,
  pageWidth: 8.5,
  pageHeight: 11.0,
  margins: 40,
}
```

### Module K (External Device)

**On Device Provider**:
```dart
// Listen to actions
moduleK.onAction.listen((action) {
  // action.type: DeviceActionType.nextPage | previousPage | ...
  // Page navigation handled by UI
});

// Device management
moduleK.scan("bluetooth")
moduleK.connect("bluetooth", deviceId)
moduleK.disconnect(deviceId)
moduleK.getConnectedDevices()
```

## Error Handling

### Global Error Boundary

```dart
class ErrorBoundary extends StatefulWidget {
  @override
  _ErrorBoundaryState createState() => _ErrorBoundaryState();

  // Catches FlutterError and shows dialog
  // Logs error with stack trace
}
```

### Per-Module Error Propagation

```dart
// Library screen
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Error: ${library.lastError}'))
);

// Dialog-based
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Error'),
    content: Text(error.message),
    actions: [TextButton(...)]
  )
);
```

### Error Recovery

- **Module B**: Show snackbar, allow retry
- **Module F**: Show snackbar, fallback to placeholder
- **Module K**: Disable device controls, log error, continue
- **Import failures**: Return to capture screen, show error message

## Performance Optimization

### Provider Updates

- Only listen to relevant providers: `Consumer<X>` instead of `Consumer`
- Avoid unnecessary rebuilds: `listen: false` for one-time reads
- Debounce device events in Module K

### Memory Management

- Dispose listeners in `dispose()` methods
- Clear event log to last 100 events
- Use `SingleChildScrollView` for long lists
- Lazy-load score JSON only when viewing

### Metrics Collected

1. **Startup Time**: Boot → app ready (target: < 2s)
2. **Route Navigation**: Route transition latency (target: < 150ms)
3. **Page Render**: Module F render time (target: < 100ms)
4. **Device Action**: Input → page change (target: < 100ms)
5. **Library Query**: Load all scores (target: < 100ms for 100 scores)

## Testing

### Unit Tests

- Provider state transitions
- Route navigation
- Error handling
- Layout config calculations

### Integration Tests

- App opens with empty library
- Import score (mocked Module B)
- Navigate to viewer
- Page navigation (prev/next)
- Device action triggers page change
- Settings persist across app restart

### Test Execution

```bash
# All tests
flutter test --coverage

# Specific module
flutter test test/integration_test.dart

# With specific device
flutter test -d emulator test/

# Watch mode
flutter test --watch test/
```

## Build Flavors

### Development Build

```bash
flutter run --flavor dev
```

Features:
- Debug mode enabled
- `/debug` route accessible
- Verbose logging
- All feature flags enabled

### Production Build

```bash
flutter run --flavor prod
```

Features:
- Debug mode disabled
- `/debug` route hidden (redirects to `/library`)
- Minimal logging
- Feature flags per config

## Known Limitations

1. **Score Canvas**: Currently placeholder (blank page)
   - Production: Uses Module F's ScorePainter
   - Renders PageLayout from Module F via RenderCommands

2. **File Picker**: Simplified (uses dialogs)
   - Production: Uses `file_picker` and `image_picker` plugins

3. **Device Integration**: Mocked
   - Production: Real Bluetooth, MIDI, keyboard handlers via Module K

4. **No Annotation Tools**: Drawing not supported (Stage 2)

5. **No PDF Export**: Print unsupported (Stage 2)

6. **Single Active Score**: No multi-window support (Stage 1)

7. **Local Storage Only**: No cloud sync (Stage 1)

## Future Enhancements (Stage 2+)

- Cloud sync (iCloud, Google Drive)
- Offline mode
- Custom themes
- Annotation tools
- PDF export
- Multi-window support
- Plugin system
- Advanced search/filters
- Undo/redo history
- Score comparison UI
- Auto page turning (Module I)
