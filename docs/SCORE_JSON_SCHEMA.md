# Score JSON Schema - SmartScore Internal Format

## Overview
The Score JSON schema defines the internal representation of music notation within SmartScore. All modules (B, E, F, C) share this schema. Produced by Module E (OMR/conversion), consumed by Module F (rendering) and Module C (comparison).

## Root Schema

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "string, 1–256 characters",
  "composer": "string, 0–256 characters, may be empty",
  "parts": [Part, ...],
  "metadata": ScoreMetadata
}
```

### Score Properties
- **id** (UUID): Unique identifier, matches ScoreEntry.id from Module B
- **title** (string): Human-readable score name
- **composer** (string): Composer name (empty if unknown)
- **parts** (array): List of musical parts (1+ required)
- **metadata** (object): Score-level metadata

---

## Part Schema

```json
{
  "id": "string, uuid-like",
  "name": "string, e.g., 'Violin', 'Piano', 'Flute'",
  "instrumentType": "enum (see below)",
  "staveCount": 1,
  "measures": [Measure, ...]
}
```

### Instrument Types
```
"violin" | "viola" | "cello" | "bass" |        // Strings
"flute" | "oboe" | "clarinet" | "bassoon" |   // Woodwinds
"horn" | "trumpet" | "trombone" | "tuba" |    // Brass
"piano" | "organ" | "harp" |                  // Keyboards
"percussion" | "timpani" | "xylophone" |      // Percussion
"voice" | "soprano" | "alto" | "tenor" |      // Voice
"guitar" | "banjo" | "ukulele" |              // Plucked
"generic"                                      // Unknown
```

### Part Properties
- **id** (string): Unique within score (e.g., "P1", "P2")
- **name** (string): Display name (e.g., "Violin I")
- **instrumentType** (enum): Type of instrument
- **staveCount** (int): Number of staves (1–2 typical, 3+ possible)
- **measures** (array): All measures in this part (1+ required)

---

## Measure Schema

```json
{
  "number": 0,
  "elements": [Element, ...],
  "timeSignature": "4/4",
  "keySignature": {
    "step": "C",
    "tonality": "major",
    "alterations": 0
  },
  "tempo": 120,
  "rehearsalMark": "A",
  "repeatStart": false,
  "repeatEnd": false,
  "clefs": [Clef, ...]
}
```

### Measure Properties
- **number** (int): 0-indexed, absolute position in score
- **elements** (array): Notes, rests, directions (0+ allowed)
- **timeSignature** (string): e.g., "4/4", "3/4", "6/8", "5/4"
- **keySignature** (object): Current key (inherited from previous if omitted)
  - **step** (string): C, D, E, F, G, A, B
  - **tonality** (string): "major" or "minor"
  - **alterations** (int): -7 to +7 (sharps/flats count)
- **tempo** (int): BPM (optional, 60–240 typical)
- **rehearsalMark** (string): Letter or number (A–Z, 1+)
- **repeatStart** (bool): Has repeat start symbol (|:)
- **repeatEnd** (bool): Has repeat end symbol (:|)
- **clefs** (array): Clef changes in measure (optional)

---

## Element Schema

```json
{
  "type": "note",
  "pitch": {
    "step": "C",
    "octave": 4,
    "alter": 0
  },
  "duration": 4,
  "noteType": "quarter",
  "voice": 0,
  "staff": 0,
  "dots": 0,
  "isChordMember": false,
  "articulations": ["staccato"],
  "tie": {
    "type": "start"
  },
  "slur": {
    "type": "start"
  },
  "dynamic": "mf",
  "text": "ord."
}
```

### Element Types
```
"note"      → Sounding pitch (on staff)
"rest"      → Silence (measured duration)
"direction" → Text, dynamics, other directions (non-sounding)
```

### Note Element
- **type** (string): "note"
- **pitch** (object): Absolute pitch
  - **step** (string): A–G
  - **octave** (int): 0–8 (middle C = octave 4)
  - **alter** (int): -2 to +2 (double-flat to double-sharp)
- **duration** (int): Fractional duration (256ths of whole note)
  - 256 = whole, 128 = half, 64 = quarter, 32 = eighth, 16 = sixteenth
- **noteType** (string): "whole", "half", "quarter", "eighth", "sixteenth", "thirty-second"
- **voice** (int): 0-indexed voice number (0–3 typical)
- **staff** (int): 0-indexed staff within part
- **dots** (int): 0–3 (augmentation dots, each adds 1.5× to duration)
- **isChordMember** (bool): true if this note is part of chord (shares same start position)
- **articulations** (array): ["staccato", "accent", "tenuto", "marcato"]
- **tie** (object, optional): Tie info
  - **type**: "start" | "continue" | "stop"
- **slur** (object, optional): Slur/legato info
  - **type**: "start" | "continue" | "stop"
  - **slurNumber**: 0–2 (for nested slurs)
- **dynamic** (string): "ppp", "pp", "p", "mp", "mf", "f", "ff", "fff"
- **text** (string): Additional text (e.g., "pizz.", "ord.", "arco")

### Rest Element
```json
{
  "type": "rest",
  "duration": 64,
  "noteType": "quarter",
  "voice": 0,
  "staff": 0,
  "dots": 0
}
```

- Same as note but without pitch, isChordMember, articulations, tie, slur, dynamic

### Direction Element
```json
{
  "type": "direction",
  "text": "molto ritardando",
  "placement": "above"
}
```

- **type** (string): "direction"
- **text** (string): Instruction text
- **placement** (string): "above" | "below" (staff placement)

---

## ScoreMetadata Schema

```json
{
  "format": "1.0",
  "source": "omr",
  "sourceId": "550e8400-e29b-41d4-a716-446655440001",
  "ocrConfidence": 0.92,
  "edited": false,
  "editCount": 0,
  "createdAt": "2026-03-21T15:30:00Z",
  "updatedAt": "2026-03-21T15:30:00Z",
  "checksumSHA256": "abc123def456..."
}
```

### Metadata Properties
- **format** (string): Schema version (e.g., "1.0")
- **source** (string): Origin (e.g., "omr", "musicxml", "manual")
- **sourceId** (string): Reference to Module B ScoreEntry.id
- **ocrConfidence** (float): 0.0–1.0 (average confidence if from OCR)
- **edited** (bool): true if user has made edits
- **editCount** (int): Number of edits since import
- **createdAt** (ISO 8601): When this JSON was created
- **updatedAt** (ISO 8601): Last modification time
- **checksumSHA256** (string): Hash for integrity verification

---

## JSON Schema (Draft 7)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "SmartScore Internal Score Format",
  "type": "object",
  "required": ["id", "title", "parts", "metadata"],
  "properties": {
    "id": {
      "type": "string",
      "pattern": "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
    },
    "title": {
      "type": "string",
      "minLength": 1,
      "maxLength": 256
    },
    "composer": {
      "type": "string",
      "maxLength": 256
    },
    "parts": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["id", "name", "instrumentType", "staveCount", "measures"],
        "properties": {
          "id": { "type": "string" },
          "name": { "type": "string" },
          "instrumentType": {
            "type": "string",
            "enum": ["violin", "viola", "cello", "bass", "flute", "oboe", "clarinet", "bassoon", "horn", "trumpet", "trombone", "tuba", "piano", "organ", "harp", "percussion", "timpani", "xylophone", "voice", "soprano", "alto", "tenor", "bass", "guitar", "banjo", "ukulele", "generic"]
          },
          "staveCount": { "type": "integer", "minimum": 1, "maximum": 3 },
          "measures": {
            "type": "array",
            "minItems": 1,
            "items": { "$ref": "#/definitions/measure" }
          }
        }
      }
    },
    "metadata": {
      "type": "object",
      "required": ["format", "source"],
      "properties": {
        "format": { "type": "string" },
        "source": { "type": "string" },
        "sourceId": { "type": "string" },
        "ocrConfidence": { "type": "number", "minimum": 0, "maximum": 1 },
        "edited": { "type": "boolean" },
        "editCount": { "type": "integer", "minimum": 0 },
        "createdAt": { "type": "string", "format": "date-time" },
        "updatedAt": { "type": "string", "format": "date-time" },
        "checksumSHA256": { "type": "string" }
      }
    }
  },
  "definitions": {
    "measure": {
      "type": "object",
      "required": ["number", "elements"],
      "properties": {
        "number": { "type": "integer", "minimum": 0 },
        "elements": {
          "type": "array",
          "items": { "$ref": "#/definitions/element" }
        },
        "timeSignature": { "type": "string" },
        "keySignature": {
          "type": "object",
          "properties": {
            "step": { "type": "string", "enum": ["C", "D", "E", "F", "G", "A", "B"] },
            "tonality": { "type": "string", "enum": ["major", "minor"] },
            "alterations": { "type": "integer", "minimum": -7, "maximum": 7 }
          }
        },
        "tempo": { "type": "integer", "minimum": 30, "maximum": 300 },
        "rehearsalMark": { "type": "string" },
        "repeatStart": { "type": "boolean" },
        "repeatEnd": { "type": "boolean" }
      }
    },
    "element": {
      "oneOf": [
        { "$ref": "#/definitions/noteElement" },
        { "$ref": "#/definitions/restElement" },
        { "$ref": "#/definitions/directionElement" }
      ]
    },
    "noteElement": {
      "type": "object",
      "required": ["type", "pitch", "duration", "noteType", "voice", "staff"],
      "properties": {
        "type": { "const": "note" },
        "pitch": {
          "type": "object",
          "required": ["step", "octave"],
          "properties": {
            "step": { "type": "string", "enum": ["A", "B", "C", "D", "E", "F", "G"] },
            "octave": { "type": "integer", "minimum": 0, "maximum": 8 },
            "alter": { "type": "integer", "minimum": -2, "maximum": 2 }
          }
        },
        "duration": { "type": "integer", "minimum": 1 },
        "noteType": { "type": "string", "enum": ["whole", "half", "quarter", "eighth", "sixteenth", "thirty-second"] },
        "voice": { "type": "integer", "minimum": 0, "maximum": 3 },
        "staff": { "type": "integer", "minimum": 0 },
        "dots": { "type": "integer", "minimum": 0, "maximum": 3 },
        "isChordMember": { "type": "boolean" },
        "articulations": { "type": "array", "items": { "type": "string" } },
        "dynamic": { "type": "string" },
        "text": { "type": "string" }
      }
    },
    "restElement": {
      "type": "object",
      "required": ["type", "duration", "noteType", "voice", "staff"],
      "properties": {
        "type": { "const": "rest" },
        "duration": { "type": "integer", "minimum": 1 },
        "noteType": { "type": "string" },
        "voice": { "type": "integer" },
        "staff": { "type": "integer" },
        "dots": { "type": "integer", "minimum": 0, "maximum": 3 }
      }
    },
    "directionElement": {
      "type": "object",
      "required": ["type", "text"],
      "properties": {
        "type": { "const": "direction" },
        "text": { "type": "string" },
        "placement": { "type": "string", "enum": ["above", "below"] }
      }
    }
  }
}
```

---

## Example: "Twinkle Twinkle Little Star" (4 measures)

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Twinkle Twinkle Little Star",
  "composer": "Traditional",
  "parts": [
    {
      "id": "P1",
      "name": "Melody",
      "instrumentType": "voice",
      "staveCount": 1,
      "measures": [
        {
          "number": 0,
          "elements": [
            { "type": "note", "pitch": { "step": "C", "octave": 4, "alter": 0 }, "duration": 64, "noteType": "quarter", "voice": 0, "staff": 0, "dots": 0, "isChordMember": false },
            { "type": "note", "pitch": { "step": "C", "octave": 4, "alter": 0 }, "duration": 64, "noteType": "quarter", "voice": 0, "staff": 0, "dots": 0, "isChordMember": false },
            { "type": "note", "pitch": { "step": "G", "octave": 4, "alter": 0 }, "duration": 64, "noteType": "quarter", "voice": 0, "staff": 0, "dots": 0, "isChordMember": false },
            { "type": "note", "pitch": { "step": "A", "octave": 4, "alter": 0 }, "duration": 64, "noteType": "quarter", "voice": 0, "staff": 0, "dots": 0, "isChordMember": false }
          ],
          "timeSignature": "4/4",
          "keySignature": { "step": "C", "tonality": "major", "alterations": 0 },
          "tempo": 120
        },
        {
          "number": 1,
          "elements": [
            { "type": "note", "pitch": { "step": "B", "octave": 3, "alter": 0 }, "duration": 64, "noteType": "quarter", "voice": 0, "staff": 0, "dots": 0, "isChordMember": false },
            { "type": "note", "pitch": { "step": "B", "octave": 3, "alter": 0 }, "duration": 64, "noteType": "quarter", "voice": 0, "staff": 0, "dots": 0, "isChordMember": false },
            { "type": "note", "pitch": { "step": "B", "octave": 3, "alter": 0 }, "duration": 64, "noteType": "quarter", "voice": 0, "staff": 0, "dots": 0, "isChordMember": false },
            { "type": "rest", "duration": 64, "noteType": "quarter", "voice": 0, "staff": 0, "dots": 0 }
          ]
        },
        {
          "number": 2,
          "elements": [
            { "type": "note", "pitch": { "step": "A", "octave": 4, "alter": 0 }, "duration": 64, "noteType": "quarter", "voice": 0, "staff": 0, "dots": 0, "isChordMember": false },
            { "type": "note", "pitch": { "step": "A", "octave": 4, "alter": 0 }, "duration": 64, "noteType": "quarter", "voice": 0, "staff": 0, "dots": 0, "isChordMember": false },
            { "type": "note", "pitch": { "step": "A", "octave": 4, "alter": 0 }, "duration": 64, "noteType": "quarter", "voice": 0, "staff": 0, "dots": 0, "isChordMember": false },
            { "type": "rest", "duration": 64, "noteType": "quarter", "voice": 0, "staff": 0, "dots": 0 }
          ]
        },
        {
          "number": 3,
          "elements": [
            { "type": "note", "pitch": { "step": "G", "octave": 4, "alter": 0 }, "duration": 128, "noteType": "half", "voice": 0, "staff": 0, "dots": 0, "isChordMember": false },
            { "type": "rest", "duration": 128, "noteType": "half", "voice": 0, "staff": 0, "dots": 0 }
          ]
        }
      ]
    }
  ],
  "metadata": {
    "format": "1.0",
    "source": "omr",
    "sourceId": "550e8400-e29b-41d4-a716-446655440001",
    "ocrConfidence": 0.95,
    "edited": false,
    "editCount": 0,
    "createdAt": "2026-03-21T15:30:00Z",
    "updatedAt": "2026-03-21T15:30:00Z",
    "checksumSHA256": "abc123def456789..."
  }
}
```

---

## Validation Rules

1. **UUID format**: All ID fields must be valid UUID v4
2. **Pitch range**: Octave 0–8, step A–G, alter ±2
3. **Duration**: Integer 1+ (units: 256ths of whole note)
4. **Measure number**: Unique per part, start at 0
5. **Time signature**: Valid format (e.g., "4/4", "6/8")
6. **Key signature**: Valid step + tonality combination
7. **Tempo**: Integer 30–300 BPM if present
8. **Chord members**: All notes in chord share same start position and duration

---

## Compatibility Notes

- **Version 1.0** released with Stage 1
- **Backward compatibility**: Future versions will maintain schema versioning
- **Extensions**: New fields added as optional to preserve compatibility
