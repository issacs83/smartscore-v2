# Implementation Notes

## Files Created

### Core Library Files (`lib/`)

1. **result.dart** - Functional error handling
   - Sealed `Result<T, E>` class with Success and Failure variants
   - Methods: `map()`, `flatMap()`, `mapError()`, `getOrElse()`, `onSuccess()`, `onFailure()`
   - ~60 lines
   - No dependencies

2. **import_error.dart** - Error type definitions
   - Enum with 16+ error codes for all failure modes
   - Maps to contract error codes (PDF_CORRUPTED, IMAGE_DIMENSIONS_TOO_SMALL, etc.)
   - ~20 lines
   - No dependencies

3. **logger.dart** - Structured logging system
   - ModuleLogger singleton with 4 log levels (debug, info, warn, error)
   - LogEntry class with timestamp, level, module, message, metadata
   - Rotating buffer of last 1000 entries for debug retrieval
   - ~120 lines
   - Depends on: intl

4. **score_entry.dart** - Core data model
   - `ScoreEntry` class with UUID, title, composer, sourceType, versions
   - `VersionType` enum (5 types with fileExtension property)
   - `SourceType` enum (4 source types)
   - `VersionInfo` class with filePath, createdAt, sizeBytes, metadata
   - UUID v4 validation, JSON serialization, copyWith pattern
   - ~250 lines
   - Depends on: uuid

5. **import_validators.dart** - Input validation
   - `validatePdfFile()` - checks magic bytes, password protection, page count
   - `validateImageBytes()` - validates JPEG/PNG format, dimensions, file size
   - `validateMusicXml()` - parses XML, validates schema, checks parts/measures
   - Dimension parsing for both PNG and JPEG formats
   - ~200 lines
   - Depends on: xml

6. **score_library.dart** - Main library class
   - `ScoreLibrary` class with in-memory Map-based store
   - Methods:
     - `initialize()` - creates directory structure
     - `importPdf()`, `importImage()`, `importMusicXml()` - import operations
     - `getLibrary()`, `getScore()` - read operations
     - `updateScore()`, `deleteScore()` - modify operations
     - `addVersion()`, `getVersion()` - version management
   - SortOrder enum with 6 sort modes
   - Placeholder Score JSON generation from MusicXML
   - ~350 lines
   - Depends on: result, import_error, import_validators, logger, score_entry, uuid, crypto

### Test Files (`test/`)

1. **score_entry_test.dart** - 15 tests
   - Creation with/without explicit UUID
   - Title and composer validation
   - Version addition and retrieval
   - JSON serialization round-trip
   - copyWith() functionality
   - Equality and hashCode
   - ~270 lines

2. **score_library_test.dart** - 25+ tests
   - Image import (success and failures)
   - PDF import validation
   - MusicXML import with schema validation
   - getLibrary() with search and sort
   - getScore() lookup
   - Delete operations
   - Update operations
   - Version management
   - Concurrent imports
   - Result type behavior
   - ~350 lines

3. **import_validators_test.dart** - 25+ tests
   - PDF validation (magic bytes, password protection, empty files)
   - PNG validation (dimensions, file size)
   - JPEG validation
   - MusicXML parsing (valid and invalid XML)
   - Edge cases (minimum/maximum dimensions)
   - All error codes exercised
   - ~350 lines

### Configuration Files

1. **pubspec.yaml** - Project manifest
   - Name: smartscore_b_score_input
   - Version: 1.0.0
   - SDK: >=3.0.0 <4.0.0
   - Dependencies: uuid, crypto, xml, intl
   - Dev dependencies: test, lints

2. **README.md** - User documentation
   - Architecture overview
   - API examples
   - Input specifications
   - Error handling guide
   - Logging usage
   - Test instructions
   - Performance characteristics

3. **IMPLEMENTATION_NOTES.md** - This file

## Key Design Decisions

### 1. Functional Error Handling
- Used Rust-style `Result<T, E>` instead of exceptions for expected failures
- Allows composable error handling via `map()` and `flatMap()`
- Unexpected errors still throw (e.g., IO exceptions)

### 2. In-Memory Store with File Backing
- Map-based store for O(1) lookups
- All versions written to disk under `{basePath}/versions/{scoreId}/`
- Ready to migrate to SQLite without API changes
- Files named `{versionType}_{timestamp}.{ext}` for auditability

### 3. Validation Timing
- PDF/image validation happens synchronously in validators
- XML validation includes parsing and schema checks
- Dimension validation uses binary format parsing (JPEG SOF marker, PNG IHDR chunk)

### 4. Version Immutability
- ScoreEntry and VersionInfo are immutable with copyWith() factories
- Modifications return new instances, previous state preserved
- Supports audit trails and undo/redo

### 5. Structured Logging
- All operations log at appropriate level (info for imports, debug for queries)
- Metadata captured (dimensions, file sizes, error details)
- 1000-entry buffer for debug panel retrieval

### 6. UUID for IDs
- All ScoreEntry IDs are UUID v4 (cryptographically random)
- Validates against regex pattern: `[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}`
- Auto-generated if not provided

## Code Statistics

- **Total lines:** ~2200
- **Library code:** ~1200 lines
- **Test code:** ~1000 lines
- **Test coverage:** All public APIs, error paths, edge cases
- **Cyclomatic complexity:** Low (mostly linear flows)

## Dependency Graph

```
score_library.dart
  -> result.dart
  -> import_error.dart
  -> import_validators.dart
  -> logger.dart (all modules)
  -> score_entry.dart
  -> uuid, crypto, xml, intl

score_entry.dart
  -> uuid

import_validators.dart
  -> import_error.dart
  -> logger.dart
  -> xml

logger.dart
  -> intl
```

## Testing Strategy

- Unit tests for each class/function
- Happy paths and error paths covered
- Edge cases for dimensions (min/max values)
- Concurrent operations tested
- File I/O mocked with temporary directories
- No external dependencies (except SDK)

## Integration Points

- **Module D** (Image Restoration): Adds `restoredImage` versions
- **Module E** (OMR): Generates `omrMusicxml`, `omrScoreJson`, `userEditedScoreJson` versions
- **UI/API Layer**: Calls `importImage()`, `importMusicXml()`, `getLibrary()`, `updateScore()`

## Migration Path to SQLite

1. Replace `Map<String, ScoreEntry> _store` with database connection
2. Implement `_toDb()` and `_fromDb()` for ScoreEntry serialization
3. Add transaction wrapper for atomic operations
4. API surface remains unchanged

## Error Recovery

- Import failures don't leave partial files (validated before write)
- Delete operations remove both DB entry and all files atomically
- Logger provides audit trail for debugging
- No silent failures - all errors returned as `Result`

## Performance Characteristics

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| importImage() | O(n) | n = image size in bytes |
| importMusicXml() | O(n) | n = XML content size |
| getLibrary() | O(n) | n = number of scores |
| getScore() | O(1) | Direct map lookup |
| updateScore() | O(1) | Direct map write |
| deleteScore() | O(m) | m = number of version files |
| search | O(n) | n = number of scores (filters) |
| sort | O(n log n) | Dartsiort in getLibrary() |

## Security Considerations

- UUIDs prevent enumeration of score IDs
- File paths sanitized (timestamp-based, no user input in paths)
- Password-protected PDFs rejected upfront
- XML parsing with recursion protection (via xml package)
- File size limits prevent DoS (50 MB per image/PDF page)

## Testing Coverage

Tested scenarios:
- Valid imports (all 3 formats)
- Invalid formats (non-JPEG/PNG, corrupted PDF)
- Boundary dimensions (199x199, 200x200, 4800x3600, 4801x3600)
- File size limits (just under/over 50 MB)
- MusicXML edge cases (no parts, no measures, invalid version)
- Concurrent operations (3 simultaneous imports)
- Result type composition (map, flatMap, onSuccess, onFailure)
- JSON round-trip (ScoreEntry, VersionInfo)
- Search and sort (3 different sort orders)
