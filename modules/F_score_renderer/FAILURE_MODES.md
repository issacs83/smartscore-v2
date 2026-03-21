# Module F: Score Renderer - Failure Modes

## F-F01: Empty Score

**Condition**:
- Score JSON contains 0 measures in all parts
- Score JSON contains parts but each part has empty measures array
- After parsing, Part.measures.isEmpty for all parts

**Detection Method**:
1. Parse Score JSON
2. Iterate all parts: `for part in scoreJson.parts { if (part.measures.isEmpty) count++ }`
3. If count == parts.length, score is empty

**Recovery Action**:
- Return PageLayout with 1 page, empty systems array
- Render 1 blank page with message "Empty score" (optional, implementation-dependent)
- No exception, graceful degradation

**Test Case**:
```
Input: Score JSON with 1 part, 0 measures
Command: renderPage(scoreJson, 0, config)
Expected: PageLayout { pageNumber: 0, totalPages: 1, systems: [] }
Verify: Renders as blank page, no crash
```

---

## F-F02: Invalid Page Index

**Condition**:
- `page` < 0
- `page` ≥ getTotalPages(scoreJson, config)
- `page` is NaN or null

**Detection Method**:
1. Calculate total pages: `totalPages = getTotalPages(scoreJson, config)`
2. Check: `if (page < 0) || (page >= totalPages) || isNaN(page), invalid`

**Recovery Action**:
- Return PageLayout with pageNumber set to requested index
- systems array is empty (0 systems)
- canvasWidth, canvasHeight set to config paper size
- No exception thrown

**Test Case - Below Range**:
```
Command: renderPage(scoreJson, -1, config)
Expected: PageLayout { pageNumber: -1, systems: [] }
```

**Test Case - Above Range**:
```
Input: 2-page score
Command: renderPage(scoreJson, 5, config)
Expected: PageLayout { pageNumber: 5, systems: [] }
```

**Test Case - NaN**:
```
Command: renderPage(scoreJson, NaN, config)
Expected: PageLayout { pageNumber: NaN, systems: [] }
```

---

## F-F03: Unsupported Clef/Key/Time

**Condition**:
- Clef type not in {treble, bass, alto, tenor, grand_staff}
- Key signature chromatic distance > ±7 (more than 7 sharps/flats)
- Time signature numerator or denominator not in standard set
- Clef appears mid-measure (non-standard)

**Detection Method**:
1. Parse clef attribute: check against whitelist {treble, bass, alto, tenor}
2. Parse key: count sharps/flats, if |count| > 7, unsupported
3. Parse time: check numerator ∈ [1,16], denominator ∈ [2,16]
4. Check clef position: measure number must be 0 or at measure boundary

**Recovery Action**:
- **Clef unsupported**: Skip clef rendering, continue (staff lines still rendered)
- **Key unsupported**: Render naturals only (no sharps/flats), log warning
- **Time unsupported**: Skip time signature rendering, continue
- **Clef mid-measure**: Render at measure boundary instead
- No exception, continue rendering

**Test Case - Unsupported Clef**:
```
Input: Score with clef type "varC1" (unsupported)
Command: renderPage(scoreJson, 0, config)
Expected: Page rendered, clef area blank, staff lines present
```

**Test Case - Extreme Key Signature**:
```
Input: Key with 12 sharps (unsupported)
Command: renderPage(scoreJson, 0, config)
Expected: Key area blank or naturals shown, no crash
```

**Test Case - Unusual Time**:
```
Input: Time signature 13/16 (unusual but supported)
Command: renderPage(scoreJson, 0, config)
Expected: Rendered correctly
```

---

## F-F04: Canvas Size Too Small

**Condition**:
- Canvas width < 200 pixels
- Canvas height < 150 pixels
- Zoom level < 0.25 (effectively reduces canvas size)
- Paper size does not fit within available screen space

**Detection Method**:
1. Calculate final canvas dimensions: `finalWidth = paperWidth × zoom`
2. Check: `if (finalWidth < 200) || (finalHeight < 150), too_small`

**Recovery Action**:
- Return PageLayout with bounds calculated (not visually rendered)
- Canvas output: render "Canvas too small" message or skip rendering
- Caller responsible for increasing zoom or page dimensions
- No exception

**Test Case**:
```
Input: 100×100 pixel canvas, A4 paper, zoom=0.5
Command: renderPage(scoreJson, 0, config)
Expected: PageLayout returned but rendering skipped
Message: Log warning "Canvas size 100×100 insufficient (minimum 200×150)"
```

---

## F-F05: Note Outside Renderable Range

**Condition**:
- Note pitch below A0 (MIDI 21)
- Note pitch above C8 (MIDI 108)
- Note position calculated as NaN (corrupted measure width data)
- Staff count mismatches part definition

**Detection Method**:
1. Parse pitch: `{ step, octave, alter }`
2. Convert to MIDI: `midi = (octave + 1) × 12 + noteValue[step] + alter`
3. Check: `if (midi < 21) || (midi > 108), out_of_range`

**Recovery Action**:
- **Pitch below A0**: Clip to A0, render with note position scaled to A0 line
- **Pitch above C8**: Clip to C8
- **Position NaN**: Use default position (measure center)
- **Staff mismatch**: Render on highest available staff
- Continue rendering, no exception

**Test Case - Below Range**:
```
Input: Note pitch G#0 (below A0)
Command: renderPage(scoreJson, 0, config)
Expected: Note clipped to A0, rendered at bottom staff line
```

**Test Case - Above Range**:
```
Input: Note pitch C#9
Command: renderPage(scoreJson, 0, config)
Expected: Note clipped to C8, rendered above staff
```

---

## F-F06: Overlapping Elements

**Condition**:
- Multiple notes with same (x, y, pitch) → note collision
- Accidentals overlap with note heads
- Measure numbers overlap with previous/next measure numbers
- Rehearsal marks overlap with clef or time signature
- Dynamics text overlaps with notes or other text

**Detection Method**:
1. Collect bounds for all rendered elements: List<Rect>
2. For each pair: if rect1.intersects(rect2) and both have priority, collision detected
3. Log collision but do not block rendering

**Recovery Action**:
- **Note collisions**: Adjust horizontal spacing, no repositioning
- **Text overlaps**: Render text in z-order (no collision avoidance)
- **Barline overlaps**: Adjust barline position slightly
- Continue rendering, overlaps visible (user responsibility to fix notation)

**Test Case**:
```
Input: Two notes in same position (x, y, pitch)
Command: renderPage(scoreJson, 0, config)
Expected: Both notes rendered (may appear as single note or overlapped)
Verify: No crash, log warning
```

---

## F-F07: Invalid Score JSON Schema

**Condition**:
- Missing required field: id, title, parts, or measures
- Enum value not in allowed set (e.g., noteType = "invalid")
- Type mismatch: string where int expected
- Malformed nested object: Part missing required fields
- Null/undefined in required position

**Detection Method**:
1. Parse JSON
2. Validate against SCORE_JSON_SCHEMA (see docs/SCORE_JSON_SCHEMA.md)
3. Check all required fields present and correct type
4. Check all enum values match definition

**Recovery Action**:
- Return null from renderPage() (optional, implementation-dependent)
- Or return PageLayout with error message in log
- Do not render partial/invalid score
- Log specific validation error with line/field information

**Test Case**:
```
Input: Score JSON missing "parts" array
Command: renderPage(scoreJson, 0, config)
Expected: null or error PageLayout
```

---

## F-F08: Hit Test Outside Page Bounds

**Condition**:
- hitTest() called with coordinates outside canvas
- x < 0 or x > canvasWidth
- y < 0 or y > canvasHeight
- pageLayout is from different page than visual render

**Detection Method**:
1. Check: `if (x < 0) || (x > pageLayout.canvasWidth) || (y < 0) || (y > pageLayout.canvasHeight), outside_bounds`

**Recovery Action**:
- Return HitTestResult { type: "none" }
- No exception
- Caller may interpret "none" as miss

**Test Case**:
```
Input: pageLayout from page 0 (width=800), hitTest position {x: 900, y: 400}
Command: hitTest(position, pageLayout)
Expected: HitTestResult { type: "none" }
```

---

## F-F09: Concurrent Rendering Requests

**Condition**:
- renderPage() called simultaneously from multiple threads/coroutines
- hitTest() called while renderPage() executing
- Cache invalidation during render

**Detection Method**:
1. Use thread-local state to detect concurrent calls
2. If detectConcurrentRender(), log warning

**Recovery Action**:
- Serialize requests (queue internally) or reject second call
- Return result for first call, queue second
- No exception, but may experience latency

**Test Case**:
```
Setup: renderPage(scoreJson, 0, config) + renderPage(scoreJson, 1, config) in parallel
Expected: Both complete eventually, either sequential or parallel
Verify: No data corruption, consistent results
```

---

## Summary Table

| Code | Condition | Detection | Recovery | Test |
|------|-----------|-----------|----------|------|
| F-F01 | Empty score | 0 measures | Return empty page | Create 0-measure score |
| F-F02 | Invalid page index | page < 0 or ≥ total | Return empty PageLayout | Render page 999 |
| F-F03 | Unsupported clef/key/time | Not in whitelist | Skip rendering element | Import unusual key |
| F-F04 | Canvas too small | W < 200 or H < 150 | Skip visual output | 100×100 canvas |
| F-F05 | Note out of range | MIDI < 21 or > 108 | Clip to range | Pitch G#0 or C#9 |
| F-F06 | Overlapping elements | Bounds intersect | Render in z-order | Duplicate notes |
| F-F07 | Invalid JSON schema | Validation fails | Return null/error | Missing "parts" field |
| F-F08 | Hit test outside bounds | x/y outside canvas | Return type: "none" | Click outside page |
| F-F09 | Concurrent rendering | Multiple threads | Serialize or queue | Parallel renderPage calls |
