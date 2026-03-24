# SmartScore v2 — Product Requirements Document

**Version**: 2.0
**Date**: 2026-03-24
**Status**: Active

---

## 1. Product Vision & Mission

### Vision
The universal music score companion — from paper to performance, on any device.

### Mission
SmartScore v2 eliminates the friction between a musician's physical score collection and their digital practice workflow. We combine AI-powered optical music recognition (OMR), a best-in-class score viewer, and intelligent practice tools into a single cross-platform app that works identically on iOS, Android, Web, and Desktop.

### Why Now
- The Flutter ecosystem has matured enough to deliver native performance on all platforms from a single codebase.
- Commercial OMR engines (ScanScore, PlayScore 2) are desktop-only or iOS-only; no solution owns the Android market.
- AI audio analysis is now fast enough to run score-following in real time on consumer hardware.
- Musicians increasingly demand a unified workflow: scan a part at rehearsal, annotate it, practice at home with AI feedback, perform with a pedal page-turner.

---

## 2. Target Users

### Persona A — The Orchestral Musician (Primary)
**Name**: Ji-eun Park
**Age**: 28
**Role**: Professional violinist, section player in a regional orchestra
**Devices**: iPhone 15, iPad Pro 12.9", Windows laptop
**Pain Points**:
- Carries binders of physical parts to every rehearsal; annotations get lost.
- forScore works on iPad but cannot sync to Android or Windows.
- Manually enters bowing/fingering into PDF annotation tools that don't understand music.
- Can't practice with an accompaniment track tied to the score position.

**Goals**:
- Digitize her entire part library.
- Annotate bowings on iPad, have them visible on iPhone in the pit.
- Use a BT pedal to turn pages hands-free during performance.
- Practice difficult passages with looped playback and AI accuracy feedback.

**Success Condition**: Replaces forScore + a physical binder with SmartScore on two devices.

---

### Persona B — The Conservatory Student (Secondary)
**Name**: Alex Martinez
**Age**: 21
**Role**: Undergraduate piano student
**Devices**: Android phone (Samsung Galaxy S24), Chromebook
**Pain Points**:
- No budget for iOS-only apps (forScore $14.99/yr).
- Scans assignments on phone; PDFs are hard to annotate on Android.
- Practices scales and repertoire without reliable tempo feedback.
- Professor assigns IMSLP scores; downloading, importing, and annotating takes 10 minutes.

**Goals**:
- Scan printed assignments directly from phone camera.
- Annotate fingerings, circle repeated passages.
- Practice with metronome locked to score position.
- Import IMSLP URLs with one tap.

**Success Condition**: Free tier covers daily use; pays for AI practice features as they mature.

---

### Persona C — The Ensemble Director (Tertiary)
**Name**: Thomas Weber
**Age**: 45
**Role**: High school band director
**Devices**: iPad Air, MacBook Pro
**Pain Points**:
- Distributes photocopied parts; students lose them.
- Cannot quickly jump to measure 32 during rehearsal while holding a baton.
- Score and parts are separate PDFs with different page layouts.
- Wants to assign specific passages as practice homework.

**Goals**:
- Upload a score once; students access their part on any device.
- Jump to any measure number instantly.
- Mark rehearsal sections (A, B, C) that appear on all devices simultaneously.
- Export annotated score as PDF for print distribution.

**Success Condition**: Uses SmartScore in rehearsal daily; assigns practice via setlist share links.

---

## 3. Feature Roadmap

### Stage 1 — Score Viewer MVP (Q2 2026)
Core viewer that replaces physical printed scores and PDF apps. Target: Persona A & B daily use.

| Module | Feature | Status |
|--------|---------|--------|
| A — App Shell | Navigation, routing, theming, settings | 80% |
| B — Score Input | PDF import, MusicXML import, image import | 85% |
| E — Normalizer | MusicXML → Score JSON pipeline | 90% |
| F — Renderer | Layout engine + CustomPainter rendering | 85% |
| K — External Device | BT pedal page-turn, MIDI keyboard | 70% |

**Exit Criteria for Stage 1**:
- Open a MusicXML file; see rendered score on screen in < 2 s
- Turn pages via swipe, tap zones, and BT pedal
- Annotate with pen and highlight tools
- Dark/night mode
- Runs on iOS, Android, Web, and macOS

---

### Stage 2 — OMR Pipeline (Q3 2026)
Photo-to-score pipeline. Target: Persona A scanning parts, Persona B scanning assignments.

| Module | Feature |
|--------|---------|
| C — Image Restoration | Deskew, denoise, binarize scan photos |
| D — OMR Engine | Staff detection, symbol recognition |
| D — OMR Review UI | Side-by-side correction interface |
| B — Import | Camera capture with multi-page flow |

**Key Differentiator**: First Android OMR scanner with sub-5-second recognition.

---

### Stage 3 — Practice Mode & AI Evaluation (Q4 2026)
AI-powered practice features. Target: Persona B and competitive differentiation.

| Feature | Description |
|---------|-------------|
| Score Playback | Synthesized MIDI playback tied to score position |
| AI Score Following | Real-time audio analysis tracks performer position |
| Loop Selection | Select measure range; playback loops |
| Tempo Trainer | Gradually increase BPM over sessions |
| AI Evaluation | Post-practice accuracy, rhythm, dynamics report |
| Practice Log | Session history, progress graphs |

---

### Stage 4 — Collaboration & Ensemble (Q1 2027)
Multi-user and ensemble features. Target: Persona C (director) + ensembles.

| Feature | Description |
|---------|-------------|
| Setlist Sharing | Share setlists with score positions via deep link |
| Real-time Sync | Score position broadcasts to students' devices |
| Part Manager | Upload full score; auto-extract individual parts |
| Cloud Library | Cross-device sync via encrypted cloud storage |
| Export | PDF export with annotations; MusicXML round-trip |
| Homework Assign | Director assigns practice passages to students |

---

## 4. Detailed Feature Specs — Stage 1

### 4.1 Score Library (Home Screen)

**Display**:
- Grid view (default: 2 columns on phone, 3 on tablet) and list view toggle.
- Each card shows: thumbnail (score preview or source-type icon), title, composer, page count, last opened date.
- Sort: last opened (default), date imported, title A–Z, composer A–Z.
- Filter chips: All, PDF, MusicXML, Scanned.
- Search: full-text search on title + composer with debounce 300 ms.

**Import Entry Points**:
- FAB (extended on empty state, icon-only when list populated): opens Import Screen.
- Toolbar import icon (secondary entry point).

**Score Management**:
- Long-press: context menu (Open, Rename, Delete, Share).
- Swipe-to-delete with undo snackbar (5 s window).
- Pull-to-refresh.

**Empty State**:
- Illustrated empty state with CTA "Import your first score".
- Three quick-import chips: Camera, File, URL.

---

### 4.2 Score Import

**Camera Capture**:
- Viewfinder with document edge detection overlay.
- Multi-page flow: capture → review → add more / done.
- Auto-crop and deskew (Module C).
- Processing progress indicator.

**File Picker**:
- Supported formats: PDF, MusicXML (.xml, .mxl), MIDI (Stage 2), images (JPG, PNG, TIFF).
- Platform file picker integration (file_picker package).

**URL Import**:
- Paste link from clipboard or type.
- Detect IMSLP URLs and fetch directly.
- Detect raw MusicXML URLs.

**Import Progress**:
- Inline progress card in library while processing.
- Cancelable.
- Error state with retry.

---

### 4.3 Score Viewer

**Page Display**:
- Modes: Single Page (default on phone), Double Page (tablet landscape), Continuous Scroll.
- Auto-select mode based on device/orientation.
- User override in viewer menu.

**Toolbar Behavior**:
- Auto-hide after 3 s of no interaction.
- Tap center of screen to toggle.
- Top toolbar: back, title/composer, display mode, zoom menu, annotation toggle, settings.
- Bottom toolbar: previous page, page indicator (n/N), next page, playback controls (Stage 3).

**Page Navigation**:
- Tap zones: left 15% (previous), right 15% (next), center (toggle toolbars).
- Swipe: horizontal swipe with page-curl animation on iOS, slide on Android.
- BT pedal: right pedal = next, left pedal = previous.
- Page jump: tap page indicator to enter number.

**Zoom**:
- Pinch-to-zoom (0.5x – 4.0x).
- Double-tap: cycle fit-to-width → 100% → fit-to-height.
- Zoom level persists per score.

**Display Modes**:
- Normal (cream/white background, black notes).
- Night mode (dark gray background, off-white notes).
- Sepia mode (warm paper tone).

---

### 4.4 Annotation Mode

**Tools** (toolbar, left side in landscape):
- Pen: color picker, 3 sizes (fine, medium, broad).
- Highlighter: color picker (yellow/green/pink/blue), 2 sizes.
- Text: inline text box.
- Stamp: fingering numbers (1–5), dynamic marks (p/mp/mf/f/ff), bowing (up/down), breath mark.
- Eraser: point eraser.

**Layers**:
- Layer per annotation session (date-stamped).
- Toggle visibility per layer.
- Maximum 5 layers.

**Undo/Redo**: unlimited within session.

**Persistence**: annotations saved as vector overlay, not baked into score image.

---

### 4.5 BT Pedal Integration (Module K)

**Supported Actions**:
- Single press right: next page.
- Single press left: previous page.
- Double press right: half-page advance (if in single-page mode).
- Long press: activate annotation mode (if configured).

**Pairing Flow**:
- Device Manager screen (Settings > Devices).
- Scan button shows nearby BT HID devices.
- One-tap pairing.
- Persistent pairing (reconnect on app launch).

---

## 5. User Stories — Stage 1 MVP

### Library

```
US-001  As a musician, I can see all my imported scores in a grid,
        so I can find what I need quickly.

US-002  As a musician, I can search by title or composer and see
        filtered results in < 300ms, so I don't lose momentum.

US-003  As a musician, I can swipe to delete a score with a 5-second
        undo window, so accidental deletes are recoverable.

US-004  As a musician, I can sort my library by last opened, date
        imported, or title, so the most relevant score is always first.
```

### Import

```
US-010  As a musician, I can import a PDF from my device files and
        have it appear in the library, so I can view scores I already have.

US-011  As a musician, I can import a MusicXML file and see it
        rendered as a proper music score (not raw XML),
        so the output is musically readable.

US-012  As a musician, I can paste an IMSLP URL and the app
        fetches and imports the score, so I don't leave the app.

US-013  As a musician, I see a progress indicator during import
        and can cancel if it takes too long.
```

### Score Viewer

```
US-020  As a musician, I can open a score and see it full-screen
        with toolbars hidden, so nothing distracts from the music.

US-021  As a musician, I can turn pages by swiping left/right,
        so the interaction feels natural.

US-022  As a musician, I can turn pages by tapping the left/right
        15% zones, so I can navigate one-handed.

US-023  As a musician, I can pinch to zoom and the score stays
        sharp (vector rendering), so I can read small details.

US-024  As a musician, I can activate night mode so the screen
        doesn't blind me in a dark pit.

US-025  As a musician, I can see a page indicator (3 / 12) at the
        bottom and tap it to jump to any page.
```

### BT Pedal

```
US-030  As a performer, I can connect a BT page-turn pedal from
        the Device Manager and use it to turn pages without touching
        the screen, so my hands remain on the instrument.

US-031  As a performer, the pedal reconnects automatically when I
        open the app, so I don't re-pair before every performance.
```

### Settings

```
US-040  As a musician, I can switch between light, dark, and sepia
        display modes and the change is reflected immediately in
        the viewer.

US-041  As a musician, I can choose between single-page and
        double-page layout modes as a default.
```

---

## 6. Success Metrics (KPIs)

### Stage 1 Launch Metrics (30 days post-release)

| Metric | Target |
|--------|--------|
| DAU / MAU ratio | >= 40% |
| Score import success rate | >= 95% |
| Crash-free session rate | >= 99.5% |
| Avg. session duration | >= 8 min |
| App Store / Play Store rating | >= 4.5 |
| Page render time (p95) | < 100 ms |
| Cold startup time (p95) | < 2 s |

### 3-Month Growth Metrics

| Metric | Target |
|--------|--------|
| Monthly Active Users | 5,000 |
| Scores imported per active user | >= 5 |
| BT pedal pairing completion rate | >= 70% of pedal-owning users |
| Stage 2 waitlist sign-ups | 2,000 |

### Quality Gates

| Gate | Threshold |
|------|----------|
| Unit test coverage (critical paths) | >= 80% |
| Integration test coverage | >= 60% |
| Accessibility audit (WCAG 2.1 AA) | 0 failures |
| Security scan CVSS critical findings | 0 |

---

## 7. Non-Functional Requirements

### Performance

| Requirement | Target |
|------------|--------|
| Cold startup | < 2 s on mid-range Android (Snapdragon 695) |
| Score render (first page) | < 100 ms after data load |
| Page navigation animation | 60 fps, no jank |
| Library load (100 scores) | < 200 ms |
| Search debounce response | < 300 ms |
| BT pedal action latency | < 100 ms end-to-end |
| Memory (baseline) | < 200 MB |
| Memory (peak with score open) | < 500 MB |

### Accessibility

- WCAG 2.1 Level AA compliance.
- All interactive elements: minimum 44x44 dp touch target.
- Screen reader (TalkBack, VoiceOver) support for all navigation actions.
- High-contrast mode compatibility.
- Dynamic type support (font scaling to 200%).
- Color-blind safe palette (no information conveyed by color alone).

### Platform Support

| Platform | Minimum Version |
|---------|----------------|
| iOS | 16.0 |
| Android | API 26 (Android 8.0) |
| macOS | 13.0 (Ventura) |
| Web | Chrome 111+, Safari 16+, Firefox 115+ |
| Windows | Windows 10 21H1+ |

### Security

- All file operations sandboxed to app container.
- No network access in Stage 1 except IMSLP URL fetch (HTTPS only, certificate pinning).
- No analytics SDK in Stage 1 (privacy-first).
- Crash reports: opt-in, anonymized.
- User data (scores, annotations) never sent to any server in Stage 1.

### Offline First

- 100% of Stage 1 features work offline.
- No mandatory account creation.

### Localization (Stage 1)

- English (primary).
- Korean (internal team language; shipped with app).
- Architecture supports adding locales without code changes.
