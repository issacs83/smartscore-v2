# Module F: Score Renderer - Test Plan

## Test Infrastructure
- **Framework**: Flutter test (unit) + golden file testing for visual regression
- **Canvas mock**: Custom CanvasRecorder to capture draw calls instead of rasterizing
- **Golden files**: Stored in `test/goldens/f_score_renderer/` with PNG snapshots
- **Setup**: Each test loads test Score JSON from fixtures directory
- **Teardown**: Clear cache, close canvas
- **Timeout**: 10 seconds per test (rendering can be slow)

---

## Unit Tests: renderPage()

### T-F-RENDER-001: Valid single measure
**Setup**: Score JSON with 1 part, 1 measure, treble clef, 4/4 time, C4 quarter note
**Command**: `renderPage(scoreJson, 0, configDefault())`
**Assertions**:
- Return is PageLayout
- pageNumber == 0
- totalPages == 1
- systems.length == 1
- SystemLayout.measures.length == 1
- MeasureLayout bounds: x ≥ marginLeft, w > 0, h > 0
- NoteLayout rendered for C4 note

### T-F-RENDER-002: Valid multi-measure single system
**Setup**: 1 part, 4 measures, 4/4 time
**Command**: `renderPage(scoreJson, 0, { measuresPerSystem: 4 })`
**Assertions**:
- systems.length == 1
- systems[0].measures.length == 4
- measures arranged left-to-right
- measure[0].xPosition < measure[1].xPosition < ... < measure[3].xPosition

### T-F-RENDER-003: Multi-system layout
**Setup**: 1 part, 24 measures, 4/4 time
**Command**: `renderPage(scoreJson, 0, { measuresPerSystem: 4, systemsPerPage: 6 })`
**Assertions**:
- systems.length == 6
- Each system has 4 measures
- systems[0].yPosition < systems[1].yPosition < ... < systems[5].yPosition
- Last measure on page is measure 23 (0-indexed)

### T-F-RENDER-004: Multi-page layout
**Setup**: 1 part, 50 measures, 4/4 time
**Command**: `renderPage(scoreJson, 0, { measuresPerSystem: 4, systemsPerPage: 6 })` + `renderPage(scoreJson, 1, ...)`
**Assertions**:
- renderPage(scoreJson, 0, ...).systems[0].measures[0].measureNumber == 0
- renderPage(scoreJson, 0, ...).systems[5].measures[3].measureNumber == 23
- renderPage(scoreJson, 1, ...).systems[0].measures[0].measureNumber == 24
- getTotalPages(scoreJson, config) == 3

### T-F-RENDER-005: Grand staff layout
**Setup**: 2 parts (treble + bass), 1 measure
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- MeasureLayout.height > single-staff measure height (≈2× due to grand staff)
- System contains both parts' notes
- Bass clef rendered at correct position (lower)

### T-F-RENDER-006: Treble clef rendering
**Setup**: Score with treble clef at start
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Clef symbol rendered to left of first measure
- Clef positioned at y = staff center line (line 2 of 5)

### T-F-RENDER-007: Bass clef rendering
**Setup**: Score with bass clef at start
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Bass clef symbol rendered
- Positioned at y = staff line 4 (from top)

### T-F-RENDER-008: Key signature rendering (C major)
**Setup**: Score with key signature C (no sharps/flats)
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- No sharps/flats rendered (C major is natural)
- Key area blank between clef and first note

### T-F-RENDER-009: Key signature rendering (G major, 1 sharp)
**Setup**: Score with key signature G (F#)
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- One sharp symbol rendered (F# on top line)
- Sharp positioned correctly on staff

### T-F-RENDER-010: Key signature rendering (Bb major, 2 flats)
**Setup**: Score with key signature Bb (Bb, Eb)
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Two flat symbols rendered
- Flats in correct order (Bb before Eb)

### T-F-RENDER-011: Time signature rendering (4/4)
**Setup**: Score with 4/4 time signature
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- "4/4" or ₢ (common time symbol) rendered
- Positioned between key and first measure

### T-F-RENDER-012: Time signature rendering (6/8)
**Setup**: Score with 6/8 time signature
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- "6/8" rendered
- Vertical alignment centered on staff

### T-F-RENDER-013: Measure numbers (showMeasureNumbers: true)
**Setup**: 4 measures, config.showMeasureNumbers = true
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Measure numbers 0, 1, 2, 3 rendered above first system
- Numbers above staff, outside bounds
- Positioned above each measure's x-position

### T-F-RENDER-014: Measure numbers (showMeasureNumbers: false)
**Setup**: Same as T-F-RENDER-013, showMeasureNumbers = false
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- No measure numbers rendered

### T-F-RENDER-015: Whole note rendering
**Setup**: 1 whole note (C4), 4/4 time, single measure
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Note head rendered as hollow oval
- No stem
- Note takes up full measure width (visually)

### T-F-RENDER-016: Half note rendering
**Setup**: 1 half note (C4)
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Note head rendered as hollow oval
- Stem rendered (vertical line)
- Stem length standard (~3.5 staff spaces)

### T-F-RENDER-017: Quarter note rendering
**Setup**: 1 quarter note (C4)
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Note head rendered as filled oval
- Stem rendered
- Width < half note (proportional to duration)

### T-F-RENDER-018: Eighth note rendering
**Setup**: 2 eighth notes beamed together
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Both notes filled head
- Both have stems
- Beam rendered connecting stems
- Beam angle < 10 degrees (nearly horizontal)

### T-F-RENDER-019: Sixteenth note rendering
**Setup**: 4 sixteenth notes beamed
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- All notes filled
- Double beam rendered
- Notes spaced appropriate to duration

### T-F-RENDER-020: Rest rendering (whole rest)
**Setup**: 1 whole rest, 4/4 time
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Rest symbol rendered (centered horizontally in measure)
- Rest positioned on line 3 (by convention for 4/4)

### T-F-RENDER-021: Accidental sharp rendering
**Setup**: Note C#4
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Sharp symbol (#) rendered left of note head
- Sharp positioned on same staff position as note
- Sharp spacing: 0.5 note head width to left of note head

### T-F-RENDER-022: Accidental flat rendering
**Setup**: Note Bb4
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Flat symbol (♭) rendered left of note head
- Positioned correctly

### T-F-RENDER-023: Chord rendering (C-E-G triad)
**Setup**: 1 chord with 3 notes (C4, E4, G4) in same voice
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- All 3 note heads rendered vertically stacked
- Single stem (shared)
- Notes.isInChord == true for all 3

### T-F-RENDER-024: Dots (augmentation) rendering
**Setup**: 1 dotted quarter note (C4, 1 dot = 1.5× duration)
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Note head rendered
- 1 dot rendered right of note head (0.5 space away)
- Dot positioned in space right of note

### T-F-RENDER-025: Multiple dots rendering
**Setup**: 1 double-dotted quarter note (C4, 2 dots)
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Note head + 2 dots rendered
- Dots spaced 0.5 space apart
- Both aligned vertically with note

### T-F-RENDER-026: Barline rendering
**Setup**: Measures separated by barlines
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Single barline between each pair of measures
- Barlines span full staff height
- X-position at measure boundary

### T-F-RENDER-027: Double barline rendering (end of section)
**Setup**: Double barline before final measure
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Two parallel lines rendered
- Spacing < 5 pixels
- Positioned at measure boundary

### T-F-RENDER-028: Repeat signs rendering
**Setup**: Repeat start (|:) at measure 0, repeat end (:|) at measure 3
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Repeat start symbol rendered (dots + barline)
- Repeat end symbol rendered (barline + dots)
- Correct positioning at measure boundaries

### T-F-RENDER-029: Rehearsal mark rendering (showRehearsalMarks: true)
**Setup**: Rehearsal mark "A" at measure 0, config.showRehearsalMarks = true
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- "A" in rectangle rendered above staff
- Positioned above measure 0
- Visible and readable

### T-F-RENDER-030: Zoom 0.5x
**Setup**: config.zoom = 0.5 (50% size)
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- canvasWidth = paperWidth × 0.5
- All elements scaled by 0.5
- Layout still valid

### T-F-RENDER-031: Zoom 2.0x
**Setup**: config.zoom = 2.0 (200% size)
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- canvasWidth = paperWidth × 2.0
- All elements scaled by 2.0
- Text and symbols still readable

### T-F-RENDER-032: Dark mode
**Setup**: config.darkMode = true
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Background rendered as dark color (not white)
- All foreground elements (notes, staff) rendered as light color
- Canvas draw commands include dark background fill

### T-F-RENDER-033: Light mode (default)
**Setup**: config.darkMode = false
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Background white
- Foreground black

### T-F-RENDER-034: Custom margins
**Setup**: config margins { top: 60, bottom: 80, left: 100, right: 50 }
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- First measure xPosition >= 100 (marginLeft)
- Last system yPosition + systemHeight <= canvasHeight - 80 (marginBottom)
- pageMargins in PageLayout match config

### T-F-RENDER-035: Paper size A4
**Setup**: config.paperSize = "A4"
**Command**: `getTotalPages(scoreJson, config)` and `renderPage(scoreJson, 0, config)`
**Assertions**:
- canvasWidth ≈ 210 mm / 25.4 mm-per-inch × 96 DPI ≈ 793 pixels
- canvasHeight ≈ 297 mm / 25.4 × 96 DPI ≈ 1123 pixels

### T-F-RENDER-036: Paper size Letter
**Setup**: config.paperSize = "Letter"
**Command**: Same
**Assertions**:
- canvasWidth ≈ 8.5" × 96 DPI ≈ 816 pixels
- canvasHeight ≈ 11" × 96 DPI ≈ 1056 pixels

---

## Unit Tests: hitTest()

### T-F-HIT-001: Hit on note
**Setup**: Single measure, 1 quarter note C4 at pixel {400, 300}
**Command**: `hitTest({x: 400, y: 300}, pageLayout)`
**Assertions**:
- Result.type == "note"
- Result.noteId == C4 note id
- Result.pitch == { step: "C", octave: 4 }
- Result.confidence == 1.0

### T-F-HIT-002: Hit on measure (no note)
**Setup**: 1 whole rest, click on measure area away from rest
**Command**: `hitTest({x: 350, y: 280}, pageLayout)` (outside rest bounds)
**Assertions**:
- Result.type == "measure"
- Result.measureNumber == 0
- Result.noteId == null

### T-F-HIT-003: Hit on rest
**Setup**: Whole rest at pixel {400, 300}
**Command**: `hitTest({x: 400, y: 300}, pageLayout)`
**Assertions**:
- Result.type == "rest"
- Result.beat == 0.0 (rest at start)

### T-F-HIT-004: Hit on barline
**Setup**: Barline between measures at x = 500
**Command**: `hitTest({x: 500, y: 300}, pageLayout)`
**Assertions**:
- Result.type == "barline"
- Result.measureNumber == 0 or 1 (boundary)

### T-F-HIT-005: Hit outside all elements
**Setup**: Click in margin
**Command**: `hitTest({x: 10, y: 10}, pageLayout)` (within margin)
**Assertions**:
- Result.type == "none" or null
- Result.noteId == null

### T-F-HIT-006: Hit on staff line (no elements)
**Setup**: Click on staff line but no notes/rests
**Command**: `hitTest({x: 300, y: 280}, pageLayout)` (on staff, no note)
**Assertions**:
- Result.type == "staff"
- Result.measureNumber set to nearest measure

### T-F-HIT-007: Hit on note head (tight bounds)
**Setup**: Note at {400, 300}, note head 8×10 px
**Command**: `hitTest({x: 404, y: 305}, pageLayout)` (inside bounds by 4px)
**Assertions**:
- Result.type == "note"

### T-F-HIT-008: Miss note head (tight bounds)
**Setup**: Same note
**Command**: `hitTest({x: 409, y: 305}, pageLayout)` (outside bounds by 1px)
**Assertions**:
- Result.type != "note" or null

### T-F-HIT-009: Hit on chord (multiple notes)
**Setup**: Chord C-E-G, click on E4 (middle note)
**Command**: `hitTest({x: 400, y: 295}, pageLayout)` (E position)
**Assertions**:
- Result.type == "note"
- Result.pitch == { step: "E", octave: 4 }

### T-F-HIT-010: Beat position calculation
**Setup**: 4/4 measure, 4 quarter notes at x = 100, 200, 300, 400
**Command**: `hitTest({x: 150, y: 300}, pageLayout)` (first note area)
**Assertions**:
- Result.beat == 0.0
- Then hitTest({x: 250, y: 300}) → beat == 1.0
- Then hitTest({x: 350, y: 300}) → beat == 2.0
- Then hitTest({x: 450, y: 300}) → beat == 3.0

---

## Unit Tests: getPageForMeasure()

### T-F-PAGE-001: Get page for first measure
**Setup**: 3-page score, config.measuresPerSystem=4, systemsPerPage=6
**Command**: `getPageForMeasure(0, config)`
**Assertions**:
- Return == 0

### T-F-PAGE-002: Get page for middle measure
**Setup**: Same setup, measure 24 (25th measure, 0-indexed)
**Command**: `getPageForMeasure(24, config)`
**Assertions**:
- Return == 1

### T-F-PAGE-003: Get page for last measure
**Setup**: 50 total measures, 3 pages with last page having 2 measures
**Command**: `getPageForMeasure(49, config)`
**Assertions**:
- Return == 2

### T-F-PAGE-004: Get page for non-existent measure
**Setup**: 20 total measures
**Command**: `getPageForMeasure(50, config)`
**Assertions**:
- Return == 0 or -1 (implementation-dependent, but not crash)

---

## Unit Tests: getTotalPages()

### T-F-TOTAL-001: Single measure
**Setup**: 1 measure, config.measuresPerSystem = 1
**Command**: `getTotalPages(scoreJson, config)`
**Assertions**:
- Return == 1

### T-F-TOTAL-002: Fits on one page
**Setup**: 20 measures, config.measuresPerSystem=4, systemsPerPage=6 (24 measures per page)
**Command**: `getTotalPages(scoreJson, config)`
**Assertions**:
- Return == 1

### T-F-TOTAL-003: Spans two pages exactly
**Setup**: 48 measures, 24 per page
**Command**: `getTotalPages(scoreJson, config)`
**Assertions**:
- Return == 2

### T-F-TOTAL-004: Spans two pages with remainder
**Setup**: 50 measures, 24 per page (2 pages + 2 on page 3)
**Command**: `getTotalPages(scoreJson, config)`
**Assertions**:
- Return == 3

### T-F-TOTAL-005: Large score (1000 measures)
**Setup**: 1000 measures
**Command**: `getTotalPages(scoreJson, config)`
**Assertions**:
- Return > 0
- Return completes within 100 ms

---

## Visual Regression Tests

### T-F-VIS-001: Golden image comparison (1 measure)
**Setup**: Single measure (treble clef, 4/4, C4 quarter note)
**Command**: `renderPage(scoreJson, 0, config)` → capture canvas to PNG
**Assertions**:
- Compare PNG to golden file `test/goldens/f_score_renderer/single_measure.png`
- Pixel difference < 0.1% (allow for font rendering variance)

### T-F-VIS-002: Golden image comparison (multi-measure system)
**Setup**: 4 measures on 1 system
**Command**: Same
**Assertions**:
- Compare to golden `multi_measure_system.png`
- Pixel diff < 0.1%

### T-F-VIS-003: Golden image comparison (grand staff)
**Setup**: Piano staff (treble + bass) 2 measures
**Command**: Same
**Assertions**:
- Compare to golden `grand_staff_piano.png`

### T-F-VIS-004: Golden image comparison (complex notation)
**Setup**: Key change, time change, repeat signs, chords, accidentals
**Command**: Same
**Assertions**:
- Compare to golden `complex_notation.png`

---

## Integration Tests: Edge Cases

### T-F-EDGE-001: Empty score
**Setup**: Score JSON with 0 measures
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Return valid PageLayout
- systems.length == 0
- No exception

### T-F-EDGE-002: Very long measure
**Setup**: Measure with 100+ notes (compressed, but valid)
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Measure rendered, possibly overflowing system
- No crash, layout calculated

### T-F-EDGE-003: Key/time change at measure 5
**Setup**: Measures 0–4 in 4/4, C major; measure 5 in 3/4, G major
**Command**: `renderPage(scoreJson, 0, config)`
**Assertions**:
- Key change rendered at measure 5
- Time change rendered at measure 5
- Both correct visually

### T-F-EDGE-004: Clef change mid-score
**Setup**: Treble clef measures 0–2, bass clef measure 3+
**Command**: `renderPage(scoreJson, 0, config)` and page 2
**Assertions**:
- Clef change rendered at measure boundary

---

## Performance Tests

### T-F-PERF-001: Render 1 measure
**Threshold**: < 10 ms
**Setup**: Single measure
**Command**: Timed renderPage()
**Metric**: ms

### T-F-PERF-002: Render 1 page (24 measures)
**Threshold**: < 100 ms
**Setup**: Full page (4 measures × 6 systems)
**Command**: Timed renderPage()
**Metric**: ms

### T-F-PERF-003: Render 100-measure score (4 pages)
**Threshold**: < 400 ms
**Setup**: 100 measures total
**Command**: Timed renderPage() for all 4 pages
**Metric**: ms

### T-F-PERF-004: Hit test latency
**Threshold**: < 5 ms
**Setup**: Page with 50 notes
**Command**: Timed hitTest() 100 times
**Metric**: ms (average)

### T-F-PERF-005: Cache benefit
**Setup**: Render page 0, then page 0 again (should be cached)
**Command**: First render (not cached) vs. second render (cached)
**Threshold**: Second render < 50% of first render time

---

## Test Execution Checklist
- [ ] Render tests: 36 tests
- [ ] Hit test tests: 10 tests
- [ ] Page lookup tests: 3 tests
- [ ] Total pages tests: 5 tests
- [ ] Visual regression tests: 4 tests
- [ ] Edge case tests: 4 tests
- [ ] Performance tests: 5 tests
- [ ] **Total: 67 test cases**

**Pass Criteria**: 67/67 pass, 0 failures, 0 timeouts, visual regression < 0.1% pixel diff
