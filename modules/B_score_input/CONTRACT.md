# Module B: Score Input & Library - Contract

## Module Purpose
Manages score import from multiple source formats (PDF, images, MusicXML), version control of internal representations, and library persistence. Single source of truth for all score data.

## Input Specifications

### PDF Input
- **Format**: PDF 1.4+ compliant
- **Image extraction**: Each page converted to PNG at 150 DPI minimum, max 300 DPI
- **Page range**: 1 to 500 pages inclusive
- **Image constraints**: Result after extraction must be 200×200 px minimum, 50MB per file maximum
- **Acceptance**: Valid PDF that is not password-protected, contains at least 1 page, has valid structure

### Camera/Image Input
- **Formats**: JPEG (baseline, progressive), PNG (8-bit or 16-bit RGB/RGBA)
- **Dimensions**: 200×200 px (minimum) to 4800×3600 px (maximum)
- **File size**: ≤50 MB
- **Color space**: RGB or RGBA (sRGB assumed)
- **Metadata**: EXIF preserved if present, not required

### MusicXML Input
- **Format**: MusicXML 3.0 or 3.1 (compressed .musicxml.zip or uncompressed .musicxml)
- **Encoding**: UTF-8
- **Schema compliance**: Must be valid against official MusicXML XSD
- **Content**: At minimum: 1 part, 1 measure with valid timeSignature element

### Internal Score JSON
- **Source**: Module E output or user edits via Module C
- **Format**: Conforms to SCORE_JSON_SCHEMA.md
- **Validation**: All required fields present, all enums match defined values

## Output Specifications

### ScoreEntry (Metadata)
```
id: UUID v4 (36 chars, lowercase hex)
title: string, 1–256 characters, non-empty
composer: string, 0–256 characters, may be empty
sourceType: enum [pdf, image, musicxml, manual_json]
versions: Map<VersionType, Version>
createdAt: ISO 8601 UTC timestamp
updatedAt: ISO 8601 UTC timestamp
```

### Version Type Enum
```
original_image       → First imported image (PNG file path)
restored_image       → Post-processing result (PNG file path)
omr_musicxml         → MusicXML from OCR/OMR (XML string in storage)
omr_score_json       → Score JSON from OMR (JSON string in storage)
user_edited_score_json → Last user edit (JSON string in storage)
```

### Version Object
```
type: VersionType
content: string (file path for images, full content for XML/JSON)
createdAt: ISO 8601 UTC timestamp
isActive: boolean (only one per ScoreEntry is active)
metadata: {
  ocrConfidence?: float [0.0–1.0],
  editedBy?: string,
  editCount?: int (≥0),
  checksumSHA256?: string
}
```

### Storage Layer
- **Metadata DB**: SQLite 3.39+, single file `scores.db`
- **Binary storage**: Filesystem at `{basePath}/versions/`
- **File naming**: `{scoreId}/{versionType}_{timestamp}.{ext}`
- **Transaction**: All write operations atomic (begin → write → commit or rollback)

## API Contract

### importPdf(filePath: string) → Result<ScoreEntry, ImportError>
**Behavior:**
- Read PDF from given path (must exist)
- Extract all pages as PNG images (150–300 DPI)
- Create ScoreEntry with `sourceType: pdf`
- Store `original_image` version for each page (or as single composite)
- Return ScoreEntry if ≥1 page extracted, else ImportError

**Success Return**: `{ ok: true, value: ScoreEntry }`
**Failure Return**: `{ ok: false, error: { code: ImportError, message: string, details: {} } }`

**Error Codes**:
- `PDF_CORRUPTED`: File not readable as PDF
- `PDF_PASSWORD_PROTECTED`: PDF requires password
- `PDF_EMPTY`: 0 pages
- `PDF_EXTRACTION_FAILED`: Image extraction failed
- `STORAGE_WRITE_FAILED`: Cannot write to disk

### importImage(bytes: Uint8Array) → Result<ScoreEntry, ImportError>
**Behavior:**
- Validate image format (JPEG/PNG magic bytes)
- Check dimensions: 200×200 ≤ W×H ≤ 4800×3600
- Check file size: ≤50 MB
- Create ScoreEntry with `sourceType: image`
- Store bytes as `original_image` version
- Return ScoreEntry

**Error Codes**:
- `IMAGE_INVALID_FORMAT`: Not JPEG or PNG
- `IMAGE_DIMENSIONS_TOO_SMALL`: W < 200 or H < 200
- `IMAGE_DIMENSIONS_TOO_LARGE`: W > 4800 or H > 3600
- `IMAGE_FILE_TOO_LARGE`: > 50 MB
- `STORAGE_WRITE_FAILED`: Disk I/O error

### importMusicXml(content: string) → Result<ScoreEntry, ParseError>
**Behavior:**
- Parse XML (handle both compressed .zip and plain .xml)
- Validate against MusicXML 3.0/3.1 schema
- Extract title, composer from work-title, composer elements (optional)
- Generate Score JSON via internal parser (details in Module E)
- Store both `omr_musicxml` and `omr_score_json` versions
- Create ScoreEntry with `sourceType: musicxml`

**Error Codes**:
- `XML_MALFORMED`: Parse error
- `XML_SCHEMA_INVALID`: Does not conform to MusicXML spec
- `XML_UNSUPPORTED_VERSION`: Version ≠3.0/3.1
- `PARSE_CONTENT_EMPTY`: No parts/measures

### getLibrary() → List<ScoreEntry>
**Behavior:**
- Query all ScoreEntry records from SQLite
- Return sorted by `createdAt` descending (newest first)
- Include only metadata (not full version content)
- Empty list if no scores exist

**Contract**: O(n) where n = number of scores in library
**Return**: List (may be empty), always succeeds

### getScore(id: string) → ScoreEntry | null
**Behavior:**
- Query single ScoreEntry by UUID id
- Return full metadata + active version reference
- Return null if id not found

**Validation**: id must be valid UUID format, else return null
**Return**: ScoreEntry or null

### deleteScore(id: string) → bool
**Behavior:**
- Remove ScoreEntry from SQLite
- Delete all files in `versions/{id}/` directory
- Delete all version records in metadata
- Return true if deleted, false if not found

**Constraints**: Deletion is permanent, not reversible
**Return**: true if score existed and was deleted, false otherwise

### exportMusicXml(id: string) → string | null
**Behavior:**
- Load active `user_edited_score_json` or fallback to `omr_score_json`
- Convert internal Score JSON to MusicXML 3.1 XML string
- Return XML string

**Return**: Valid MusicXML string or null if score not found or no JSON version available
**Error**: Silently returns null on conversion error (logged separately)

## Storage Guarantees
- **Atomicity**: All version writes to DB are transactional
- **Durability**: All files flushed to disk before operation returns
- **Consistency**: Only one active version per type
- **Isolation**: Concurrent reads allowed, writes serialized

## Dependencies
- SQLite 3.39+ for metadata
- PNG/JPEG library for image validation
- XML parser (XML 1.0 compliant)
- File system with ≥1 GB free space recommended

## Version Management Rules
1. Only one version per VersionType can be active
2. New import creates new ScoreEntry (no deduplication at this layer)
3. User edits create new `user_edited_score_json` version
4. Restore operations create new `restored_image` version
5. All versions retain creation timestamp for audit trail
