# Module B: Score Input & Library

SmartScore v2 Module B implements comprehensive score import, version control, and library management.

## Overview

This module manages:
- **Score imports** from PDF, image, and MusicXML sources
- **Version tracking** of multiple representations (original, restored, OMR output, user edits)
- **Library persistence** using in-memory storage (SQLite-ready)
- **Validation** of all input formats with detailed error reporting

## Architecture

### Core Types

#### ScoreEntry
Represents a single score in the library with complete metadata and version history.

```dart
final entry = ScoreEntry(
  title: 'Symphony No. 5',
  composer: 'Beethoven',
  sourceType: SourceType.musicxml,
);
```

**Fields:**
- `id`: UUID v4 identifier (auto-generated)
- `title`: 1-256 character string
- `composer`: Optional 0-256 character string
- `sourceType`: How the score was originally imported
- `versions`: Map of version types to VersionInfo objects
- `createdAt`, `updatedAt`: ISO 8601 UTC timestamps

#### VersionType Enum
Represents the different processing stages of a score:
- `originalImage`: First imported image (PNG file path)
- `restoredImage`: Post-processing result (PNG file path)
- `omrMusicxml`: OMR/OCR output (MusicXML XML)
- `omrScoreJson`: OMR Score JSON output
- `userEditedScoreJson`: User-edited Score JSON

#### VersionInfo
Metadata about a specific version.

```dart
final version = VersionInfo(
  filePath: '/scores/uuid/original_image_1234567890.png',
  createdAt: DateTime.now(),
  sizeBytes: 102400,
  metadata: {
    'ocrConfidence': 0.95,
    'editCount': 3,
  },
);
```

#### Result<T, E>
Functional error handling - represents either success or failure.

```dart
final result = await library.importImage(bytes, 'score.png');

if (result.isSuccess) {
  final entry = result.valueOrNull;
  print('Imported: ${entry.title}');
} else {
  final error = result.errorOrNull;
  print('Import failed: $error');
}
```

### ScoreLibrary API

#### Import Operations

**PDF Import:**
```dart
final result = await library.importPdf('/path/to/score.pdf');
result.onSuccess((entry) => print('PDF imported: ${entry.id}'));
result.onFailure((error) => print('Error: $error'));
```

**Image Import:**
```dart
final bytes = await File('photo.png').readAsBytes();
final result = await library.importImage(bytes, 'photo.png');
```

**MusicXML Import:**
```dart
final xml = '''<?xml version="1.0"?>
<score-partwise version="3.1">...</score-partwise>''';
final result = await library.importMusicXml(xml, fileName: 'score.musicxml');
```

#### Query Operations

**Get All Scores:**
```dart
final scores = await library.getLibrary(
  searchQuery: 'Beethoven',
  sort: SortOrder.titleAsc,
);
```

**Get Single Score:**
```dart
final entry = await library.getScore(scoreId);
```

**Get Version:**
```dart
final version = library.getVersion(scoreId, VersionType.originalImage);
```

#### Modification Operations

**Update Score:**
```dart
final updated = entry.copyWith(
  title: 'New Title',
  composer: 'New Composer',
);
await library.updateScore(scoreId, updated);
```

**Add Version:**
```dart
await library.addVersion(
  scoreId,
  VersionType.restoredImage,
  '/path/to/restored.png',
  fileSize,
);
```

**Delete Score:**
```dart
final deleted = await library.deleteScore(scoreId);
```

## Input Validation

All imports are validated against strict specifications.

### PDF Validation
- Must be PDF 1.4+
- Must not be password-protected
- Must contain at least 1 page
- Extracted images must be 200×200 px minimum
- Extracted images must be ≤50 MB

### Image Validation
- Must be JPEG (baseline or progressive) or PNG (8/16-bit RGB/RGBA)
- Dimensions: 200×200 px minimum, 4800×3600 px maximum
- File size: ≤50 MB
- EXIF metadata preserved if present

### MusicXML Validation
- Must be MusicXML 3.0 or 3.1
- UTF-8 encoding required
- Must conform to official XSD schema
- Must have at least 1 part with 1 measure and valid time signature

## Error Handling

All expected failures return Result<T, ImportError> instead of throwing.

```dart
enum ImportError {
  pdfCorrupted,
  pdfPasswordProtected,
  pdfEmpty,
  imageInvalidFormat,
  imageDimensionsTooSmall,
  imageDimensionsTooLarge,
  xmlMalformed,
  xmlSchemaInvalid,
  storageWriteFailed,
  // ... and more
}
```

## Logging

Module uses structured logging with 4 levels:

```dart
final logger = ModuleLogger.instance;

logger.info('ScoreLibrary', 'Score imported', data: {
  'scoreId': entry.id,
  'title': entry.title,
});

logger.debug('ImportValidators', 'Image validated', data: {
  'width': 800,
  'height': 600,
});

// Retrieve logs
final logs = logger.getBuffer();
final recent = logger.getRecent(limit: 50);
```

## Storage Layout

```
{basePath}/
  versions/
    {scoreId}/
      original_image_1234567890.png
      omr_musicxml_1234567890.xml
      omr_score_json_1234567890.json
      user_edited_score_json_1234567890.json
```

## Testing

Comprehensive test suite with 60+ tests:

```bash
# Run all tests
dart test

# Run specific test file
dart test test/score_entry_test.dart

# Run with coverage
dart pub add dev:coverage
dart test --coverage=coverage
```

Test coverage includes:
- ScoreEntry serialization and validation
- Library CRUD operations
- Import workflows (happy path and error cases)
- Concurrent operations
- Validator edge cases (dimensions, file sizes, formats)
- Result type behavior

## Performance

- Library queries: O(n) where n = number of scores
- Single score lookups: O(1)
- Validation is synchronous
- Imports run asynchronously
- Concurrent imports supported

## Dependencies

- uuid: UUID v4 generation
- crypto: SHA256 checksums
- xml: XML parsing and validation
- intl: Date/time formatting

## Future Enhancements

1. Replace in-memory Map with actual SQLite database
2. Add checksum verification for version integrity
3. Implement batch import optimization
4. Add export to PDF and MusicXML
5. Support for compressed MusicXML .zip files
6. Image restoration integration (Module D)
7. OMR processing integration (Module E)

## API Contract Compliance

This implementation fully satisfies the contract defined in CONTRACT.md:
- All specified input types supported
- All output specifications met
- All error codes implemented
- All storage guarantees honored
- Complete version tracking
- Atomic transactions (via Map-based implementation)
