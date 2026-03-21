# Module B: Score Input & Library - File Manifest

## Library Code (`lib/`)

### Core Modules

| File | Lines | Purpose | Key Classes |
|------|-------|---------|-------------|
| `result.dart` | 60 | Functional error handling | Result<T, E>, Success, Failure |
| `import_error.dart` | 20 | Error type definitions | ImportError enum |
| `logger.dart` | 120 | Structured logging | ModuleLogger, LogEntry |
| `score_entry.dart` | 250 | Core data model | ScoreEntry, VersionType, VersionInfo |
| `import_validators.dart` | 200 | Input validation | validatePdfFile, validateImageBytes, validateMusicXml |
| `score_library.dart` | 350 | Library management | ScoreLibrary, SortOrder |

**Total Library Code: ~1000 lines**

## Test Code (`test/`)

| File | Tests | Coverage |
|------|-------|----------|
| `score_entry_test.dart` | 15 | ScoreEntry creation, serialization, versions, validation |
| `score_library_test.dart` | 25+ | Import workflows, CRUD, search, sort, concurrent ops |
| `import_validators_test.dart` | 25+ | PDF/PNG/JPEG/XML validation, boundary cases |

**Total Tests: 65+**
**Total Test Code: ~1000 lines**

## Configuration

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Package manifest, dependencies |

## Documentation

| File | Purpose |
|------|---------|
| `CONTRACT.md` | API contract (provided) |
| `README.md` | User documentation and examples |
| `QUICK_START.md` | Quick reference and common patterns |
| `IMPLEMENTATION_NOTES.md` | Architecture and design decisions |
| `FILES.md` | This file - manifest of all files |

## Directory Structure

```
B_score_input/
├── lib/
│   ├── result.dart                 # Functional error type
│   ├── import_error.dart           # Error codes enum
│   ├── logger.dart                 # Logging system
│   ├── score_entry.dart            # Core data models
│   ├── import_validators.dart      # Input validation
│   └── score_library.dart          # Main library class
├── test/
│   ├── score_entry_test.dart       # ScoreEntry tests
│   ├── score_library_test.dart     # Library tests
│   └── import_validators_test.dart # Validation tests
├── pubspec.yaml                    # Package manifest
├── CONTRACT.md                     # API contract (provided)
├── README.md                       # Documentation
├── QUICK_START.md                  # Quick reference
├── IMPLEMENTATION_NOTES.md         # Architecture details
└── FILES.md                        # This file
```

## Dependencies

### Production Dependencies
- `uuid: ^4.0.0` - UUID v4 generation
- `crypto: ^3.0.0` - Cryptographic functions
- `xml: ^6.0.0` - XML parsing
- `intl: ^0.19.0` - Internationalization (date formatting)

### Dev Dependencies
- `test: ^1.24.0` - Testing framework
- `lints: ^3.0.0` - Dart style linter

## Code Organization

### Public API (score_library.dart)

```
ScoreLibrary
├── initialize()
├── importPdf(String) -> Future<Result<ScoreEntry, ImportError>>
├── importImage(List<int>, String) -> Future<Result<ScoreEntry, ImportError>>
├── importMusicXml(String) -> Future<Result<ScoreEntry, ImportError>>
├── getLibrary(...) -> Future<List<ScoreEntry>>
├── getScore(String) -> Future<ScoreEntry?>
├── updateScore(String, ScoreEntry) -> Future<bool>
├── deleteScore(String) -> Future<bool>
├── addVersion(...) -> Future<bool>
└── getVersion(...) -> VersionInfo?
```

### Data Models (score_entry.dart)

```
ScoreEntry
├── id: String (UUID v4)
├── title: String
├── composer: String?
├── sourceType: SourceType
├── versions: Map<VersionType, VersionInfo>
├── createdAt: DateTime
├── updatedAt: DateTime
└── methods: validate(), addVersion(), getVersion(), copyWith(), toJson(), fromJson()

VersionInfo
├── filePath: String
├── createdAt: DateTime
├── sizeBytes: int
├── metadata: Map?
└── methods: toJson(), fromJson()

VersionType enum
├── originalImage
├── restoredImage
├── omrMusicxml
├── omrScoreJson
└── userEditedScoreJson

SourceType enum
├── pdf
├── image
├── musicxml
└── manualJson
```

### Validators (import_validators.dart)

```
validatePdfFile(String path) -> Future<ImportError?>
validateImageBytes(List<int> bytes) -> Future<ImportError?>
validateMusicXml(String content) -> Future<ImportError?>
```

### Error Handling (result.dart)

```
Result<T, E> - sealed class
├── Success<T, E> extends Result
└── Failure<T, E> extends Result

Methods:
├── map<R>(fn) -> Result<R, E>
├── mapError<R>(fn) -> Result<T, R>
├── flatMap<R>(fn) -> Result<R, E>
├── getOrThrow() -> T
├── getOrElse(fn) -> T
├── onSuccess(fn) -> void
└── onFailure(fn) -> void
```

### Logging (logger.dart)

```
ModuleLogger (singleton)
├── log(level, module, message, data) -> void
├── debug/info/warn/error(...) -> void
├── getBuffer() -> List<LogEntry>
├── getRecent(limit) -> List<LogEntry>
├── filterByLevel(level) -> List<LogEntry>
├── filterByModule(module) -> List<LogEntry>
└── clearBuffer() -> void

LogEntry
├── timestamp: DateTime
├── level: LogLevel
├── module: String
├── message: String
├── data: Map?
└── toString() -> String
```

## Testing Strategy

### Unit Tests
- 15 tests for ScoreEntry (model, serialization, validation)
- 25+ tests for ScoreLibrary (imports, CRUD, search, sort)
- 25+ tests for validators (formats, dimensions, edge cases)

### Coverage Areas
- Happy paths (successful imports and queries)
- Error paths (invalid formats, size limits, missing data)
- Edge cases (min/max dimensions, boundary values)
- Concurrency (multiple simultaneous operations)
- Serialization (JSON round-trip)
- Result type behavior (map, flatMap, composition)

### Test Utilities
- `_createValidPng(width, height)` - Generate test PNG bytes
- `_createValidJpeg(width, height)` - Generate test JPEG bytes
- `_createMinimalPdf()` - Generate test PDF bytes
- Temp directory fixtures

## Integration Points

### Module D (Image Restoration)
- Produces `restoredImage` versions
- Calls: `library.addVersion(scoreId, VersionType.restoredImage, ...)`

### Module E (OMR Processing)
- Produces `omrMusicxml`, `omrScoreJson`, `userEditedScoreJson` versions
- Calls: `library.addVersion()` for each version type

### UI/API Layer
- Calls import methods: `importImage()`, `importMusicXml()`, `importPdf()`
- Queries: `getLibrary()`, `getScore()`
- Updates: `updateScore()`, `deleteScore()`
- Accesses: `library.getVersion()` for version details

## Version History

- v1.0.0 - Initial implementation
  - All core functionality implemented
  - 65+ comprehensive tests
  - Full contract compliance

## File Sizes (Approximate)

```
lib/result.dart                  ~2 KB
lib/import_error.dart            ~1 KB
lib/logger.dart                  ~5 KB
lib/score_entry.dart            ~10 KB
lib/import_validators.dart       ~8 KB
lib/score_library.dart          ~14 KB
test/score_entry_test.dart      ~11 KB
test/score_library_test.dart    ~14 KB
test/import_validators_test.dart ~14 KB
pubspec.yaml                     ~0.5 KB
README.md                        ~10 KB
QUICK_START.md                   ~8 KB
IMPLEMENTATION_NOTES.md          ~10 KB

Total: ~112 KB
```

## Running the Code

```bash
# Get dependencies
dart pub get

# Run all tests
dart test

# Run specific test file
dart test test/score_library_test.dart

# Generate documentation
dart doc

# Analyze code
dart analyze

# Format code
dart format lib/ test/
```

## Future Extensions

Files that may be added/modified:
- `lib/sqlite_store.dart` - SQLite implementation (replaces Map store)
- `lib/pdf_extractor.dart` - PDF to image extraction
- `lib/musicxml_parser.dart` - MusicXML to Score JSON conversion
- `test/sqlite_store_test.dart` - SQLite tests
- `pubspec.yaml` - Add sqlite3, pdf packages

