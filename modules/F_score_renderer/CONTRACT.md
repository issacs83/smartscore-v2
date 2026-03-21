# Module F: Score Renderer - Contract

## Module Purpose
Transforms Score JSON (internal normalized format) into real-time visual representation. Provides layout metrics for hit testing, measure/note positioning, and interactive element tracking. Supports multi-page layout with configurable rendering parameters.

## Input Specifications

### Score JSON Input
- **Format**: Internal Score JSON conforming to SCORE_JSON_SCHEMA.md
- **Source**: Module E output (OMR) or Module C (user edits)
- **Validation**: All required fields present, enums match defined values
- **Content**: ≥1 part, ≥1 measure per part

### Current Position (Optional)
```
position: {
  page?: int,           // 0-indexed, ≤ totalPages - 1
  system?: int,         // 0-indexed per page
  measure?: int,        // Absolute measure number (0-indexed)
  beat?: float          // 0.0–4.0 (or 0.0–time signature numerator)
}
```

### Render Configuration
```
config: {
  zoom: float,                        // 0.5–4.0 (0.5 = 50%, 1.0 = 100%, 2.0 = 200%)
  darkMode: bool,                     // false = light bg, true = dark bg
  measuresPerSystem: int,             // 1–20 (default 4, affects page breaks)
  systemsPerPage: int,                // 1–20 (default 6, affects page breaks)
  showMeasureNumbers: bool,           // true shows measure numbers
  showRehearsalMarks: bool,           // true shows rehearsal marks
  currentPositionColor: string,       // Hex color #RRGGBB or named (e.g., "blue")
  currentPositionOpacity: float,      // 0.0–1.0
  paperSize: enum["A4", "Letter"],    // Page dimensions
  marginTop: int,                     // Pixels, default 40
  marginBottom: int,
  marginLeft: int,
  marginRight: int
}
```

### Edit State (Optional)
```
editState: {
  selectedNotes: List<string>,        // Note element IDs
  selectedMeasures: List<int>,        // Measure numbers
  highlightError: List<string>,       // Element IDs with errors (red outline)
  fadeOutMeasures: List<int>          // Measures at reduced opacity
}
```

## Output Specifications

### PageLayout Object
```
{
  pageNumber: int,              // 0-indexed
  totalPages: int,
  canvasWidth: int,             // Pixels, depends on paper size + margins
  canvasHeight: int,
  systems: List<SystemLayout>,
  pageMargins: { top, bottom, left, right }
}
```

### SystemLayout Object
```
{
  systemNumber: int,            // 0-indexed within page
  yPosition: int,               // Pixels from page top
  height: int,                  // Pixels
  measures: List<MeasureLayout>,
  startMeasure: int,            // First measure number on this system
  endMeasure: int               // Last measure number on this system
}
```

### MeasureLayout Object
```
{
  measureNumber: int,           // 0-indexed, absolute
  xPosition: int,               // Pixels from system left
  yPosition: int,               // Pixels from system top
  width: int,                   // Pixels
  height: int,                  // Pixels (staff system height)
  notes: List<NoteLayout>,
  bounds: Rect { x, y, w, h },
  timeSignature?: string,       // e.g., "4/4"
  keySignature?: string,        // e.g., "G major"
  hasRepeatStart: bool,
  hasRepeatEnd: bool,
  rehearsalMark?: string        // e.g., "A", "B1"
}
```

### NoteLayout Object
```
{
  elementId: string,            // Unique within score
  pitch: { step, octave, alter }, // e.g., C4, D#5
  noteType: enum,               // "whole", "half", "quarter", "eighth", "sixteenth"
  xPosition: int,               // Pixels from measure left
  yPosition: int,               // Pixels from staff top (5 lines)
  width: int,                   // Note head width
  height: int,                  // Note head height
  stemBounds?: Rect,            // Stem line bounding box
  beamBounds?: Rect,            // Beam line bounding box
  dots: int,                    // 0–3 (augmentation dots)
  staff: int,                   // 0-indexed within part
  voice: int,                   // 0-indexed
  accidental?: "#" | "b" | "♮",  // Actual rendered accidental
  isInChord: bool,              // true if part of chord
  hasArtulation: bool,
  hasDynamic: bool
}
```

### HitTestResult Object
```
{
  type: enum ["measure", "note", "rest", "barline", "staff", "none"],
  measureNumber?: int,
  noteId?: string,
  pitch?: { step, octave },
  beat?: float,                 // Position within measure (0.0–time sig numerator)
  confidence: float             // 0.0–1.0, always 1.0 for clickable elements
}
```

## Supported Musical Elements

### Clefs
- Treble (G2)
- Bass (F4)
- Alto (C3)
- Tenor (C4)
- Grand staff (treble + bass, automatically paired)

### Key Signatures
- Natural keys: C, F, G, D, A, E, B
- Flats: F, Bb, Eb, Ab, Db, Gb, Cb
- Sharps: G, D, A, E, B, F#, C#

### Time Signatures
- Simple: 2/4, 3/4, 4/4, 2/2
- Compound: 6/8, 9/8, 12/8
- Complex: 5/4, 7/8, 15/16

### Notes (Pitches)
- Range: A0 to C8 (88 keys + extension)
- Note types: whole, half, quarter, eighth, sixteenth, thirty-second
- Accidentals: natural, sharp, flat, double-sharp, double-flat

### Rests
- All durations corresponding to note types
- Rendered as standard notation symbols

### Symbols
- Stems: vertical lines from note heads
- Beams: connecting eighth+ notes
- Barlines: single, double, final
- Repeat signs: start, end
- Time/key signature changes mid-measure
- Clef changes mid-measure
- Rehearsal marks (letters A–Z, numbers)
- Measure numbers (optional)

### Articulations
- Staccato, accent, tenuto, marcato (rendered as symbols above/below notes)

### Dynamics
- Text indicators: ppp, pp, p, mp, mf, f, ff, fff
- Rendered as text

## API Contract

### renderPage(scoreJson: string, page: int, config: RenderConfig) → PageLayout
**Behavior**:
- Parse Score JSON
- Calculate layout: measure widths, system breaks, page breaks based on config
- Page pagination: distribute measures across systems based on measuresPerSystem and systemsPerPage
- Render page @index (0-indexed)
- Return PageLayout with all geometry

**Preconditions**:
- `scoreJson` is valid JSON conforming to SCORE_JSON_SCHEMA
- `page` ∈ [0, getTotalPages(scoreJson, config) - 1]
- `config` has valid values

**Postconditions**:
- All Rect bounds have integer pixel coordinates
- All measures on page have bounds
- All notes on page have bounds

**Error handling**: Invalid page index returns PageLayout with empty systems (no exception)

**Complexity**: O(n) where n = measures on page (~10–50)

### hitTest(position: {x, y}, pageLayout: PageLayout) → HitTestResult | null
**Behavior**:
- Check if (x, y) in pixel coordinates falls within rendered element
- Search in order: note > rest > barline > measure > staff > none
- Return HitTestResult with element type and metadata
- Return null if (x, y) outside all elements

**Preconditions**:
- `position` is valid {x, y} pixel coordinate
- `pageLayout` returned from renderPage()

**Complexity**: O(m) where m = notes on page (~100–500)

**Optimization**: Spatial index (quadtree) recommended for large scores

### getPageForMeasure(measureNumber: int, config: RenderConfig) → int
**Behavior**:
- Calculate which page contains measureNumber
- Use same layout algorithm as renderPage()
- Return 0-indexed page number

**Preconditions**:
- `measureNumber` ∈ [0, totalMeasures - 1]
- `config` is valid

**Return**: Page number ∈ [0, getTotalPages() - 1], or 0 if measure not found

**Complexity**: O(n) linear scan (could cache results)

### getTotalPages(scoreJson: string, config: RenderConfig) → int
**Behavior**:
- Parse Score JSON
- Calculate layout without rendering
- Count resulting pages
- Return page count

**Preconditions**:
- `scoreJson` is valid
- `config` is valid

**Return**: Integer ≥ 1 (at minimum 1 page, even if content exceeds space)

**Complexity**: O(n) where n = total measures

---

## Current Position Rendering

### Highlight Specification
- **Shape**: Rectangle outline around measure or note
- **Color**: From config.currentPositionColor (default: blue)
- **Opacity**: config.currentPositionOpacity (default: 0.5)
- **Width**: 2–3 pixels outline
- **Animation**: Optional fade-in/out (0.3 second)

### Position Levels
1. **measure**: Highlight entire measure bounds
2. **system**: Highlight entire system (all measures on system)
3. **beat**: Highlight current note at beat position + adjacent notes in chord
4. **page**: Entire page background tint (optional)

---

## Canvas Output Format

**Render target**: Canvas abstraction (platform-agnostic)
- Platform implementations: SkCanvas (Android), Metal (iOS), Direct2D (Windows)
- Output: Sequence of draw commands (fill rects, stroke paths, render text)

**Example pseudocode**:
```
canvas.fillRect(margin, margin, pageWidth - margin, pageHeight - margin, color: white)
canvas.strokeRect(x, y, w, h, color: black, width: 1)  // measure bounds
canvas.fillText("4/4", x+10, y+20)                      // time signature
canvas.strokePath(noteHeadPath, color: black)           // note head outline
canvas.fillPath(stemPath, color: black)                 // stem fill
```

---

## Edge Cases & Constraints

### Empty Score
- If 0 measures in any part, return PageLayout with 1 empty page
- No error, graceful rendering of "empty score"

### Invalid Page Index
- Page ≥ totalPages: return empty PageLayout
- Page < 0: return empty PageLayout
- No exception

### Unsupported Clefs/Keys/Times
- Clef not in {treble, bass, alto, tenor}: skip clef rendering, continue
- Key not supported: render naturals only
- Time signature not supported: skip rendering, continue
- Score still renderable with fallback

### Canvas Size Too Small
- If canvas width < 200 px or height < 150 px: no rendering attempted
- Return PageLayout with bounds but no visual output
- Caller responsible for ensuring adequate canvas size

### Notes Outside Renderable Range
- Note pitch > C8: clipped to C8
- Note pitch < A0: clipped to A0
- Rendered on extended staff lines if necessary

### Overlapping Elements
- Overlapping note heads: z-order = voice order (voice 1 on top)
- Overlapping accidentals: no collision detection (user responsibility)
- Overlapping text (measures, rehearsal marks): layer text on top of staff
- No automatic avoidance

### Very Long Measures
- Measure width > config.measuresPerSystem space: flows to next system
- Measure width > page width: rendered at reduced zoom (automatic)
- Measure cannot be split across systems

### Key/Time Changes Mid-Score
- New key signature at measure boundary: rendered in measure
- New time signature at measure boundary: rendered in measure
- Both supported without special handling

---

## Performance Requirements

**Rendering latency** (p95):
- Single measure: < 10 ms
- Single page (4 measures × 6 systems = 24 measures): < 100 ms
- 100-measure score (4 pages): < 400 ms

**Memory** (per page):
- Typical page (~30 measures): < 50 MB
- Large page (~100 measures): < 150 MB

**Caching**:
- Cache previous page (LRU 3-page cache recommended)
- Invalidate cache on config change or position change
- Prerender next/previous page in background

---

## Dependencies
- **Canvas abstraction**: Custom or platform-specific (Skia, Metal, Direct2D)
- **Font rendering**: TrueType fonts for music notation (SMuFL-compliant)
- **Geometry library**: Rectangle, Path, Matrix operations
- **Score JSON parser**: Conforming to SCORE_JSON_SCHEMA

---

## Version Management Rules
1. Render only active version (user_edited_score_json or omr_score_json from Module B)
2. Each render call is stateless (no internal caching)
3. Caller manages cache for performance
