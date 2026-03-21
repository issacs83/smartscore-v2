# Quick Start Guide

## Installation

```bash
cd modules/B_score_input
pub get
```

## Basic Usage

### Initialize Library

```dart
import 'package:smartscore_b_score_input/score_library.dart';

final library = ScoreLibrary('/path/to/library/data');
await library.initialize();
```

### Import a Score

```dart
// From image file
final imageBytes = await File('score.png').readAsBytes();
final result = await library.importImage(imageBytes, 'score.png');

if (result.isSuccess) {
  final entry = result.valueOrNull!;
  print('Imported: ${entry.id}');
  print('Title: ${entry.title}');
}

// From MusicXML
final xmlContent = await File('score.musicxml').readAsString();
final result = await library.importMusicXml(xmlContent);

result.onSuccess((entry) => print('MusicXML imported'));
result.onFailure((error) => print('Error: ${error.message}'));
```

### Query the Library

```dart
// Get all scores
final scores = await library.getLibrary();

// Search by title or composer
final results = await library.getLibrary(
  searchQuery: 'Beethoven',
);

// Sort by title
final sorted = await library.getLibrary(
  sort: SortOrder.titleAsc,
);

// Get single score
final score = await library.getScore(scoreId);
```

### Modify Scores

```dart
// Update metadata
final updated = score.copyWith(
  title: 'Symphony No. 9',
  composer: 'Beethoven',
);
await library.updateScore(scoreId, updated);

// Add a new version (e.g., after restoration)
await library.addVersion(
  scoreId,
  VersionType.restoredImage,
  '/path/to/restored.png',
  fileSize,
);

// Get version info
final version = library.getVersion(
  scoreId,
  VersionType.originalImage,
);
print('Version size: ${version?.sizeBytes} bytes');
```

### Delete Score

```dart
final deleted = await library.deleteScore(scoreId);
if (deleted) {
  print('Score and all versions deleted');
}
```

## Error Handling

```dart
final result = await library.importImage(bytes, 'score.png');

switch (result.errorOrNull) {
  case ImportError.imageInvalidFormat:
    print('Not a valid JPEG or PNG');
  case ImportError.imageDimensionsTooSmall:
    print('Image must be at least 200x200 pixels');
  case ImportError.imageDimensionsTooLarge:
    print('Image must not exceed 4800x3600 pixels');
  case ImportError.imageFileTooLarge:
    print('Image must be 50 MB or smaller');
  case null:
    print('Success: ${result.valueOrNull}');
  case _:
    print('Other error: ${result.errorOrNull}');
}
```

## Logging

```dart
import 'package:smartscore_b_score_input/logger.dart';

final logger = ModuleLogger.instance;

// Retrieve logs
final buffer = logger.getBuffer();
final recent = logger.getRecent(limit: 20);
final errors = logger.filterByLevel(LogLevel.error);

// Print a log entry
for (final entry in buffer) {
  print(entry); // Uses toString() formatting
}
```

## Testing

```bash
# Run all tests
dart test

# Run specific test file
dart test test/score_library_test.dart

# Run with output
dart test -v

# Run with coverage
dart pub add dev:coverage
dart test --coverage=coverage
dart run coverage:format_coverage --packages=.packages --report-on=lib --in=coverage --out=coverage/lcov.info
```

## Common Patterns

### Process Multiple Files

```dart
final files = [
  'score1.png',
  'score2.png',
  'score3.png',
];

final results = await Future.wait([
  for (final file in files)
    library.importImage(
      await File(file).readAsBytes(),
      file,
    ),
]);

final successes = results.whereType<Success>();
final failures = results.whereType<Failure>();

print('Imported: ${successes.length}, Failed: ${failures.length}');
```

### Search and Update

```dart
// Find all scores by a composer
final scores = await library.getLibrary(
  searchQuery: 'Bach',
);

// Update each one
for (final score in scores) {
  final updated = score.copyWith(
    composer: 'Johann Sebastian Bach',
  );
  await library.updateScore(score.id, updated);
}
```

### Iterate Versions

```dart
final score = await library.getScore(scoreId);

for (final versionType in score.getAvailableVersions()) {
  final version = score.getVersion(versionType);
  print('$versionType: ${version?.sizeBytes} bytes');
}
```

## File Structure

```
data/
  versions/
    550e8400-e29b-41d4-a716-446655440000/
      original_image_1234567890.png
      omr_musicxml_1234567890.xml
      omr_score_json_1234567890.json
    550e8400-e29b-41d4-a716-446655440001/
      original_image_1234567890.png
      restored_image_1234567900.png
```

## Troubleshooting

**Import fails with `imageDimensionsTooSmall`**
- Ensure image is at least 200×200 pixels
- Use `convert` or similar tools to resize if needed

**MusicXML import fails with `xmlMalformed`**
- Validate XML is well-formed (use an XML validator)
- Check file encoding is UTF-8

**PDF import fails with `pdfPasswordProtected`**
- Remove password from PDF using PDF editor
- Use `qpdf` to unlock: `qpdf --password='' input.pdf output.pdf`

**Search returns no results**
- Search is case-insensitive but requires substring match
- Check title and composer fields are filled

**Cannot delete score**
- Ensure you have write permissions to version files directory
- Check filesystem isn't full

## API Reference

See generated dartdoc:
```bash
dart doc
```

Open `doc/api/index.html` in browser.
