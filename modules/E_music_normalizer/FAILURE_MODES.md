# E_music_normalizer Failure Modes Analysis

## Overview

This document catalogs known failure modes, mitigation strategies, and recovery paths for the Music Normalizer module (E).

## Category 1: Parser Failures

### F1.1 Malformed XML

**Symptom:** ParseError with message containing "Failed to parse XML"

**Root Causes:**
- Unclosed tags: `<score-partwise><part>` (missing `</part>`)
- Invalid characters: `<part name="P & Q">`
- Encoding issues: BOM markers, mixed UTF-8/ASCII
- Invalid entity references: `&invalid;` instead of `&amp;`

**Detection:**
```dart
if (result.errors.any((e) => e.message.contains('Failed to parse'))) {
  // XML is structurally invalid
}
```

**Recovery:**
1. Validate input encoding (should be UTF-8)
2. Attempt XML repair (sanitize special characters)
3. Report human-readable error to user
4. Fall back to manual score entry

**Prevention:**
- Validate XML before parsing: `xmllint --noout file.xml`
- Use schema validation if source is known (MusicXML spec)

---

### F1.2 Wrong Root Element

**Symptom:** ParseError with message "Root element must be score-partwise"

**Root Causes:**
- MusicXML score-timewise format (measure-based, not part-based)
- Incorrect file type (MIDI, ABC, other format)
- Partial document (subset of score)

**Detection:**
```dart
final root = _doc.rootElement.name.local;
if (root != 'score-partwise') {
  // Format mismatch
}
```

**Recovery:**
1. Check file extension (.xml expected)
2. Offer conversion path for score-timewise
3. Detect other formats (MIDI, ABC) and provide appropriate handler
4. Allow user to specify format explicitly

**Prevention:**
- Document format requirements clearly
- Support multiple input formats with explicit selection
- Validate against MusicXML schema

---

### F1.3 Missing or Empty part-list

**Symptom:** ParseError "score-partwise must have part-list element" OR "empty part-list"

**Root Causes:**
- Corrupted file (part-list deleted)
- Empty score stub
- Version mismatch (old MusicXML without part-list)

**Detection:**
```dart
final partListElem = scoreElement.findElements('part-list').firstOrNull;
if (partListElem == null) {
  // Missing element
}
if (partListElem.findElements('score-part').isEmpty) {
  // Empty list
}
```

**Recovery:**
1. Infer parts from `part` elements if possible
2. Create generic single-part score as fallback
3. Alert user to missing instrumentation data
4. Allow manual part definition

**Prevention:**
- Validate complete document before processing
- Use MusicXML validators
- Test with representative file samples

---

### F1.4 Duplicate Part IDs

**Symptom:** ParseWarning "Part [ID] referenced but not defined" followed by missing part

**Root Causes:**
- Malformed MusicXML: part-list and part elements out of sync
- Typo in ID matching (e.g., "P1" vs "P-1")
- Partial file corruption

**Detection:**
```dart
final partInfoMap = _parsePartList(partListElem);
final partElements = scoreElement.findElements('part');
for (final partElem in partElements) {
  final partId = partElem.getAttribute('id') ?? '';
  if (!partInfoMap.containsKey(partId)) {
    // Mismatch detected
  }
}
```

**Recovery:**
1. Try fuzzy matching on IDs (case-insensitive, whitespace-tolerant)
2. Use part order as fallback (1st part-list entry → 1st part element)
3. Generate synthetic IDs for orphaned parts
4. Log warnings for human review

**Prevention:**
- Validate part-list ↔ part correspondence
- Normalize IDs before comparison
- Provide diagnostic output with mismatch details

---

### F1.5 Unknown Note Type

**Symptom:** NoteElement with noteType="unusual" (not in standard types)

**Root Causes:**
- MusicXML extension element
- Unrecognized duration notation
- Version skew (newer format)

**Detection:**
```dart
const validTypes = ['whole', 'half', 'quarter', 'eighth', 'sixteenth', 'thirty-second'];
if (!validTypes.contains(noteType)) {
  // Unknown type
}
```

**Recovery:**
1. Default to 'quarter' (safe default)
2. Log ParseWarning with original type preserved
3. Continue parsing (non-blocking)
4. Flag in metadata for review

**Prevention:**
- Document supported note types
- Accept and preserve unknown types as-is
- Provide clear warnings in parser output

---

## Category 2: Validation Failures

### F2.1 Measure Duration Mismatch

**Symptom:** ValidationError "Measure duration [X] does not match time signature expectation [Y]"

**Root Causes:**
- User editing error (removed note, didn't adjust duration)
- Tuplet or unusual notation not properly handled
- Rounding error from fractional divisions
- Incomplete measure (anacrusis not marked)

**Detection:**
```dart
int expectedDuration = _parseTimeSignatureDuration(measure.timeSignature!);
int actualDuration = _calculateMeasureDuration(measure.elements);
if (actualDuration != expectedDuration) {
  // Mismatch
}
```

**Recovery:**
1. Calculate missing duration needed
2. Suggest padding with rest
3. Check if measure is anacrusis/pickup measure
4. Flag for manual review

**Severity:** ERROR (blocks some operations)
**User Impact:** Score may render incorrectly or cause playback issues

**Prevention:**
- Validate on every edit
- Auto-adjust durations in UI
- Mark anacrusis measures explicitly
- Provide visual duration feedback

---

### F2.2 Pitch Out of Instrument Range

**Symptom:** ValidationError "Note MIDI [X] outside [instrument] range ([min]-[max])"

**Root Causes:**
- Octave misidentification in OMR
- Manual transcription error
- Instrument type wrong
- Using extended range (rare)

**Detection:**
```dart
final midi = element.pitch.midiNumber;
final range = instrumentRanges[part.instrumentType];
if (midi < range['min'] || midi > range['max']) {
  // Out of range
}
```

**Recovery (Priority Order):**
1. Verify instrument type is correct
2. Check octave (±1 octave adjustment)
3. Verify if extended range is intentional
4. If legitimate, override validation for this note

**Severity:** ERROR (hard limit)
**User Impact:** Cannot physically play note on instrument

**Variants:**
- **PitchOutOfTypical** (WARNING): Outside typical range but physically possible
  - Recovery: Accept with warning, flag for human review
  - Example: Violin C1 (rare but possible)

**Prevention:**
- Auto-detect instrument range from context
- Offer octave correction suggestions
- Provide instrument-specific pitch visualizations

---

### F2.3 Invalid Chord Structure

**Symptom:** ValidationWarning "Chord member durations do not match: [X] vs [Y]"

**Root Causes:**
- Notes added/removed without updating all chord members
- Tie crossing chord boundary
- Irregular tuplet notation
- Serialization error

**Detection:**
```dart
final chordMembers = measure.elements
    .whereType<NoteElement>()
    .where((n) => n.isChordMember);
final firstDuration = chordMembers.first.duration;
if (chordMembers.any((n) => n.duration != firstDuration)) {
  // Duration mismatch in chord
}
```

**Recovery:**
1. Identify which note is likely wrong
2. Suggest correcting shorter/longer notes
3. May indicate incorrect chord membership
4. Allow manual override

**Severity:** WARNING (non-blocking)
**User Impact:** Possible playback timing issues

**Prevention:**
- Enforce chord constraints in editor UI
- Make isChordMember implicit from simultaneous notes
- Validate chords in real-time

---

### F2.4 Missing Time Signature

**Symptom:** ValidationWarning "First measure lacks time signature"

**Root Causes:**
- Implicit time signature (4/4 assumed)
- Corrupted file (time signature dropped)
- Non-standard score (no time signature)

**Detection:**
```dart
if (measure.number == 0 && measure.timeSignature == null) {
  // First measure missing time signature
}
```

**Recovery:**
1. Assume 4/4 (standard default)
2. Parse subsequent measures for inherited time signature
3. Allow user to specify explicitly
4. Log warning but continue

**Severity:** WARNING (recoverable)
**User Impact:** May assume wrong time signature

**Prevention:**
- Make time signature required
- Auto-populate first measure if missing
- Validate time signature chain consistency

---

## Category 3: Data Model Failures

### F3.1 Invalid UUID Format

**Symptom:** ValidationError "Invalid UUID format for score id"

**Root Causes:**
- Source ID mismatch from Module B
- Manual entry error
- Version skew (UUID v5 vs v4)

**Detection:**
```dart
final uuidRegex = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);
if (!uuidRegex.hasMatch(uuid)) {
  // Invalid format
}
```

**Recovery:**
1. Generate new UUID if validation/generation is primary
2. Accept alternate ID formats with conversion
3. Flag for manual review if from external source

**Severity:** ERROR (structural)
**User Impact:** Cannot link to database records

**Prevention:**
- Validate UUIDs at Module B boundary
- Generate UUIDs server-side, pass to parser
- Reject non-conforming IDs explicitly

---

### F3.2 String Length Violations

**Symptom:** ValidationError "Title must be 1-256 characters" or similar

**Root Causes:**
- Very long title or composer name
- Accidental paste of entire document
- Unicode handling (multi-byte chars)

**Detection:**
```dart
if (title.isEmpty || title.length > 256) {
  // Length violation
}
```

**Recovery:**
1. Truncate to max length (preserve semantic content)
2. Move overflow to metadata or description field
3. Ask user to confirm truncation

**Severity:** ERROR (structural)
**User Impact:** Score metadata incomplete

**Prevention:**
- Validate string lengths on input
- Provide length feedback in UI
- Suggest splitting into separate fields

---

### F3.3 Immutability Violation (Programming)

**Symptom:** Difficult to diagnose; internal inconsistency

**Root Causes:**
- Developer bypasses immutability (reflection, unsafe code)
- Concurrent modification
- Serialization/deserialization bug

**Detection:**
- Should never occur in safe Dart (type system enforces)
- Catchable only through data integrity checks

**Recovery:**
1. This should be impossible in Dart
2. If occurs, indicates serious bug in implementation
3. Restart and force reparse from source

**Prevention:**
- Never use reflection on Score models
- Never share mutable collections
- Test immutability assumptions

---

## Category 4: Resource/Performance Failures

### F4.1 Out of Memory During Parse

**Symptom:** Dart OutOfMemoryError during large file parse

**Root Causes:**
- Very large score (1000+ measures, complex chords)
- Memory leak in parser (unreleased references)
- Cascading error (error list grows unbounded)

**Detection:**
```dart
try {
  _doc = XmlDocument.parse(musicXmlString);
} catch (e) {
  if (e is OutOfMemoryError) {
    // Memory exhausted
  }
}
```

**Recovery:**
1. Implement streaming parser for large files
2. Parse in chunks (per-part or per-section)
3. Limit maximum file size (configurable)
4. Provide progress feedback

**Severity:** CRITICAL (blocks operation)
**User Impact:** Large scores cannot be imported

**Prevention:**
- Profile memory usage with representative files
- Set size limits with clear user feedback
- Use streaming XML parser for very large documents
- Implement pagination/incremental loading in UI

---

### F4.2 Parse Timeout

**Symptom:** Parser runs indefinitely on specific input

**Root Causes:**
- Infinite loop in name resolution (circular references)
- Exponential regex in ID matching
- Recursive XML structure

**Detection:**
- Implement timeout wrapper around parse()

**Recovery:**
1. Add explicit timeout (e.g., 30 seconds)
2. Return partial result with error
3. Ask user to split file

**Prevention:**
- Use iterative (not recursive) parsing
- Avoid regex on unbounded input
- Add iteration limits to all loops

---

## Category 5: Integration Failures

### F5.1 Module B Linkage Failure

**Symptom:** Score created but cannot link to database record

**Root Causes:**
- sourceId format mismatch
- Checksum validation fails
- Timestamp format incompatible

**Detection:**
```dart
if (!_validateChecksum(score)) {
  // Checksum mismatch
}
```

**Recovery:**
1. Recalculate checksum
2. Offer direct linkage by ID
3. Manual record matching in UI

**Severity:** ERROR (integration issue)
**User Impact:** Cannot track score provenance

**Prevention:**
- Define checksum algorithm clearly
- Validate format compatibility
- Test Module B integration thoroughly

---

### F5.2 Module F Rendering Failure

**Symptom:** Score parses successfully but Module F cannot render

**Root Causes:**
- Score JSON structure incomplete for rendering
- Unsupported notation in renderer
- Metadata missing required fields

**Detection:**
- Requires Module F validation (out of scope)

**Recovery:**
1. Provide diagnostic info on missing fields
2. Suggest which fields are required for rendering
3. Allow partial rendering

**Prevention:**
- Define rendering requirements explicitly
- Test parser output against renderer
- Document unsupported notations

---

## Mitigation Strategies

### Strategy 1: Defensive Programming

All external input treated as untrusted:
- Validate before processing
- Use defaults for missing fields
- Check ranges/formats explicitly
- Log all violations

### Strategy 2: Graceful Degradation

Parser never crashes; always returns usable result:
- Collect errors without halting
- Preserve partial work
- Provide recovery hints
- Allow user to override validation

### Strategy 3: Observability

All failures logged with full context:
- Error category and code
- Input location (line, element path)
- Affected element
- Suggested recovery

### Strategy 4: Testing

Comprehensive failure case coverage:
- Fuzzing with malformed input
- Stress testing with large files
- Boundary condition testing
- Integration testing with other modules

---

## Severity Scale

| Level | Definition | User Action |
|-------|-----------|-------------|
| CRITICAL | Operation cannot proceed; data loss possible | Stop, fix issue, retry |
| ERROR | Operation blocked; manual intervention needed | Correct input or settings, retry |
| WARNING | Operation proceeds with caution; data may be incomplete | Review and confirm, may require override |
| INFO | Informational; no action needed | Log and monitor |

---

## Test Cases for Failure Modes

```dart
// F1.1: Malformed XML
test('Malformed XML returns error', () {
  final invalidXml = '<score-partwise><broken>';
  final result = parser.parse(invalidXml);
  expect(result.score, isNull);
  expect(result.errors.any((e) => e.message.contains('parse')), isTrue);
});

// F2.1: Duration mismatch
test('Measure duration mismatch detected', () {
  final score = Score(/* incomplete measure */);
  final report = validator.validate(score);
  expect(report.errors.any((e) => e.category == 'MeasureDurationMismatch'), isTrue);
});

// F2.2: Pitch out of range
test('Pitch out of instrument range detected', () {
  final note = NoteElement(pitch: Pitch(step: 'C', octave: 0), /* violin */);
  final report = validator.validate(scoreWithNote);
  expect(report.errors.any((e) => e.category == 'PitchRangeViolation'), isTrue);
});
```

---

**Last Updated:** 2026-03-21
**Status:** Active
**Review Frequency:** Quarterly
