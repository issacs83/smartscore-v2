# Module A: App Shell - Contract

## Module Purpose
Platform-agnostic application foundation. Manages routing, state management, and integration of all subordinate modules. Provides consistent UI/UX across iOS, Android, macOS, Windows, and Web platforms.

## Platform Support

### Minimum Requirements
- **Flutter**: 3.2+ (Dart 3.2+)
- **iOS**: 12.0+ (A12 or later)
- **Android**: 7.0+ (API level 24)
- **macOS**: 10.14+
- **Windows**: 10 (build 19041) or later
- **Web**: Chrome, Safari, Firefox (evergreen versions)

### Required Capabilities (by platform)
- **iOS**: Bluetooth LE, camera, file access
- **Android**: BLUETOOTH, CAMERA, READ_EXTERNAL_STORAGE, WRITE_EXTERNAL_STORAGE, ACCESS_FINE_LOCATION
- **macOS**: Camera, file access (no special entitlements beyond sandbox)
- **Windows**: Camera, file access
- **Web**: File API (drag-drop), Camera API

---

## Route Structure

### Navigation Routes
```
/ (home)
  ├─ /library              (score library list)
  ├─ /viewer/:id           (active score viewer)
  ├─ /settings             (app settings)
  ├─ /capture              (camera score capture)
  └─ /debug                (development mode, features only)

Supported navigation patterns:
- Push (new page on top)
- Replace (current page replaced)
- Pop (return to previous)
- Deep link (direct URL navigation)
```

### Route Definitions
```dart
// Deep link examples
smartscore:///library
smartscore:///viewer/550e8400-e29b-41d4-a716-446655440000
smartscore:///settings
smartscore:///capture
smartscore:///debug
```

---

## State Management Architecture

### Provider Pattern
```
AppState (root ChangeNotifier)
  ├─ ScoreLibraryProvider (Module B)
  │   ├─ List<ScoreEntry>
  │   └─ selectedScoreId: string?
  ├─ ScoreRendererProvider (Module F)
  │   ├─ currentPage: int
  │   ├─ totalPages: int
  │   └─ PageLayout
  ├─ ComparisonProvider (Module C)
  │   ├─ showComparison: bool
  │   ├─ originalJson: string
  │   └─ editedJson: string
  ├─ DeviceProvider (Module K)
  │   ├─ connectedDevices: List<Connection>
  │   └─ lastAction: DeviceAction?
  └─ UIStateProvider
      ├─ darkMode: bool
      ├─ zoomLevel: float
      └─ systemsPerPage: int
```

### State Updates
- **Module B** (library) → notifies when scores imported/deleted
- **Module F** (renderer) → notifies when page changes
- **Module K** (device) → notifies when action received
- **Module A** (UI) → updates local UI state (zoom, dark mode)

### Consumption Pattern
```dart
// Widgets consume state via Consumer pattern
Consumer<ScoreLibraryProvider>(
  builder: (context, library, _) {
    return ListView(
      children: library.allScores.map((score) => ListTile(...)).toList(),
    );
  },
)
```

---

## Route Contracts

### / (Home/Library)
**Purpose**: View all imported scores, navigate to viewer or import new

**State**:
- Displays list from ScoreLibraryProvider.allScores
- Shows score title, composer, source type (icon), date imported
- Search/filter (optional)
- Sort by date or title

**Actions**:
- Tap score → navigate to `/viewer/:id`
- Long-press score → delete (confirmation dialog)
- Floating action button → `/capture` or file picker

**Provider dependencies**: ScoreLibraryProvider

---

### /viewer/:id
**Purpose**: Display and interact with imported score

**State**:
- Score loaded: `getScore(id)` from Module B
- Current page from ScoreRendererProvider
- PageLayout from Module F.renderPage()
- Current position highlight (if Module K device connected)
- Edit state from Module C (if in comparison mode)

**Actions**:
- Swipe left/right or page buttons → navigate pages
- Tap note/measure → show details or select for editing
- Device input (pedal, keyboard) → change page (via Module K)
- Settings button → open /settings
- Comparison toggle → show/hide before/after

**Provider dependencies**: ScoreLibraryProvider, ScoreRendererProvider, DeviceProvider, ComparisonProvider, UIStateProvider

**Canvas rendering**: Module F.renderPage() → CanvasRecorder → display

---

### /settings
**Purpose**: Configure app behavior, device management, UI preferences

**Tabs**:
1. **Display**: zoom level (0.5–2.0×), dark mode (toggle), measures per system, systems per page
2. **Devices**: list connected devices (from DeviceProvider), scan for new, disconnect, manage mappings
3. **About**: version, credits, license

**Actions**:
- Toggle dark mode → rebuild UI with new theme
- Adjust zoom → re-render current page
- Scan for devices → call Module K.startScan()
- Connect device → call Module K.connect()

**Provider dependencies**: DeviceProvider, UIStateProvider

---

### /capture
**Purpose**: Import score via camera, PDF file, or MusicXML

**Actions**:
1. **Camera**: Launch camera, capture image → Module B.importImage()
2. **File picker**: Select PDF or MusicXML file → Module B.importPdf() or Module B.importMusicXml()
3. **Gallery**: Select from gallery → Module B.importImage()

**Results**:
- Success: Show imported score summary, offer to view or return to library
- Failure: Show error message, retry or dismiss

**Provider dependencies**: ScoreLibraryProvider

---

### /debug
**Purpose**: Development mode, internal state inspection (stage 1 only)

**Features** (if enabled in build config):
- Display current module state (JSON from all modules)
- Show input event log (last 100 events from Module K)
- Render metrics (FPS, memory, latency)
- Toggle debug logging in all modules
- Force app state corruption/recovery (testing)

**Visibility**: Hidden in production builds (release mode)

**Provider dependencies**: All providers (read-only)

---

## State Synchronization

### Event Flow Example (Page Turn)
```
User taps "next" button on UI
  ↓
ScoreRendererProvider.currentPage++
  ↓
ScoreRendererProvider.notifyListeners()
  ↓
/viewer/:id rebuilds
  ↓
renderPage(scoreJson, newPage, config) called (Module F)
  ↓
Canvas updated with new PageLayout
```

### Event Flow Example (Device Input)
```
Bluetooth pedal button pressed
  ↓
Module K emits DeviceAction.nextPage to onAction stream
  ↓
DeviceProvider listens, emits action event
  ↓
ScoreRendererProvider.currentPage++
  ↓
(same as user tap flow)
```

### Cross-Module Communication
- **Module B ↔ Module A**: Library changes notified via ChangeNotifier
- **Module K → Module A**: Device actions consumed from onAction stream
- **Module F ← Module A**: Render config and score JSON passed by-value (no state sharing)
- **Module C ↔ Module A**: Comparison state managed by Module A (own ChangeNotifier)

---

## Build Configuration

### Environment Files
```bash
# .env.development
SMARTSCORE_DEBUG_LOGGING=true
SMARTSCORE_ENABLE_DEMO_MODE=false
SMARTSCORE_API_ENDPOINT=http://localhost:8000

# .env.production
SMARTSCORE_DEBUG_LOGGING=false
SMARTSCORE_ENABLE_DEMO_MODE=false
SMARTSCORE_API_ENDPOINT=https://api.smartscore.app
```

### Build Variants
```dart
// lib/config.dart
const bool isDebugMode = bool.fromEnvironment('DEBUG_MODE', defaultValue: false);
const bool isDemoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);
```

### Feature Flags
```dart
// lib/features.dart
enum Feature {
  comparison,      // Module C (pre/post comparison)
  externalDevice,  // Module K (Bluetooth devices)
  omr,             // Module E (Optical Music Recognition)
  restoration,     // Module D (Image restoration)
}

bool isFeatureEnabled(Feature feature) {
  // Read from config or platform
}
```

---

## Error Handling & Recovery

### Global Error Boundary
```dart
void main() {
  runApp(
    MaterialApp(
      home: ErrorBoundary(
        child: MyApp(),
      ),
    ),
  );
}

// Catches any unhandled exception, shows error UI
```

### Module Error Propagation
```
Module throws error (ImportError, ParseError, DeviceError)
  ↓
Module A UI shows snackbar or dialog
  ↓
User can retry or dismiss
  ↓
App continues (no crash)
```

### Network/Storage Error Recovery
- Storage full → Prompt user to free space
- Permission denied → Prompt to grant permissions
- Network timeout → Retry with exponential backoff
- Corrupted data → Log error, offer to delete and restart

---

## Theme & Localization

### Theme Management
```dart
ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
);

ThemeData darkTheme = ThemeData.dark(useMaterial3: true);
```

### Responsive Design
```dart
// Breakpoints
enum DeviceType { mobile, tablet, desktop }

DeviceType getDeviceType(BuildContext context) {
  double width = MediaQuery.of(context).size.width;
  if (width > 1024) return DeviceType.desktop;
  if (width > 600) return DeviceType.tablet;
  return DeviceType.mobile;
}
```

### Localization
- **Supported languages**: English (baseline)
- **Future**: Spanish, French, German, Japanese (not in Stage 1)
- **Strings**: All user-facing text in localization file (arb format)

---

## Permissions Model

### Permission Requests (Example: iOS)
```
[Camera, Bluetooth, FileAccess]
  ↓
User grants/denies
  ↓
Store result in SharedPreferences
  ↓
Check before feature use, prompt if denied
```

### Graceful Degradation
- Camera denied → Disable /capture, show message
- Bluetooth denied → Disable device discovery, gray out /settings#devices
- File access denied → Disable import from files

---

## Performance Targets

**Target metrics** (Stage 1):
- App startup: < 2 seconds
- Route navigation: < 100 ms (page transition)
- Library load (100 scores): < 1 second
- Score render: < 100 ms (Module F)
- Memory: < 200 MB baseline, < 500 MB peak

---

## Dependencies

### Core
- **flutter**: 3.2+
- **provider**: 6.0+ (state management)
- **go_router**: 10.0+ (navigation)
- **intl**: 0.19+ (internationalization)

### UI
- **material_design_icons_flutter**: latest
- **google_fonts**: 5.0+

### File/Storage
- **file_picker**: 5.0+
- **image_picker**: 0.8+
- **sqflite**: 2.2+ (for Module B)

### Modules
- **modules/b_score_input**: Internal
- **modules/f_score_renderer**: Internal
- **modules/k_external_device**: Internal

---

## Constraints & Limitations

1. **No offline sync**: All data stored locally (Stage 1)
2. **Single user**: No multi-user support (Stage 1)
3. **No cloud backup**: Manual export only (Stage 1)
4. **Limited search**: Basic text search only (no advanced filters)
5. **Single active score**: Only one score viewer at a time
6. **No custom shortcuts**: Input mappings read-only (Stage 1)
7. **Print unsupported**: No PDF export (Stage 2)
8. **Annotation limited**: No drawing tools (Stage 2)
