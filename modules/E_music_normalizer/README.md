# SmartScore Music Normalizer (E_music_normalizer)

Module E of the SmartScore system provides core data models and parsing/validation for musical notation in Score JSON format.

## Overview

This module implements:

1. **Score JSON Data Models** (`lib/score_json.dart`) - Immutable, serializable Dart classes representing musical structures
2. **MusicXML Parser** (`lib/musicxml_parser.dart`) - Converts MusicXML score-partwise format to Score JSON
3. **Score Validator** (`lib/score_validator.dart`) - Validates Score JSON structure, pitch ranges, and measure consistency

## Features

### Score JSON Models

- **Score**: Root container with parts, metadata, title, composer
- **Part**: Collection of measures with instrument type and staff configuration
- **Measure**: Container for notes, rests, directions with time/key signatures, tempo marks
- **Element**: Polymorphic base for Note, Rest, Direction
- **Pitch**: Musical pitch with MIDI number and frequency computation
- **Metadata**: Score-level information (format, source, checksum, OCR confidence)

All classes are immutable with `final` fields and provide:
- `fromJson()` / `toJson()` for serialization
- `copyWith()` for controlled state mutation
- Comprehensive validation

### MusicXML Parser

Converts score-partwise MusicXML to Score JSON:

```dart
final parser = MusicXmlParser();
final result = parser.parse(musicXmlString);
if (result.isSuccess) {
  final score = result.score;
  print('Parsed ${score.parts.length} parts');
}
```

**Supported Elements:**
- Notes with pitch, duration, articulations, dynamics
- Rests with proper duration
- Chords and tied notes
- Slurs and other markings
- Key signatures, time signatures, clefs
- Tempo marks and rehearsal marks
- Repeats (start/end)
- Directions and text annotations

**Result Object:**
```dart
class ParseResult {
  Score? score;           // null if errors occur
  List<ParseError> errors;
  List<ParseWarning> warnings;
  int parseTimeMs;        // Milliseconds to parse
}
```

### Score Validator

Validates Score JSON for structural and musical consistency:

```dart
final validator = ScoreValidator();
final report = validator.validate(score);

if (report.isValid) {
  print('Score is valid: ${report.score}');
} else {
  for (var error in report.errors) {
    print(error);
  }
}
```

**Validation Checks:**
- Measure duration matches time signature
- Pitch ranges per instrument type
- Chord consistency (matching durations)
- Time signature continuity
- UUID format validation
- String length constraints

**Validation Report:**
```dart
class ValidationReport {
  List<ValidationIssue> errors;      // Critical issues
  List<ValidationIssue> warnings;    // Non-critical issues
  double score;                      // 0.0-1.0 quality score
}
```

## Pitch and Frequency Computation

The `Pitch` class includes real mathematical computations:

### MIDI Number
Middle C (C4) = MIDI 60

```dart
final c4 = Pitch(step: 'C', octave: 4);
print(c4.midiNumber);  // 60

final a4 = Pitch(step: 'A', octave: 4);
print(a4.midiNumber);  // 69

final cs4 = Pitch(step: 'C', octave: 4, alter: 1);
print(cs4.midiNumber);  // 61 (C#)
```

### Frequency (Hz)
A4 = 440 Hz (ISO 16, standard tuning)

```dart
final a4 = Pitch(step: 'A', octave: 4);
print(a4.frequency);  // 440.0

final c4 = Pitch(step: 'C', octave: 4);
print(c4.frequency);  // ~261.63

// Frequency doubles every octave
final c5 = Pitch(step: 'C', octave: 5);
print(c5.frequency);  // ~523.25
```

Formula: `f = 440 * 2^((MIDI - 69) / 12)`

## Instrument Type Handling

`InstrumentType` includes extensive name variation support:

```dart
// Factory constructor for common variations
final violin = InstrumentType.fromName('Violin I');
final cello = InstrumentType.fromName('Cello');
final horn = InstrumentType.fromName('French Horn');
final soprano = InstrumentType.fromName('Soprano');

// All case-insensitive, handles whitespace
final generic = InstrumentType.fromName('Unknown Instrument');
```

**Supported Types:**
- Strings: Violin, Viola, Cello, Bass
- Woodwinds: Flute, Oboe, Clarinet, Bassoon
- Brass: Horn, Trumpet, Trombone, Tuba
- Keyboards: Piano, Organ, Harp
- Percussion: Timpani, Xylophone, Percussion
- Voice: Soprano, Alto, Tenor, Bass, Voice
- Plucked: Guitar, Banjo, Ukulele
- Generic: Unknown instruments

## Testing

Comprehensive test suites included:

### `test/score_json_test.dart`
- Pitch MIDI/frequency calculations (C4=60, A4=69, A4=440Hz)
- InstrumentType name variations
- Round-trip JSON serialization
- Immutability with copyWith
- Score validation

### `test/musicxml_parser_test.dart`
- Complete "Twinkle Twinkle Little Star" example
- Measure parsing, note/rest handling
- Key/time signature parsing
- Tempo, clef, repeat marks
- Error handling (malformed XML, empty parts)
- Parse time measurement
- Multiple parts, accidentals, dynamics

### `test/score_validator_test.dart`
- Valid score passes
- Measure duration mismatches flagged
- Pitch ranges (absolute and typical)
- Chord consistency checks
- Dotted note duration calculation
- Multiple part validation

## Example: Parse and Validate

```dart
import 'lib/score_json.dart';
import 'lib/musicxml_parser.dart';
import 'lib/score_validator.dart';

void main() {
  final musicXml = '''<?xml version="1.0"?>
  <score-partwise>
    <part-list>
      <score-part id="P1"><part-name>Violin</part-name></score-part>
    </part-list>
    <part id="P1">
      <measure number="1">
        <attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
        <note>
          <pitch><step>C</step><octave>4</octave></pitch>
          <duration>4</duration>
          <type>quarter</type>
          <voice>1</voice>
          <staff>1</staff>
        </note>
      </measure>
    </part>
  </score-partwise>''';

  // Parse
  final parser = MusicXmlParser();
  final parseResult = parser.parse(musicXml);

  if (!parseResult.isSuccess) {
    print('Parse errors: ${parseResult.errors}');
    return;
  }

  final score = parseResult.score!;
  print('Parsed: ${score.title} by ${score.composer}');
  print('Parts: ${score.parts.length}');

  // Validate
  final validator = ScoreValidator();
  final report = validator.validate(score);

  print('Valid: ${report.isValid}');
  print('Quality score: ${report.score}');
  if (report.warnings.isNotEmpty) {
    print('Warnings: ${report.warnings}');
  }
}
```

## Implementation Notes

- All models use `const` constructors for immutability
- No nullable fields where not semantically required
- JSON serialization handles partial/nested objects gracefully
- Parser logs unknown XML elements as warnings (no silent skipping)
- Validator returns both errors (critical) and warnings (informational)
- Pitch calculations use real mathematics, not approximations
- Time measurement in parse results enables performance monitoring

## Dependencies

- `xml: ^6.0.0` - XML parsing (pub.dev)
- `crypto: ^3.0.0` - SHA256 checksums (pub.dev)
- `test: ^1.24.0` - Unit testing (dev dependency)

## Integration Points

- **Module B (Database)**: Consumes ScoreEntry.id in metadata.sourceId
- **Module F (Rendering)**: Consumes Score JSON for notation display
- **Module C (Comparison)**: Compares Score JSON structures for diff detection

## Version

Schema version: 1.0 (matches SCORE_JSON_SCHEMA.md)
