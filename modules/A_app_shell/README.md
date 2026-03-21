# Module A: App Shell

## Module Purpose
Platform-agnostic foundation for SmartScore. Orchestrates all modules (B, C, F, K) through centralized state management and routing. Provides consistent UX across iOS, Android, macOS, Windows, and Web.

**Responsibility**: Routes → State → Modules → UI rendering
**Dependencies**: Flutter 3.2+, all other modules

---

## Architecture Overview

```
App Entry Point (main.dart)
    ↓
ErrorBoundary (global error handler)
    ↓
MultiProvider (all modules as providers)
    ↓
GoRouter (navigation)
    ↓
MaterialApp (theme, localization)
    ↓
Routes: /, /library, /viewer/:id, /settings, /capture, /debug
    ↓
Consumers (widgets listening to providers)
```

---

## Platform Support

### Minimum Requirements
| Platform | Min Version | Notes |
|----------|-------------|-------|
| iOS | 12.0 | iPhone 6s+ |
| Android | 7.0 (API 24) | Most devices |
| macOS | 10.14 | Intel + Apple Silicon |
| Windows | 10 (build 19041) | Anniversary update+ |
| Web | Chrome, Safari, Firefox | Evergreen versions |

### Required Permissions
- **iOS**: NSCameraUsageDescription, NSBluetoothPeripheralUsageDescription, NSBluetoothAlwaysAndWhenInUseUsageDescription
- **Android**: CAMERA, BLUETOOTH, BLUETOOTH_SCAN, WRITE_EXTERNAL_STORAGE
- **macOS/Windows**: File picker (user grant)

---

## Route Map

### Hierarchy
```
/ (Root → /library)
├─ /library              Home, score list, import
├─ /viewer/:id           Active score display
├─ /settings             App config, device management
├─ /capture              Image/PDF/MusicXML import
└─ /debug                Dev mode (build flavor dependent)
```

### Deep Links
```
smartscore:///library
smartscore:///viewer/550e8400-e29b-41d4-a716-446655440000
smartscore:///settings
smartscore:///capture
```

---

## State Management Architecture

### Providers Overview
```dart
// Expose each module as a ChangeNotifier
providers: [
  ChangeNotifierProvider(create: (_) => ScoreLibraryProvider(moduleB)),
  ChangeNotifierProvider(create: (_) => ScoreRendererProvider(moduleF)),
  ChangeNotifierProvider(create: (_) => ComparisonProvider(moduleC)),
  ChangeNotifierProvider(create: (_) => DeviceProvider(moduleK)),
  ChangeNotifierProvider(create: (_) => UIStateProvider()),
]
```

### State Flow
```
User Action (tap button)
  ↓
Provider listener triggered
  ↓
Provider calls module API
  ↓
Provider notifyListeners()
  ↓
Widgets rebuild with new state
```

### Consumption
```dart
Consumer<ScoreLibraryProvider>(
  builder: (context, library, _) {
    return ListView(
      children: library.allScores.map(...).toList(),
    );
  },
)
```

---

## Module Integration

### Module B (Score Input)
- **Init**: Creates SQLite DB, loads library
- **Consumed**: ScoreLibraryProvider wraps Module B
- **Actions**: Import PDF/image/MusicXML, delete score

### Module F (Score Renderer)
- **Init**: Loads music fonts, initializes canvas
- **Consumed**: ScoreRendererProvider wraps Module F
- **Actions**: Render page, hit test, get layout

### Module K (External Device)
- **Init**: Starts Bluetooth scan on demand
- **Consumed**: DeviceProvider listens to K.onAction stream
- **Actions**: Connect device, map MIDI CC, handle page turn

### Module C (Comparison)
- **Init**: Lazily initialized when comparison mode enabled
- **Consumed**: ComparisonProvider stores original/edited JSONs
- **Actions**: Generate diff, highlight changes

---

## Configuration

### Build Flavors
```bash
# Development
flutter run --flavor dev

# Production
flutter run --flavor prod
```

### Feature Flags (lib/features.dart)
```dart
const bool enableDevMode = true;        // Dev flavor only
const bool enableComparison = true;     // Module C
const bool enableExternalDevice = true; // Module K
```

### Localization (lib/l10n/app_en.arb)
```json
{
  "appTitle": "SmartScore",
  "libraryTitle": "Score Library",
  "viewerTitle": "Score Viewer",
  "settingsTitle": "Settings"
}
```

---

## Usage Examples

### Launch App
```bash
# iOS
flutter run -t lib/main.dart --flavor prod

# Android
flutter run -t lib/main.dart --flavor prod

# Web
flutter run -d chrome --target lib/main.dart
```

### Navigate to Score Viewer
```dart
// Programmatically
GoRouter.of(context).push('/viewer/550e8400-e29b-41d4-a716-446655440000');

// Deep link
context.go('smartscore:///viewer/550e8400-e29b-41d4-a716-446655440000');
```

### Listen for Device Actions
```dart
// In a widget
Consumer<DeviceProvider>(
  builder: (context, devices, _) {
    // devices.lastAction contains latest DeviceAction
    // UI can react to page turn, hold, etc.
  },
)
```

### Import Score
```dart
// Triggered from /capture
final result = await moduleB.importPdf(filePath);
if (result.ok) {
  // Refresh library
  libraryProvider.loadLibrary();
  // Navigate to viewer
  GoRouter.of(context).push('/viewer/${result.value.id}');
}
```

---

## Error Handling

### Global Error Boundary
```dart
// Catches any unhandled exception
class ErrorBoundary extends StatefulWidget {
  @override
  void didUpdateWidget(ErrorBoundary oldWidget) {
    FlutterError.onError = (details) {
      showErrorDialog(context, details.exceptionAsString());
    };
  }
}
```

### Module Error Propagation
```dart
// Module throws error
try {
  await moduleB.importImage(bytes);
} on ImportError catch (e) {
  // Show snackbar or dialog
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.message)),
  );
}
```

---

## Testing

Run tests with:
```bash
# Unit/widget tests
flutter test test/modules/a_app_shell_test.dart

# Integration tests
flutter drive --target=integration_test/app_test.dart
```

See TEST_PLAN.md for 48 test cases covering:
- Routing (11 tests)
- State management (9 tests)
- UI widgets (8 tests)
- Integration workflows (6 tests)
- Error handling (5 tests)
- Performance (6 tests)
- Accessibility (3 tests)

---

## Performance

**Target SLAs** (p95):
- Cold startup: < 2 seconds
- Route navigation: < 150 ms
- Frame rate: 60 FPS (device-dependent)
- Memory: < 200 MB baseline
- Provider updates: < 50 ms

See METRICS.md for detailed benchmarks by device and activity.

---

## Debugging

### Enable Debug Logging
```dart
// lib/main.dart
if (kDebugMode) {
  enableDebugLogging = true;
}
```

### Access Debug Panel
```
Build with: flutter run --flavor dev
Route to: /debug (visible only in dev mode)
```

### Inspect State
```dart
// Print provider state
final library = Provider.of<ScoreLibraryProvider>(context, listen: false);
print('Loaded ${library.allScores.length} scores');
```

---

## Known Limitations

1. **No multi-window**: Single score viewer (Stage 1)
2. **No cloud sync**: Local storage only (Stage 1)
3. **No annotation**: Drawing tools not available (Stage 2)
4. **No PDF export**: Print unsupported (Stage 2)
5. **Limited undo**: No undo/redo in editor (Stage 2)
6. **Single theme**: Material Design 3 only (custom themes Stage 2)
7. **English only**: Localization framework ready, other languages Stage 2

---

## Version History

**v1.0.0**: Initial release
- All 5 modules integrated
- Cross-platform support (iOS, Android, macOS, Windows, Web)
- 48 test cases passing
- All target SLAs met

---

## Roadmap (Future Releases)

- [ ] Cloud sync (iCloud, Google Drive)
- [ ] Offline mode
- [ ] Custom themes
- [ ] Annotation tools
- [ ] PDF export
- [ ] Multi-window support
- [ ] Plugin system
- [ ] Accessibility improvements
