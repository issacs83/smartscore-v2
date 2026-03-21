import 'dart:io';
import 'package:test/test.dart';
import 'package:smartscore_build/modules/b_score_input/import_error.dart';
import 'package:smartscore_build/modules/b_score_input/result.dart';
import 'package:smartscore_build/modules/b_score_input/score_entry.dart';
import 'package:smartscore_build/modules/b_score_input/score_library.dart';

void main() {
  late ScoreLibrary library;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('smartscore_test_');
    library = ScoreLibrary(tempDir.path);
    await library.initialize();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('ScoreLibrary', () {
    test('initializes with empty store', () async {
      final scores = await library.getLibrary();
      expect(scores, isEmpty);
    });

    test('importImage() creates valid ScoreEntry', () async {
      // Create a simple valid PNG (1x1 pixel)
      final pngBytes = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, // IHDR chunk size
        0x49, 0x48, 0x44, 0x52, // IHDR
        0x00, 0x00, 0x01, 0x00, // width: 256
        0x00, 0x00, 0x01, 0x00, // height: 256
        0x08, 0x02, 0x00, 0x00, 0x00, // bit depth, color type, etc.
        0x90, 0x77, 0x53, 0xDE, // CRC
      ];

      final result = await library.importImage(pngBytes, 'test.png');

      expect(result.isSuccess, true);
      final entry = result.valueOrNull!;
      expect(entry.title, 'test');
      expect(entry.sourceType, SourceType.image);
      expect(entry.versions, contains(VersionType.originalImage));
    });

    test('importImage() fails with invalid dimensions (too small)', () async {
      // PNG with 100x100 dimensions (below 200x200 minimum)
      final pngBytes = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x64, // width: 100
        0x00, 0x00, 0x00, 0x64, // height: 100
        0x08, 0x02, 0x00, 0x00, 0x00,
        0x90, 0x77, 0x53, 0xDE,
      ];

      final result = await library.importImage(pngBytes, 'test.png');

      expect(result.isFailure, true);
      expect(result.errorOrNull, ImportError.imageDimensionsTooSmall);
    });

    test('importImage() fails with invalid format', () async {
      final invalidBytes = [0x00, 0x01, 0x02, 0x03];

      final result = await library.importImage(invalidBytes, 'test.jpg');

      expect(result.isFailure, true);
      expect(result.errorOrNull, ImportError.imageInvalidFormat);
    });

    test('importPdf() fails with non-existent file', () async {
      final result = await library.importPdf('/nonexistent/file.pdf');

      expect(result.isFailure, true);
      expect(result.errorOrNull, ImportError.fileNotFound);
    });

    test('importMusicXml() creates valid ScoreEntry', () async {
      final xmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <work><work-title>Test Score</work-title></work>
  <identification><composer>Test Composer</composer></identification>
  <part-list>
    <score-part id="P1">
      <part-name>Piano</part-name>
    </score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <time>
          <beats>4</beats>
          <beat-type>4</beat-type>
        </time>
      </attributes>
    </measure>
  </part>
</score-partwise>''';

      final result = await library.importMusicXml(xmlContent, fileName: 'test.musicxml');

      expect(result.isSuccess, true);
      final entry = result.valueOrNull!;
      expect(entry.title, 'test');
      expect(entry.sourceType, SourceType.musicxml);
      expect(entry.versions, contains(VersionType.omrMusicxml));
      expect(entry.versions, contains(VersionType.omrScoreJson));
    });

    test('importMusicXml() fails with malformed XML', () async {
      final xmlContent = '<score-partwise><invalid>';

      final result = await library.importMusicXml(xmlContent);

      expect(result.isFailure, true);
      expect(result.errorOrNull, ImportError.xmlMalformed);
    });

    test('importMusicXml() fails with no parts', () async {
      final xmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <work><work-title>Empty</work-title></work>
  <part-list></part-list>
</score-partwise>''';

      final result = await library.importMusicXml(xmlContent);

      expect(result.isFailure, true);
      expect(result.errorOrNull, ImportError.xmlContentEmpty);
    });

    test('getLibrary() returns all scores', () async {
      // Import two images
      final png1 = _createValidPng(256, 256);
      final png2 = _createValidPng(512, 512);

      await library.importImage(png1, 'score1.png');
      await library.importImage(png2, 'score2.png');

      final scores = await library.getLibrary();

      expect(scores, hasLength(2));
    });

    test('getLibrary() filters by search query', () async {
      final png = _createValidPng(256, 256);

      await library.importImage(png, 'symphony.png');
      await library.importImage(png, 'sonata.png');

      final results = await library.getLibrary(searchQuery: 'symphony');

      expect(results, hasLength(1));
      expect(results.first.title, 'symphony');
    });

    test('getLibrary() sorts by creation date (newest first)', () async {
      final png = _createValidPng(256, 256);

      final r1 = await library.importImage(png, 'first.png');
      await Future.delayed(Duration(milliseconds: 10));
      final r2 = await library.importImage(png, 'second.png');

      final scores = await library.getLibrary(sort: SortOrder.newestFirst);

      expect(scores, hasLength(2));
      expect(scores[0].id, r2.valueOrNull!.id);
      expect(scores[1].id, r1.valueOrNull!.id);
    });

    test('getLibrary() sorts by title ascending', () async {
      final png = _createValidPng(256, 256);

      await library.importImage(png, 'zebra.png');
      await library.importImage(png, 'apple.png');
      await library.importImage(png, 'banana.png');

      final scores = await library.getLibrary(sort: SortOrder.titleAsc);

      expect(scores[0].title, 'apple');
      expect(scores[1].title, 'banana');
      expect(scores[2].title, 'zebra');
    });

    test('getScore() returns entry by ID', () async {
      final png = _createValidPng(256, 256);
      final result = await library.importImage(png, 'test.png');
      final id = result.valueOrNull!.id;

      final retrieved = await library.getScore(id);

      expect(retrieved, isNotNull);
      expect(retrieved?.id, id);
      expect(retrieved?.title, 'test');
    });

    test('getScore() returns null for non-existent ID', () async {
      final retrieved = await library.getScore('nonexistent-id');
      expect(retrieved, isNull);
    });

    test('deleteScore() removes entry and files', () async {
      final png = _createValidPng(256, 256);
      final result = await library.importImage(png, 'test.png');
      final id = result.valueOrNull!.id;

      // Verify it exists
      var retrieved = await library.getScore(id);
      expect(retrieved, isNotNull);

      // Delete
      final deleted = await library.deleteScore(id);
      expect(deleted, true);

      // Verify it's gone
      retrieved = await library.getScore(id);
      expect(retrieved, isNull);
    });

    test('deleteScore() returns false for non-existent ID', () async {
      final deleted = await library.deleteScore('nonexistent-id');
      expect(deleted, false);
    });

    test('updateScore() modifies entry', () async {
      final png = _createValidPng(256, 256);
      final result = await library.importImage(png, 'test.png');
      final id = result.valueOrNull!.id;

      final retrieved = (await library.getScore(id))!;
      final updated = retrieved.copyWith(
        title: 'Updated Title',
        composer: 'New Composer',
      );

      final success = await library.updateScore(id, updated);
      expect(success, true);

      final afterUpdate = await library.getScore(id);
      expect(afterUpdate?.title, 'Updated Title');
      expect(afterUpdate?.composer, 'New Composer');
    });

    test('updateScore() returns false for non-existent ID', () async {
      const validUuid = '550e8400-e29b-4d4d-8d44-446655440000';
      final entry = ScoreEntry(
        id: validUuid,
        title: 'Test',
        sourceType: SourceType.pdf,
      );

      final success = await library.updateScore(validUuid, entry);
      expect(success, false);
    });

    test('addVersion() adds new version to score', () async {
      final png = _createValidPng(256, 256);
      final result = await library.importImage(png, 'test.png');
      final id = result.valueOrNull!.id;

      // Add restored image version
      final restored = _createValidPng(512, 512);
      final success = await library.addVersion(
        id,
        VersionType.restoredImage,
        '${tempDir.path}/versions/$id/restored.png',
        restored.length,
      );

      expect(success, true);

      final entry = await library.getScore(id);
      expect(entry?.versions, contains(VersionType.restoredImage));
    });

    test('addVersion() returns false for non-existent score', () async {
      final success = await library.addVersion(
        'nonexistent',
        VersionType.restoredImage,
        '/path/to/file',
        1024,
      );

      expect(success, false);
    });

    test('getVersion() retrieves version info', () async {
      final png = _createValidPng(256, 256);
      final result = await library.importImage(png, 'test.png');
      final id = result.valueOrNull!.id;

      final version = library.getVersion(id, VersionType.originalImage);

      expect(version, isNotNull);
      expect(version?.sizeBytes, png.length);
    });

    test('getVersion() returns null for non-existent version', () async {
      final png = _createValidPng(256, 256);
      final result = await library.importImage(png, 'test.png');
      final id = result.valueOrNull!.id;

      final version = library.getVersion(id, VersionType.omrMusicxml);

      expect(version, isNull);
    });

    test('multiple concurrent imports work', () async {
      final png1 = _createValidPng(256, 256);
      final png2 = _createValidPng(512, 512);
      final png3 = _createValidPng(300, 300);

      final results = await Future.wait([
        library.importImage(png1, 'img1.png'),
        library.importImage(png2, 'img2.png'),
        library.importImage(png3, 'img3.png'),
      ]);

      expect(results, hasLength(3));
      for (final result in results) {
        expect(result.isSuccess, true);
      }

      final library_scores = await library.getLibrary();
      expect(library_scores, hasLength(3));
    });

    test('Result.Success behaves correctly', () {
      final result = Result<String, ImportError>.success('test value');

      expect(result.isSuccess, true);
      expect(result.isFailure, false);
      expect(result.valueOrNull, 'test value');
      expect(result.errorOrNull, isNull);
    });

    test('Result.Failure behaves correctly', () {
      final result = Result<String, ImportError>.failure(ImportError.imageInvalidFormat);

      expect(result.isSuccess, false);
      expect(result.isFailure, true);
      expect(result.valueOrNull, isNull);
      expect(result.errorOrNull, ImportError.imageInvalidFormat);
    });

    test('Result.map() transforms success', () {
      final result = Result<int, ImportError>.success(42);
      final mapped = result.map((v) => v * 2);

      expect(mapped.valueOrNull, 84);
    });

    test('Result.mapError() transforms failure', () {
      final result = Result<int, ImportError>.failure(ImportError.imageInvalidFormat);
      final mapped = result.mapError((_) => 'custom error');

      expect(mapped.errorOrNull, 'custom error');
    });
  });
}

/// Creates a valid minimal PNG with specified dimensions.
List<int> _createValidPng(int width, int height) {
  final w = [
    (width >> 24) & 0xFF,
    (width >> 16) & 0xFF,
    (width >> 8) & 0xFF,
    width & 0xFF,
  ];
  final h = [
    (height >> 24) & 0xFF,
    (height >> 16) & 0xFF,
    (height >> 8) & 0xFF,
    height & 0xFF,
  ];

  return [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52,
    ...w,
    ...h,
    0x08, 0x02, 0x00, 0x00, 0x00,
    0x90, 0x77, 0x53, 0xDE,
  ];
}
