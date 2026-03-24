# SmartScore v2 — UI/UX Design Specification

**Version**: 2.0
**Date**: 2026-03-24
**Framework**: Flutter + Material 3

---

## 2.1 Design System

### Color Palette

All tokens follow Material 3 ColorScheme conventions. Custom music-notation tokens are
prefixed with `score`.

#### Light Theme

| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | `#1A56DB` | CTAs, active nav, FAB |
| `onPrimary` | `#FFFFFF` | Text/icons on primary |
| `primaryContainer` | `#D6E4FF` | Chip fills, selected states |
| `onPrimaryContainer` | `#001A41` | Text on primaryContainer |
| `secondary` | `#5E6AD2` | Secondary actions, accent |
| `onSecondary` | `#FFFFFF` | Text/icons on secondary |
| `secondaryContainer` | `#E2E0FF` | Annotation tool highlight |
| `tertiary` | `#B5853A` | Page turn indicator, BPM accent |
| `surface` | `#FAFAFA` | Library background, cards |
| `surfaceVariant` | `#F0F2F5` | Input fills, inactive chips |
| `onSurface` | `#1A1C1E` | Primary text |
| `onSurfaceVariant` | `#42474E` | Secondary text, icons |
| `outline` | `#72787E` | Dividers, input borders |
| `error` | `#B3261E` | Errors, delete confirmations |
| `onError` | `#FFFFFF` | Text on error |

#### Dark Theme

| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | `#A8C7FA` | CTAs on dark surface |
| `onPrimary` | `#002D6B` | Text on primary (dark) |
| `primaryContainer` | `#004494` | Chip fills (dark) |
| `surface` | `#131416` | Library background (dark) |
| `surfaceVariant` | `#1E2228` | Cards, sheets (dark) |
| `onSurface` | `#E2E2E6` | Primary text (dark) |
| `onSurfaceVariant` | `#C5C6CC` | Secondary text (dark) |

#### Score-Specific Color Tokens

| Token | Light Hex | Dark Hex | Usage |
|-------|-----------|----------|-------|
| `scoreBackground` | `#FFFDE7` | `#1A1A1E` | Score page background |
| `scoreNoteColor` | `#1A1A1A` | `#E8E8E8` | Note heads, stems, beams |
| `scoreStaffLine` | `#2A2A2A` | `#D0D0D0` | Staff lines |
| `scoreMeasureBar` | `#3A3A3A` | `#C0C0C0` | Bar lines |
| `scoreHighlight` | `#1A56DB` + 25% alpha | `#A8C7FA` + 25% alpha | Current position cursor |
| `scoreAnnotationPen` | `#C62828` | `#EF9A9A` | Default pen color |
| `scoreAnnotationHighlight` | `#FDD835` + 60% alpha | `#FDD835` + 40% alpha | Highlighter |
| `scoreSepia` | `#F5EDD6` | — | Sepia background |

#### Night Mode Score Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `nightBackground` | `#121212` | Full-black OLED background |
| `nightNoteColor` | `#DCDCDC` | Inverted notes |
| `nightStaffLine` | `#909090` | Muted staff lines |

---

### Typography Scale (Material 3)

Font: **Noto Sans** (UI), **Noto Serif** (score titles/composer names).

| Style | Font | Size | Weight | Line Height | Usage |
|-------|------|------|--------|-------------|-------|
| `displayLarge` | Noto Serif | 57 | 400 | 64 | Splash headline |
| `displayMedium` | Noto Serif | 45 | 400 | 52 | Onboarding titles |
| `headlineLarge` | Noto Serif | 32 | 400 | 40 | Screen titles (large tablet) |
| `headlineMedium` | Noto Sans | 28 | 400 | 36 | Library section headers |
| `headlineSmall` | Noto Sans | 24 | 500 | 32 | Dialog titles, sheet titles |
| `titleLarge` | Noto Sans | 22 | 500 | 28 | App bar titles |
| `titleMedium` | Noto Sans | 16 | 500 | 24 | Score card title |
| `titleSmall` | Noto Sans | 14 | 500 | 20 | Chip labels, section labels |
| `bodyLarge` | Noto Sans | 16 | 400 | 24 | Primary body text |
| `bodyMedium` | Noto Sans | 14 | 400 | 20 | Secondary body text, composer |
| `bodySmall` | Noto Sans | 12 | 400 | 16 | Captions, metadata |
| `labelLarge` | Noto Sans | 14 | 500 | 20 | Buttons, tabs |
| `labelMedium` | Noto Sans | 12 | 500 | 16 | Smaller buttons |
| `labelSmall` | Noto Sans | 11 | 500 | 16 | Overlines, micro-labels |

---

### Spacing System (4 px Grid)

| Token | Value | Usage |
|-------|-------|-------|
| `space-1` | 4 px | Icon-to-text gap, micro padding |
| `space-2` | 8 px | Inner card padding, chip margin |
| `space-3` | 12 px | Row padding, subtitle margin |
| `space-4` | 16 px | Standard section padding |
| `space-5` | 20 px | Large row height |
| `space-6` | 24 px | Section separation |
| `space-8` | 32 px | Large section breaks |
| `space-10` | 40 px | Screen-edge padding (tablet) |
| `space-12` | 48 px | FAB margin, major section gap |
| `space-16` | 64 px | Hero image padding |

**Radii**:
| Token | Value | Usage |
|-------|-------|-------|
| `radius-xs` | 4 px | Source-type badge |
| `radius-sm` | 8 px | Chips, input fields |
| `radius-md` | 12 px | Cards, dialogs |
| `radius-lg` | 16 px | Bottom sheets, modals |
| `radius-xl` | 24 px | FAB, feature cards |
| `radius-full` | 9999 px | Pill chips, avatar |

---

### Icon Set

**Base**: Material Symbols (outlined weight 400).

| Context | Icons |
|---------|-------|
| Navigation | `home`, `menu_book`, `import_contacts`, `settings` |
| Library actions | `add`, `search`, `filter_list`, `sort`, `grid_view`, `view_list` |
| Import | `camera_alt`, `upload_file`, `link`, `picture_as_pdf`, `music_note`, `image` |
| Score viewer | `fullscreen`, `fullscreen_exit`, `zoom_in`, `zoom_out`, `navigate_before`, `navigate_next` |
| Display modes | `book`, `menu_book`, `view_agenda` |
| Annotation | `edit`, `highlight`, `text_fields`, `auto_fix_high`, `layers`, `undo`, `redo` |
| Practice | `play_circle`, `pause_circle`, `stop_circle`, `speed`, `piano`, `mic` |
| Devices | `bluetooth`, `bluetooth_connected`, `piano` (MIDI), `pedal_bike` (pedal) |
| Feedback | `check_circle`, `error`, `warning`, `info` |

**Custom music icons** (SVG, rendered via CustomPaint):
- Treble clef, Bass clef
- Whole/half/quarter/eighth note
- Dynamic marks: pp, p, mp, mf, f, ff
- Bow up, Bow down, Fermata

---

### Light/Dark Theme Tokens Summary

All tokens resolved through `Theme.of(context).colorScheme.*` — no hardcoded colors in widget code.

```dart
// Correct pattern
color: Theme.of(context).colorScheme.primary

// Incorrect — avoid
color: Color(0xFF1A56DB)
```

Score-specific tokens accessed via extension:
```dart
context.scoreColors.background   // scoreBackground
context.scoreColors.noteColor    // scoreNoteColor
context.scoreColors.highlight    // scoreHighlight
```

---

### Component Library

| Component | Material 3 Base | Customization |
|-----------|----------------|---------------|
| `ScoreCard` | `Card` (elevated) | Thumbnail area, source badge, metadata row |
| `ImportOptionCard` | `Card` (filled) | Large icon, title, subtitle |
| `FilterChip` | `FilterChip` | Color: primaryContainer when selected |
| `SearchBar` | `SearchBar` | Leading search icon, trailing clear |
| `ScoreViewerToolbar` | `AppBar` / custom | Auto-hide animation, blur backdrop |
| `PlaybackBar` | Custom bottom bar | Play/pause, tempo slider, page indicator |
| `AnnotationToolbar` | Custom left rail | Vertical in landscape, horizontal in portrait |
| `PageCurlTransition` | Custom `PageRoute` | Simulated curl on iOS |
| `DeviceCard` | `ListTile` in `Card` | BT status indicator, connect button |
| `ProgressDialog` | `AlertDialog` | Linear progress, cancel button |
| `EmptyStateView` | Custom | Illustration + headline + CTA |
| `SnackBar` | `SnackBar` | 4 s duration, undo action |
| `BottomSheet` | `ModalBottomSheet` | Drag handle, radius-lg top corners |

---

## 2.2 Screen Inventory

### Screen 1 — Splash / Onboarding

**Purpose**: App launch, brand moment, first-time setup.

**Layout**:
```
[Full screen, no AppBar]
  Center:
    [App logo — musical note stylized mark, 80x80]
    [App name "SmartScore" — displayMedium, Noto Serif]
    [Version tag — labelSmall, onSurfaceVariant]
  Bottom:
    [LinearProgressIndicator — primary color, 2dp height]
```

**First-launch overlay** (shown once, dismissed permanently):
```
PageView (3 pages, dot indicator):
  Page 1: "Scan any score" — camera illustration + body copy
  Page 2: "Annotate anywhere" — annotation overlay illustration
  Page 3: "Practice smarter" — radar chart illustration
Bottom:
  [Skip] TextButton   [Next] FilledButton → [Get Started] FilledButton
```

**Navigation**: Automatically advances to Home after loading completes (or after onboarding "Get Started").

**State Variants**:
- `loading`: progress indicator animating
- `onboarding`: page view with dot progress
- `error`: "Failed to load app data" with Retry button

---

### Screen 2 — Library (Home)

**Purpose**: Central score collection browser; primary daily-use screen.

**Layout**:
```
[NavigationBar — bottom, 4 tabs]
  Tab: Library (active), Practice, Setlists, Settings

[TopAppBar — medium, collapsible]
  Leading: [Menu icon or back]
  Title: "Library"
  Trailing: [search icon] [sort icon] [view toggle icon]

[SearchBar — below AppBar, full-width, slides in on search tap]
  Placeholder: "Search scores..."
  Trailing: [X clear] when text entered

[FilterChips — horizontal scroll row, below search]
  [All] [PDF] [MusicXML] [Scanned] [Recent]

[Content — fills remaining space]
  Grid variant (default): 2 columns (phone) / 3 columns (tablet)
    Each cell: ScoreCard
  List variant: full-width ScoreCard rows

[FAB — bottom-right, 88dp from bottom edge]
  Extended when 0 scores: [+ Import Score]
  Icon-only when >0 scores: [+]
```

**Navigation**:
- In: app launch, any back navigation
- Out: tap ScoreCard → Score Viewer; tap FAB → Import Screen; tab bar → other tabs

**Key Interactions**:
- Tap card: open Score Viewer
- Long-press card: context BottomSheet (Open / Rename / Delete / Export)
- Swipe card left: delete with undo snackbar
- Pull-to-refresh: reload library
- Tap search icon: expand SearchBar, focus keyboard
- Tap sort icon: BottomSheet with sort options
- Tap view toggle: switch grid/list

**State Variants**:
- `loading`: shimmer placeholder cards (3x2 grid)
- `empty`: EmptyStateView with illustration and "Import Score" CTA
- `error`: error card with Retry
- `populated`: normal grid/list
- `searching`: filtered results or "No results" message

---

### Screen 3 — Score Import

**Purpose**: Entry point for adding new scores; replaces the basic CaptureScreen.

**Layout**:
```
[AppBar]
  Leading: [X close]
  Title: "Import Score"

[Body — vertically scrollable]
  Section: "Capture"
    [ImportOptionCard — camera, large 1/2 screen width]
      Icon: camera_alt (48dp, primary)
      Title: "Scan with Camera"
      Subtitle: "Photograph printed music"

  Section: "From Files"
    [Row of 3 ImportOptionCards]
      [PDF Card] — picture_as_pdf, red accent
      [MusicXML Card] — music_note, blue accent
      [Image Card] — image, orange accent

  Section: "From Web"
    [ImportOptionCard — link, full width]
      Icon: link
      Title: "Import from URL"
      Subtitle: "IMSLP or any direct link"
      Trailing: paste from clipboard chip

  Section: "Recent Imports" (if any)
    [Horizontal scroll list of thumbnail chips]
```

**Navigation**:
- In: FAB from Library, context menu from Library
- Out: successful import → Score Viewer; X button → back to Library

**Key Interactions**:
- Tap Camera card: open camera viewfinder (system camera or in-app)
- Tap PDF/XML/Image card: open platform file picker
- Tap URL card: show URL input bottom sheet
- Paste from clipboard chip (if URL in clipboard): auto-fill URL field

**State Variants**:
- `idle`: cards as described
- `importing`: ProgressDialog over content, cancel button
- `error`: inline error card with retry

---

### Screen 4 — OMR Processing (Stage 2)

**Purpose**: Show real-time OMR progress and allow user to review/correct results.

**Layout**:
```
[AppBar]
  Title: "Processing Score"
  Trailing: [X cancel]

[Body]
  [Score preview thumbnail — top 40% of screen]

  [Progress section]
    Step indicator (horizontal):
      [1 Enhance] → [2 Detect] → [3 Recognize] → [4 Review]
    Current step label: "Detecting staff lines..."
    CircularProgressIndicator + percentage

  [Log output — expandable, bottom sheet trigger]
    "Tap to see details"

[Bottom bar — shown at step 4 (Review)]
  [Reject — OutlinedButton]   [Accept — FilledButton]
```

**Review sub-screen** (step 4):
```
[Split view — 50/50 horizontal]
  Left: original scan image with overlay boxes
  Right: rendered score output
[Bottom toolbar]
  [< Previous error] [Error 3/7] [Next error >]
  [Edit note] [Delete note] [Accept all]
```

**Navigation**:
- In: after capture / file import triggers OMR
- Out: Accept → Score Viewer with new score; Reject → back to Import

---

### Screen 5 — Score Viewer

**Purpose**: Primary score-viewing experience; most-used screen in the app.

**Layout** (see Section 2.4 for full detail):
```
[Full screen — SystemUI overlays hidden]
  [Score canvas — fills 100% of screen]
    CustomPaint(painter: ScorePainter(...))

  [Top toolbar — auto-hides, 56dp height]
    [< Back]  [Title / Composer]  [display mode] [zoom] [annotation] [more]

  [Bottom toolbar — auto-hides, 72dp height]
    [< prev]  [page indicator n/N]  [> next]
    [Stage 3: play/pause | tempo | metronome toggle]

  [Page tap zones — invisible, 15% left and right]

  [Annotation toolbar — left rail, visible only in annotation mode]
    [pen] [highlight] [text] [stamp] [eraser] [layers] [undo] [redo]
```

**Navigation**:
- In: tap ScoreCard in Library, successful import
- Out: Back button → Library

---

### Screen 6 — Annotation Mode

**Purpose**: Pen, highlight, and stamp overlay editing on top of score canvas.

**Layout**:
```
[Score canvas (blurred slightly to indicate edit mode)]

[Annotation toolbar — vertical left rail in landscape]
  [Pen tool]
  [Highlighter tool]
  [Text insert]
  [Stamp picker]
  [Eraser]
  [---]
  [Layers button]
  [Undo]
  [Redo]

[Tool options bar — horizontal, above bottom edge]
  [Color swatches: 5 preset + custom]
  [Size selector: S / M / L dots]

[Top toolbar]
  [Done] FilledButton (right side)
  [Clear page] TextButton (destructive, left side)
```

**Key Interactions**:
- Touch and drag on canvas: draw strokes
- Tap stamp icon: open stamp picker bottom sheet
- Tap Layers: open layer management bottom sheet
- Two-finger pinch: zoom without drawing
- Tap Done: return to viewer mode, save annotations

---

### Screen 7 — Practice Mode (Stage 3)

**Purpose**: Score-synchronized playback with metronome and AI following.

**Layout**:
```
[Score canvas — top 70% of screen, slightly compressed]

[Practice control bar — bottom 30%]
  Row 1:
    [Loop on/off toggle]  [Tempo BPM: 92]  [Metronome on/off]
  Row 2 (Playback):
    [|<< start]  [< 10s]  [play/pause — large 56dp]  [10s >]  [>> end]
  Row 3 (Tempo slider):
    50 [========o=========] 200 BPM
  Row 4 (AI mode — Stage 3):
    [Wait mode: off/on]   [Follow mode: off/on]
    [Loop region: tap to select measures]
```

**AI Score Following indicator**:
- Green pulsing dot when tracking
- Orange when lost position
- Tap to manually re-sync

**Navigation**:
- In: "Practice" button from Score Viewer more menu; Practice tab
- Out: X closes panel, returns to normal Viewer

---

### Screen 8 — AI Evaluation (Stage 3)

**Purpose**: Post-practice performance feedback with 5-axis visualization.

**Layout**:
```
[AppBar]
  Title: "Practice Report"
  Trailing: [Share] [Save]

[Body — scrollable]
  [Session summary card]
    Score title, date, duration, total notes played

  [Radar chart — 5 axes]
    Pitch Accuracy, Rhythm Accuracy, Dynamics, Tempo Stability, Articulation
    [Score this session: 84]  [Previous best: 91]

  [Axis breakdown]
    Each axis: label + progress bar + improvement tip

  [Problem spots section]
    [List of measures with most errors]
    [Tap to jump to that measure in viewer]

  [Practice log — "Last 7 sessions" sparkline]
```

**Navigation**:
- In: after practice session ends (Stop button)
- Out: Back → Practice Mode; "Open Score" → Score Viewer at problem measure

---

### Screen 9 — Settings

**Purpose**: App preferences, display, account, storage management.

**Layout**:
```
[AppBar]
  Title: "Settings"

[Body — ListView of ListTile sections]

  Section: Display
    [Display mode: Single / Double / Scroll] — segmented button
    [Theme: Light / Dark / System] — segmented button
    [Score colors: Normal / Night / Sepia] — segmented button
    [Font scale: 80% - 150%] — slider

  Section: Practice
    [Default tempo: ---] — number input
    [Metronome sound: Click / Beep / Silent] — radio group
    [AI evaluation: On / Off] — switch

  Section: Devices
    [Manage Devices] — navigates to Device Manager

  Section: Library
    [Default import folder: ...] — path picker
    [Auto-organize: By composer / None] — toggle
    [Storage used: 248 MB]  [Clear cache] button

  Section: About
    [App version: 2.0.0]
    [Open source licenses]
    [Privacy policy]
    [Send feedback]
```

**Navigation**:
- In: Settings tab (bottom nav), AppBar icon from Library
- Out: back navigation to previous screen

---

### Screen 10 — Device Manager

**Purpose**: Pair and manage Bluetooth page-turn pedals and MIDI keyboards.

**Layout**:
```
[AppBar]
  Title: "Devices"
  Trailing: [+ Add device]

[Body]

  Section: Connected Devices
    [DeviceCard for each paired device]
      Icon: bluetooth_connected (animated pulse)
      Name: "PageFlip BT-105"
      Subtitle: "Bluetooth Pedal • Connected"
      Trailing: [disconnect button]

    [Empty state: "No devices connected"]

  Section: Available Devices (shown during scan)
    [ScanningCard]
      Animated Bluetooth icon + "Scanning..."
      [Stop scan] TextButton
    [DeviceCard for each found device]
      Trailing: [Connect] OutlinedButton

  [FAB: scan for devices — bluetooth_searching icon]
```

**Key Interactions**:
- Tap FAB: start scan, show available section
- Tap Connect: pair and move to Connected section
- Tap device row: show device details sheet (battery level, last connected, remove pairing)
- Long-press: show remove pairing option

---

### Screen 11 — Setlist Manager

**Purpose**: Create ordered playlists of scores for performances.

**Layout**:
```
[AppBar]
  Title: "Setlists"
  Trailing: [+ New setlist]

[Body]
  [SetlistCard for each setlist]
    Title, count of scores, estimated duration, last modified
    Trailing: [play button — opens first score in viewer]

[Bottom sheet — Create/Edit Setlist]
  [Title input]
  [Scores in setlist — reorderable list]
    DragHandle | ScoreThumbnail | Title | Remove button
  [+ Add score — bottom of list]
  [Share link icon] [Save FilledButton]
```

**Navigation**:
- In: Setlists tab (bottom nav)
- Out: tap setlist → Score Viewer at first score; share link → system share sheet

---

## 2.3 Navigation Architecture

### Tab Bar Structure

Bottom NavigationBar (NavigationBar Material 3, 4 tabs):

| Index | Label | Icon (inactive) | Icon (active) | Route |
|-------|-------|----------------|--------------|-------|
| 0 | Library | `menu_book_outlined` | `menu_book` | `/` |
| 1 | Practice | `fitness_center_outlined` | `fitness_center` | `/practice` |
| 2 | Setlists | `queue_music_outlined` | `queue_music` | `/setlists` |
| 3 | Settings | `settings_outlined` | `settings` | `/settings` |

Tab bar visible on: Library, Practice, Setlists, Settings.
Tab bar hidden on: Score Viewer, Annotation Mode, Import, Device Manager.

---

### Screen Flow Diagram

```
[Splash]
    |
    v
[Onboarding] (first launch only)
    |
    v
[Library (Home)] ←──────────────────────────────┐
    |                                            |
    |── tap FAB ──────────────────> [Import Screen]
    |                                    |
    |                                    |── camera ──> [Camera Viewfinder]
    |                                    |                     |
    |                                    |                     v
    |                                    |              [OMR Processing] (Stage 2)
    |                                    |                     |
    |                                    └── all paths ────────┘
    |                                                          |
    |── tap score card ──────────────────────────────────────> v
    |                                              [Score Viewer]
    |                                                    |
    |                                                    |── annotation icon ──> [Annotation Mode]
    |                                                    |                              |
    |                                                    |                     [Done] ──┘
    |                                                    |
    |                                                    |── practice button ──> [Practice Mode] (Stage 3)
    |                                                    |                              |
    |                                                    |                     [Stop] ──> [AI Evaluation]
    |                                                    |
    |                                                    └── Back ──────────────────────┘
    |
    |── Settings tab ──────────> [Settings]
    |                                |
    |                                └── Manage Devices ──> [Device Manager]
    |
    |── Setlists tab ──────────> [Setlist Manager]
    |                                |
    |                                └── tap setlist ──> [Score Viewer]
    |
    └── Practice tab ──────────> [Practice Hub] (Stage 3)
```

---

### Deep Link Structure

| Deep Link | Destination | Parameters |
|-----------|-------------|-----------|
| `smartscore://score/{id}` | Score Viewer | `id`: score UUID |
| `smartscore://score/{id}/page/{n}` | Score Viewer at page n | `id`, `n` |
| `smartscore://setlist/{id}` | Setlist opens first score | `id`: setlist UUID |
| `smartscore://import?url={url}` | Import Screen with URL pre-filled | `url`: encoded URL |
| `smartscore://practice/{id}` | Practice Mode for score | `id`: score UUID |

---

### Back Navigation Rules

- Score Viewer: back → Library (pop to root, not push).
- Annotation Mode: "Done" → Score Viewer (not back gesture — prevent accidental exit).
- Import Screen: X button → Library; hardware back → Library.
- Settings: back → wherever Settings was opened from.
- Device Manager: back → Settings.
- OMR Processing: X cancels processing and returns to Import Screen.

### Gesture Navigation

- Swipe right from left edge: back navigation (iOS-style, also on Android with gesture nav).
- Swipe down on BottomSheet: dismiss sheet.
- Score Viewer: swipe left = next page; swipe right = previous page.
- Score Viewer: pinch = zoom.
- Library: pull down = refresh.
- Library score card: swipe left = delete action reveal.

---

## 2.4 Score Viewer — Detail Design

### Page Display Modes

#### Single Page Mode (default on phone/portrait)
```
┌─────────────────────┐
│  [Top toolbar]      │ ← 56dp, auto-hide
│─────────────────────│
│                     │
│    [Score page]     │ ← fills available height, centered
│    A4 aspect ratio  │
│    (or Letter)      │
│                     │
│─────────────────────│
│  [Bottom toolbar]   │ ← 72dp, auto-hide
└─────────────────────┘
```

#### Double Page Mode (tablet/landscape)
```
┌──────────────────────────────────────┐
│  [Top toolbar — full width]         │
│──────────────────────────────────────│
│         │                            │
│  [Page  │  [Page                     │
│   left] │   right]                   │
│         │                            │
│──────────────────────────────────────│
│  [Bottom toolbar — full width]      │
└──────────────────────────────────────┘
```
Left page: even page number; Right page: odd page number.
Page turn: both pages slide simultaneously.

#### Continuous Scroll Mode
```
Score pages flow vertically with 8dp gap between pages.
Standard Flutter SingleChildScrollView with physics: BouncingScrollPhysics.
Horizontal overflow: clamped with pinch-zoom support.
Page snap: optional setting; snaps to nearest full page.
```

#### Half-Page Turn (forScore-style)
Available in Single Page mode only.
```
Screen is divided horizontally at 50% (adjustable via drag).
Upper half shows top of current page.
Lower half shows bottom of current page.
Right pedal press → scroll lower half to top of next page
                  → then on second press, upper half also advances.
Visual divider: 2dp hairline, draggable to adjust split point.
```

---

### Toolbar Layout

**Top Toolbar** (height: 56dp, blur backdrop):
```
[←back]  [Title (truncated) · Composer]  [...display] [zoom±] [✏ annotate] [⋮ more]
```

**More menu** (BottomSheet):
- Display mode submenu
- Night mode toggle
- Sepia mode toggle
- Jump to measure...
- Export / Share
- Score info

**Bottom Toolbar** (height: 72dp, blur backdrop):
```
Row 1:  [←] ─────── [ 3 / 12 ] ─────── [→]
              Page indicator — tap to jump
```

Stage 3 adds Row 2:
```
Row 2:  [⏮] [⏪10s]  [▶/⏸]  [10s⏩] [⏭]   Tempo: [92 BPM ▾]  [🎵 metro]
```

**Auto-hide behavior**:
- Toolbars fade out after 3 s of inactivity (opacity: 1.0 → 0.0, duration: 300 ms).
- Tap center zone of screen: toggle visible (opacity: 0.0 → 1.0, duration: 200 ms).
- During page turn animation: toolbars remain hidden.
- When annotation mode is active: top toolbar always visible, bottom toolbar hidden.

---

### Page Turn Gestures and Animations

| Trigger | Action | Animation |
|---------|--------|-----------|
| Swipe left (velocity > 300 px/s) | Next page | Slide transition (slide left, 250ms, easeOut) |
| Swipe right (velocity > 300 px/s) | Previous page | Slide transition (slide right, 250ms, easeOut) |
| Tap right 15% zone | Next page | Slide transition |
| Tap left 15% zone | Previous page | Slide transition |
| BT pedal right button | Next page | Slide transition |
| BT pedal left button | Previous page | Slide transition |
| Tap page indicator | Jump to N | Fade transition (150ms) |

**iOS page-curl animation** (optional, toggle in settings):
- Use `CupertinoPageRoute` with custom page-curl painter.
- 3D perspective transform with shadow.
- Only on iOS; Android uses slide.

---

### Zoom Behavior

| Gesture | Action |
|---------|--------|
| Pinch expand | Zoom in (0.5x – 4.0x, smooth, continuous) |
| Pinch contract | Zoom out |
| Double-tap | Cycle: fit-to-width → 100% → fit-to-height → fit-to-width |
| Two-finger drag | Pan (when zoomed in) |

Zoom implementation:
- `InteractiveViewer` widget wraps the CustomPaint canvas.
- `minScale: 0.5`, `maxScale: 4.0`.
- `boundaryMargin: EdgeInsets.all(20)`.
- Zoom level persists in `UIStateProvider.zoomLevel`.

---

### Night / Sepia Mode

| Mode | Background | Note Color | Staff Color |
|------|-----------|-----------|-------------|
| Normal | `#FFFDE7` | `#1A1A1A` | `#2A2A2A` |
| Night | `#121212` | `#DCDCDC` | `#909090` |
| Sepia | `#F5EDD6` | `#2C1810` | `#3D2416` |

Toggle: More menu → Night mode / Sepia mode radio group.
`LayoutConfig.darkMode` flag passed to `ScorePainter`.
Transition: 200ms cross-fade.

---

### Annotation Overlay Integration

Annotation layer sits above the `ScorePainter` canvas in a `Stack`:
```
Stack:
  ├─ CustomPaint(painter: ScorePainter(...))     // score
  ├─ CustomPaint(painter: AnnotationPainter(...)) // vector annotations
  └─ GestureDetector (annotation mode only)      // capture strokes
```

In viewer mode (non-annotation): `GestureDetector` passes through all touches for zoom/pan/page-turn.
In annotation mode: `GestureDetector` captures touch for drawing; zoom via two-finger only.

---

### Playback Cursor Display (Stage 3)

- Semi-transparent vertical bar (2dp wide, `scoreHighlight` color, 25% opacity).
- Animated left-to-right across each measure as playback progresses.
- `RenderState.currentMeasure` and `measureProgress` (0.0–1.0) fed to `ScorePainter`.
- On measure change: cursor snaps to start of new measure, then animates continuously.

---

### BT Pedal Integration Points

Pedal events flow: `DeviceManager` → `DeviceProvider` → `ScoreViewerScreen`.

```
DeviceProvider.onAction stream:
  DeviceAction.pageNext  → _nextPage()
  DeviceAction.pagePrev  → _previousPage()
  DeviceAction.halfPage  → _halfPageAdvance()
  DeviceAction.annotate  → _toggleAnnotationMode()
```

In `ScoreViewerScreen.initState()`:
```dart
_deviceSubscription = deviceProvider.onAction.listen(_handleDeviceAction);
```

Visual feedback on pedal press: brief 100ms highlight flash on the activated page-turn zone.

---

## 2.5 Key Interaction Patterns

### Page Turn: Tap Zones

```
┌──────┬──────────────────┬──────┐
│ ← 15%│                  │ 15% →│
│ prev │  center: toolbar │ next │
│ zone │  toggle          │ zone │
└──────┴──────────────────┴──────┘
```

Zone sizes adjust on tablets: 10% on each side (larger screen makes 15% too aggressive).

---

### Half-Page Turn (forScore-style)

1. User enables "Half-page turn" in display mode menu.
2. A horizontal hairline divider appears at screen midpoint.
3. User can drag the divider to reposition the split (saved per score).
4. Pedal right (first press): bottom half advances to show beginning of next page.
5. Visual: page "peels" away in bottom half, next page slides up from below.
6. Pedal right (second press): full page advance — both halves synchronize to new page.
7. Scroll state stored separately for top and bottom half.

---

### Auto-Scroll (Piascore-style)

Available via More menu → "Auto Scroll".
```
[Auto-scroll control pill — bottom center, above toolbar]
  [slower ─] [▶ scroll] [─ faster]
  Speed range: 1–10 (line-height per second)
```

Implementation: `ScrollController` with `animateTo` in a repeating `Timer`.
User can still swipe and tap normally; auto-scroll pauses on interaction, resumes after 2 s.

---

### Camera Capture Flow

```
[Tap Camera card in Import]
      |
      v
[Camera Viewfinder]
  - System camera overlay with document edge detection
  - Guide corners (CSS-border-style overlay, amber color)
  - Capture button (56dp FAB at bottom center)
      |
      v
[Review screen]
  - Captured image full-screen
  - [Retake] [Use this photo] buttons
  - If multi-page: [+ Add page] button → back to viewfinder
      |
      v
[Page list thumbnail strip at bottom]
  - Thumbnails of all captured pages
  - Drag to reorder, swipe to remove
  - [Import X pages] FilledButton → OMR Processing (Stage 2) or direct import
```

---

### OMR Result Review (ScanScore-style)

Step 4 of OMR Processing screen:
```
[Split view]
  LEFT: Original scan
    - Error bounding boxes in red
    - Correct recognitions in green (subtle)
    - Uncertain recognitions in yellow

  RIGHT: Rendered score output
    - Corresponding measure highlighted when left side element tapped

[Bottom bar]
  [Error 3 of 7] counter
  [← Prev error] [Next error →]
  [Fix: incorrect note pitch picker / delete / accept]
  [Accept All Remaining] FilledButton
```

---

### Practice Mode Patterns

**Wait Mode** (SmartMusic-style):
- Playback pauses at each note and waits for the performer to play it.
- AI listens for the correct pitch; on detection, advances to next note.
- Visual: current note pulses amber; green check on correct detection.

**Follow Mode**:
- AI tracks performer position continuously.
- Playback follows without strict timing — adapts to performer's tempo.
- Highlight cursor follows detected position.
- If tracking is lost for > 2 s: orange warning dot; playback pauses.

**Loop Selection**:
- Tap and drag across measures in score: selects a range.
- Selected range highlighted with `primaryContainer` fill.
- Loop indicator: A/B markers at start/end measure.
- Toggle loop: loop button in playback bar.

---

## Appendix: Screen Size Breakpoints

| Breakpoint | Width | Layout Changes |
|-----------|-------|---------------|
| `compact` | < 600dp | 2-column library grid, single-page viewer, bottom nav visible |
| `medium` | 600–840dp | 2–3 column grid, double-page viewer optional |
| `expanded` | > 840dp | 3-column grid, double-page default, left-rail nav option |

Navigation adaptation at `expanded`:
- Bottom NavigationBar → `NavigationRail` (left sidebar, 72dp wide).
- Library: master-detail split (list left, viewer right).

---

## Appendix: Animation Durations

| Animation | Duration | Curve |
|-----------|----------|-------|
| Toolbar show/hide | 200ms | easeInOut |
| Toolbar auto-hide fade | 300ms | easeOut |
| Page slide transition | 250ms | easeOut |
| Page curl | 400ms | easeInOut |
| Mode switch cross-fade | 200ms | linear |
| Score card appear | 150ms | easeOut (staggered) |
| FAB extend/collapse | 200ms | easeInOut |
| Bottom sheet slide | 300ms | decelerate |
| Snackbar appear | 250ms | easeOut |
| Snackbar dismiss | 200ms | easeIn |
