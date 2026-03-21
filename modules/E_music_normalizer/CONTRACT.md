# E_music_normalizer Contract Specification

## Module Purpose

Module E provides the core data models, parsing, and validation for musical scores in the SmartScore system. It translates between MusicXML (external format) and Score JSON (internal standard format).

## Input Contracts

### MusicXmlParser.parse(String musicXmlString) → ParseResult

**Preconditions:**
- Input must be valid XML syntax (well-formed)
- Root element must be `score-partwise` (not `score-timewise`)
- Document must contain exactly one `part-list` element
- Each `score-part` must have unique `id` attribute
- Each `part` must have `id` matching a `score-part`

**Input Assumptions:**
- Divisions element (if present) indicates duration units per quarter note
- Note duration is in division units (not quarters)
- Pitch steps are A–G (uppercase)
- Octave numbers use 0-8 range (middle C = octave 4)
- Voice and staff numbers are 1-indexed in MusicXML (converted to 0-indexed)

**Invalid Cases Handled:**
- Malformed XML: Returns ParseResult with errors list, score=null
- Missing part-list: Error logged, score=null
- Empty part-list: Error logged, score=null
- Unknown elements: Warning logged (non-blocking)
- Missing part/measure attributes: Defaults used

### Score.validate() → List<ValidationError>

**Preconditions:**
- Score object must be initialized with all required fields
- Parts list must contain at least one Part
- Each Part must contain at least one Measure

**Validation Scope:**
- UUID format validation (RFC 4122)
- String length constraints (title 1-256, composer 0-256)
- Numeric ranges (octave 0-8, tempo 30-300, voice 0-3)
- Part structure completeness

### ScoreValidator.validate(Score score) → ValidationReport

**Preconditions:**
- Score object must be valid (pass Score.validate())
- All parts must have at least one measure with timeSignature
- No null references in measure elements

**Validation Scope:**
- Measure duration consistency with time signature
- Pitch ranges per instrument type (absolute + typical ranges)
- Chord consistency (matching durations for chord members)
- Time signature continuity

## Output Contracts

### ParseResult

**Guaranteed Properties:**
- Exactly one of: `score != null` OR `errors.isNotEmpty`
- `parseTimeMs >= 0` (always measured)
- `warnings` may contain non-blocking issues even if score != null
- All ParseError/ParseWarning objects have message, lineNumber (optional), elementPath (optional)

**Score Guarantee (if not null):**
- Valid UUID format
- Title length 1-256 characters
- Composer length 0-256 characters
- At least 1 part
- At least 1 measure per part
- At least 1 element per measure (if not empty)

### ValidationReport

**Guaranteed Properties:**
- `score` value 0.0-1.0 (never NaN, never out of range)
- `isValid` = true ⟺ errors.isEmpty
- All ValidationIssue objects have category, message, optional path/measureNumber
- Reports are deterministic for same input Score

**Score Semantics:**
- 1.0 = No errors, no warnings
- 0.8-0.99 = No errors, some warnings
- 0.5-0.79 = Multiple non-critical issues
- 0.0-0.49 = Critical validation failures

## Type Contracts

### Pitch

**MIDI Number Computation:**
- Formula: `12 * (octave + 1) + noteStepValue + alter`
- Note step values: C=0, D=2, E=4, F=5, G=7, A=9, B=11
- C4 = 60 (guaranteed, mathematically)
- A4 = 69 (guaranteed, mathematically)
- C5 = 72 (guaranteed, mathematically)
- Valid range: octave ∈ [0,8], alter ∈ [-2,2]

**Frequency Computation:**
- Formula: `f = 440 * 2^((midi - 69) / 12)`
- A4 = 440.0 Hz (guaranteed, by definition)
- Monotonically increasing with MIDI number
- Doubles every octave (±0.01% tolerance for floating-point)

### InstrumentType

**Type Mapping Guarantees:**
- 28 distinct instrument types enumerated
- `fromString()` is case-insensitive
- Unknown strings → generic (never null, never exception)
- `fromName()` handles ≥50 common instrument name variations
- All lookups are O(n) string comparison, deterministic

**Supported Names (Examples):**
- "Violin I", "Violin II", "Vln", "1st Violin" → violin
- "Cello", "Vcl", "Violoncello" → cello
- "Piano", "Pno", "Pianoforte" → piano
- "French Horn", "Horn in F" → horn
- "Soprano", "Sop" → soprano
- "Electric Guitar", "Gtr" → guitar
- Unknown → generic (never throws)

### Element Polymorphism

**Factory Pattern Guarantee:**
```dart
Element.fromJson(Map) → NoteElement | RestElement | DirectionElement
```
- Dispatches on `type` field: "note", "rest", "direction"
- Unknown type throws ArgumentError
- Round-trip: `Element.toJson()` → JSON → `Element.fromJson()` preserves all data

### Duration Units

**Standard: 256ths of whole note**
- Whole note = 256 divisions
- Half note = 128
- Quarter note = 64
- Eighth note = 32
- Sixteenth note = 16
- Thirty-second note = 8

**Dotted Duration:**
- Each dot adds half of previous value
- Dotted quarter = 64 + 32 = 96
- Triple-dotted = 64 + 32 + 16 = 112

**Time Signature Duration:**
- 4/4 = (4/4) * 256 = 256 units
- 3/4 = (3/4) * 256 = 192 units
- 6/8 = (6/8) * 256 = 192 units
- 5/4 = (5/4) * 256 = 320 units

## Immutability Contract

**All models are immutable:**
- All fields declared `final`
- No setters
- No mutable collections (all returned as new instances)
- `copyWith()` creates new instance (not modifying original)

**Guarantee:**
```dart
final original = Pitch(step: 'C', octave: 4);
final modified = original.copyWith(octave: 5);
assert(original.octave == 4);  // Unchanged
assert(modified.octave == 5);  // New instance
assert(original != modified);  // Different objects
```

## Serialization Contract

**JSON Round-trip Guarantee:**
```dart
final original = score;
final json = original.toJson();
final restored = Score.fromJson(json);
// restored structurally equivalent to original
// (not necessarily identical objects, but equal values)
```

**Partial Serialization:**
- `toJson()` omits null fields
- `fromJson()` uses defaults for missing optional fields
- No data loss if all fields present

## Error Handling Contract

### MusicXmlParser

**Exception Handling:**
- Catches XML parse exceptions → ParseError (non-throwing)
- Unknown elements → ParseWarning (non-blocking)
- Missing required attributes → ParseWarning (use defaults)
- Invalid pitch/duration values → ParseWarning (skip element)

**Never Throws:**
- Malformed input handled gracefully
- Always returns ParseResult (never null)

### Score Validation

**Contract:**
- `validate()` never throws
- Returns list of ValidationError objects
- Empty list = fully valid
- Errors are categories, not exceptions

## Performance Contract

### Parse Performance

**Guaranteed Complexity:**
- Parse time ∝ O(n) where n = total XML elements
- No backtracking or re-scanning
- Result reported in `parseTimeMs` (wall-clock milliseconds)
- Example: "Twinkle Twinkle" (4 measures) < 10ms on modern hardware

### Validation Performance

**Guaranteed Complexity:**
- Validation ∝ O(m × e) where m = measures, e = elements per measure
- Typical score (100 measures × 8 elements) < 5ms
- Pitch range checks O(1) per note
- Duration checks O(1) per measure

## Version Contract

**Schema Version:** 1.0
**Backward Compatibility:** None (version 1.0 is baseline)
**Forward Planning:** Future extensions will:
- Add new optional fields to existing classes
- Never remove or rename required fields
- Maintain version field in metadata

## Specific Guarantees

### Twinkle Twinkle Little Star Example

When parsing the canonical test case:
- Parses to 4 measures (0-indexed: 0, 1, 2, 3)
- Measure 0: 4 quarter notes (C, C, G, A)
- Measure 1: 3 quarter notes (B, B, B) + 1 rest
- Measure 2: 3 quarter notes (A, A, A) + 1 rest
- Measure 3: 1 half note (G) + 1 half rest
- Time signature: 4/4 throughout
- Key signature: C major (0 alterations)
- All durations validate correctly

### Pitch Verification

```dart
test('Pitch MIDI calculations', () {
  expect(Pitch(step: 'C', octave: 4).midiNumber, 60);
  expect(Pitch(step: 'A', octave: 4).midiNumber, 69);
  expect(Pitch(step: 'C', octave: 5).midiNumber, 72);
});

test('Pitch frequency calculations', () {
  expect(Pitch(step: 'A', octave: 4).frequency, closeTo(440.0, 0.01));
  expect(Pitch(step: 'C', octave: 4).frequency, closeTo(261.63, 0.1));
});
```

These tests are mandatory pass conditions.

## Integration Guarantees

### With Module B (Database)

- Score.metadata.sourceId matches ScoreEntry.id format
- Checksum format matches database expectations
- Timestamps in ISO 8601 format

### With Module F (Rendering)

- Score JSON structure is stable and predictable
- All required fields are always present (no defensive null checks needed)
- Pitch values always valid (no need for out-of-range handling)

### With Module C (Comparison)

- Validation scores are consistent and reproducible
- Error categories are standard and well-documented
- Warning levels don't affect structural integrity

---

**Last Updated:** 2026-03-21
**Status:** Active
**Maintainer:** SmartScore Team (Module E)
