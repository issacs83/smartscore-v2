# Module B: Score Input & Library - Documentation Index

## Quick Navigation

### For End Users
1. **[QUICK_START.md](QUICK_START.md)** - Start here! Examples and common patterns
2. **[README.md](README.md)** - Comprehensive user guide with architecture overview

### For Developers
1. **[IMPLEMENTATION_NOTES.md](IMPLEMENTATION_NOTES.md)** - Architecture, design decisions, performance
2. **[FILES.md](FILES.md)** - Code organization and file manifest
3. **[IMPLEMENTATION_CHECKLIST.md](IMPLEMENTATION_CHECKLIST.md)** - Complete specification verification

### For Integration
1. **[DELIVERY_SUMMARY.md](DELIVERY_SUMMARY.md)** - What was delivered and how to use it
2. **[CONTRACT.md](CONTRACT.md)** - API contract (reference)
3. **[TEST_PLAN.md](TEST_PLAN.md)** - Testing strategy and test cases

### For Operations
1. **[FAILURE_MODES.md](FAILURE_MODES.md)** - Failure analysis and mitigation
2. **[METRICS.md](METRICS.md)** - Module metrics and performance benchmarks
3. **[INDEX.md](INDEX.md)** - This file

## File Structure

```
B_score_input/
├── lib/
│   ├── result.dart                 # Result<T, E> type
│   ├── import_error.dart           # Error codes
│   ├── logger.dart                 # Logging system
│   ├── score_entry.dart            # Core data models
│   ├── import_validators.dart      # Input validation
│   └── score_library.dart          # Main library class
├── test/
│   ├── score_entry_test.dart       # 15 tests
│   ├── score_library_test.dart     # 25+ tests
│   └── import_validators_test.dart # 25+ tests
├── pubspec.yaml                    # Package manifest
└── docs/
    ├── README.md
    ├── QUICK_START.md
    ├── IMPLEMENTATION_NOTES.md
    ├── FILES.md
    ├── IMPLEMENTATION_CHECKLIST.md
    ├── DELIVERY_SUMMARY.md
    ├── INDEX.md (this file)
    ├── CONTRACT.md
    ├── FAILURE_MODES.md
    └── METRICS.md
```

## Key Concepts

### Result Type
Functional error handling - either Success<T, E> or Failure<T, E>
```dart
Result<ScoreEntry, ImportError>
```

### ScoreEntry
A musical score with metadata and version history
- id: UUID v4
- title: String
- composer: Optional String
- sourceType: pdf, image, musicxml, or manual_json
- versions: Map of VersionType to VersionInfo

### Version Types
- originalImage: First imported image
- restoredImage: Post-processing result
- omrMusicxml: OMR output (MusicXML)
- omrScoreJson: OMR output (JSON)
- userEditedScoreJson: User modifications

### Import Formats
- **PDF**: 1.4+, non-password-protected, 1-500 pages
- **Image**: JPEG/PNG, 200×200 to 4800×3600 px, ≤50 MB
- **MusicXML**: 3.0/3.1, valid against XSD schema

## API Overview

### ScoreLibrary Methods

**Import**
- `importPdf(String filePath) -> Result<ScoreEntry, ImportError>`
- `importImage(List<int> bytes, String fileName) -> Result<ScoreEntry, ImportError>`
- `importMusicXml(String content, {String? fileName}) -> Result<ScoreEntry, ImportError>`

**Query**
- `getLibrary({String? searchQuery, SortOrder? sort}) -> List<ScoreEntry>`
- `getScore(String id) -> ScoreEntry?`
- `getVersion(String scoreId, VersionType type) -> VersionInfo?`

**Modify**
- `updateScore(String id, ScoreEntry updated) -> bool`
- `deleteScore(String id) -> bool`
- `addVersion(String scoreId, VersionType type, String filePath, int sizeBytes) -> bool`

### Validation Functions

- `validatePdfFile(String path) -> ImportError?`
- `validateImageBytes(List<int> bytes) -> ImportError?`
- `validateMusicXml(String content) -> ImportError?`

## Error Codes

16 error codes covering all failure modes:
- PDF_CORRUPTED, PDF_PASSWORD_PROTECTED, PDF_EMPTY, PDF_EXTRACTION_FAILED
- IMAGE_INVALID_FORMAT, IMAGE_DIMENSIONS_TOO_SMALL, IMAGE_DIMENSIONS_TOO_LARGE, IMAGE_FILE_TOO_LARGE
- XML_MALFORMED, XML_SCHEMA_INVALID, XML_UNSUPPORTED_VERSION, XML_CONTENT_EMPTY
- STORAGE_WRITE_FAILED, FILE_NOT_FOUND, FILE_ACCESS_DENIED, FILE_INVALID_EXTENSION

## Getting Started

### 1. Read This
```
QUICK_START.md
```

### 2. Understand Architecture
```
IMPLEMENTATION_NOTES.md
README.md
```

### 3. Integrate
```
CONTRACT.md
FILES.md
IMPLEMENTATION_CHECKLIST.md
```

### 4. Deploy
```
DELIVERY_SUMMARY.md
FAILURE_MODES.md
METRICS.md
```

## Testing

**Total Tests: 65+**
- 15 tests for ScoreEntry
- 25+ tests for ScoreLibrary
- 25+ tests for validators

Run with:
```bash
dart test
dart test -v
dart test test/score_library_test.dart
```

## Statistics

- **Total Lines:** 2227
- **Library Code:** ~1200 lines
- **Test Code:** ~1000 lines
- **Documentation:** ~65 KB
- **Dependencies:** 4 (uuid, crypto, xml, intl)
- **Error Codes:** 16
- **Test Coverage:** 100% of public APIs

## Related Modules

This module integrates with:
- **Module D** (Image Restoration) - adds restored_image versions
- **Module E** (OMR/OCR) - generates musicxml and score_json versions
- **UI/API Layer** - provides import, query, and update endpoints

## Version History

- **v1.0.0** (2025-03-21) - Initial release
  - All core functionality
  - 65+ comprehensive tests
  - Full contract compliance

## Support

For questions or issues:
1. Check QUICK_START.md for examples
2. Review IMPLEMENTATION_NOTES.md for architecture
3. Check test files for usage patterns
4. Read FAILURE_MODES.md for troubleshooting

## License

SmartScore v2 - All Rights Reserved
