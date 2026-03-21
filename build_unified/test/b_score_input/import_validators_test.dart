import 'dart:io';
import 'package:test/test.dart';
import 'package:smartscore_build/modules/b_score_input/import_error.dart';
import 'package:smartscore_build/modules/b_score_input/import_validators.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('smartscore_validators_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  group('validatePdfFile', () {
    test('accepts valid PDF file', () async {
      // Create a minimal valid PDF
      final pdfContent = _createMinimalPdf();
      final pdfFile = File('${tempDir.path}/test.pdf');
      await pdfFile.writeAsBytes(pdfContent);

      final error = await validatePdfFile(pdfFile.path);

      expect(error, isNull);
    });

    test('rejects non-existent file', () async {
      final error = await validatePdfFile('${tempDir.path}/nonexistent.pdf');

      expect(error, ImportError.fileNotFound);
    });

    test('rejects file with wrong extension', () async {
      final pdfContent = _createMinimalPdf();
      final wrongFile = File('${tempDir.path}/test.txt');
      await wrongFile.writeAsBytes(pdfContent);

      final error = await validatePdfFile(wrongFile.path);

      expect(error, ImportError.fileInvalidExtension);
    });

    test('rejects empty file', () async {
      final emptyFile = File('${tempDir.path}/empty.pdf');
      await emptyFile.writeAsString('');

      final error = await validatePdfFile(emptyFile.path);

      expect(error, ImportError.pdfEmpty);
    });

    test('rejects file without PDF magic bytes', () async {
      final invalidFile = File('${tempDir.path}/notpdf.pdf');
      await invalidFile.writeAsBytes([0x00, 0x01, 0x02, 0x03]);

      final error = await validatePdfFile(invalidFile.path);

      expect(error, ImportError.pdfCorrupted);
    });

    test('rejects password-protected PDF', () async {
      // Create PDF with /Encrypt directive
      final pdfContent = [..._createMinimalPdf(), ...'/Encrypt'.codeUnits];
      final protectedFile = File('${tempDir.path}/protected.pdf');
      await protectedFile.writeAsBytes(pdfContent);

      final error = await validatePdfFile(protectedFile.path);

      expect(error, ImportError.pdfPasswordProtected);
    });
  });

  group('validateImageBytes', () {
    test('accepts valid PNG image', () async {
      final pngBytes = _createValidPng(256, 256);

      final error = await validateImageBytes(pngBytes);

      expect(error, isNull);
    });

    test('accepts valid JPEG image', () async {
      final jpegBytes = _createValidJpeg(256, 256);

      final error = await validateImageBytes(jpegBytes);

      expect(error, isNull);
    });

    test('rejects empty bytes', () async {
      final error = await validateImageBytes([]);

      expect(error, ImportError.imageInvalidFormat);
    });

    test('rejects invalid format', () async {
      final invalidBytes = [0x00, 0x01, 0x02, 0x03];

      final error = await validateImageBytes(invalidBytes);

      expect(error, ImportError.imageInvalidFormat);
    });

    test('rejects PNG with dimensions too small', () async {
      final pngBytes = _createValidPng(100, 100);

      final error = await validateImageBytes(pngBytes);

      expect(error, ImportError.imageDimensionsTooSmall);
    });

    test('rejects PNG with width too small', () async {
      final pngBytes = _createValidPng(100, 500);

      final error = await validateImageBytes(pngBytes);

      expect(error, ImportError.imageDimensionsTooSmall);
    });

    test('rejects PNG with height too small', () async {
      final pngBytes = _createValidPng(500, 100);

      final error = await validateImageBytes(pngBytes);

      expect(error, ImportError.imageDimensionsTooSmall);
    });

    test('rejects PNG with dimensions too large', () async {
      final pngBytes = _createValidPng(5000, 3600);

      final error = await validateImageBytes(pngBytes);

      expect(error, ImportError.imageDimensionsTooLarge);
    });

    test('rejects PNG with width too large', () async {
      final pngBytes = _createValidPng(5000, 3000);

      final error = await validateImageBytes(pngBytes);

      expect(error, ImportError.imageDimensionsTooLarge);
    });

    test('rejects PNG with height too large', () async {
      final pngBytes = _createValidPng(4000, 4000);

      final error = await validateImageBytes(pngBytes);

      expect(error, ImportError.imageDimensionsTooLarge);
    });

    test('rejects oversized file (>50MB)', () async {
      // Create a very large PNG by padding
      var pngBytes = _createValidPng(256, 256);
      pngBytes.addAll(List<int>.filled(51 * 1024 * 1024, 0));

      final error = await validateImageBytes(pngBytes);

      expect(error, ImportError.imageFileTooLarge);
    });

    test('accepts minimum valid dimensions (200x200)', () async {
      final pngBytes = _createValidPng(200, 200);

      final error = await validateImageBytes(pngBytes);

      expect(error, isNull);
    });

    test('accepts maximum valid dimensions (4800x3600)', () async {
      final pngBytes = _createValidPng(4800, 3600);

      final error = await validateImageBytes(pngBytes);

      expect(error, isNull);
    });

    test('accepts rectangular images with valid dimensions', () async {
      final pngBytes = _createValidPng(800, 600);

      final error = await validateImageBytes(pngBytes);

      expect(error, isNull);
    });
  });

  group('validateMusicXml', () {
    test('accepts valid MusicXML 3.1', () async {
      final xmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <work><work-title>Test</work-title></work>
  <part-list>
    <score-part id="P1"><part-name>Piano</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes><time><beats>4</beats><beat-type>4</beat-type></time></attributes>
    </measure>
  </part>
</score-partwise>''';

      final error = await validateMusicXml(xmlContent);

      expect(error, isNull);
    });

    test('accepts valid MusicXML 3.0', () async {
      final xmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.0">
  <work><work-title>Test</work-title></work>
  <part-list>
    <score-part id="P1"><part-name>Piano</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1"></measure>
  </part>
</score-partwise>''';

      final error = await validateMusicXml(xmlContent);

      expect(error, isNull);
    });

    test('accepts score-timewise root', () async {
      final xmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<score-timewise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Piano</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1"></measure>
  </part>
</score-timewise>''';

      final error = await validateMusicXml(xmlContent);

      expect(error, isNull);
    });

    test('rejects empty content', () async {
      final error = await validateMusicXml('');

      expect(error, ImportError.xmlMalformed);
    });

    test('rejects malformed XML', () async {
      final xmlContent = '<score-partwise><invalid>';

      final error = await validateMusicXml(xmlContent);

      expect(error, ImportError.xmlMalformed);
    });

    test('rejects invalid root element', () async {
      final xmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<score version="3.1">
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
</score>''';

      final error = await validateMusicXml(xmlContent);

      expect(error, ImportError.xmlSchemaInvalid);
    });

    test('rejects unsupported version', () async {
      final xmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="2.0">
  <part-list><score-part id="P1"><part-name>Piano</part-name></score-part></part-list>
</score-partwise>''';

      final error = await validateMusicXml(xmlContent);

      expect(error, ImportError.xmlUnsupportedVersion);
    });

    test('rejects MusicXML with no parts', () async {
      final xmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <work><work-title>Test</work-title></work>
  <part-list></part-list>
</score-partwise>''';

      final error = await validateMusicXml(xmlContent);

      expect(error, ImportError.xmlContentEmpty);
    });

    test('rejects MusicXML with no measures', () async {
      final xmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Piano</part-name></score-part>
  </part-list>
  <part id="P1"></part>
</score-partwise>''';

      final error = await validateMusicXml(xmlContent);

      expect(error, ImportError.xmlContentEmpty);
    });

    test('accepts MusicXML with multiple parts', () async {
      final xmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <part-list>
    <score-part id="P1"><part-name>Violin</part-name></score-part>
    <score-part id="P2"><part-name>Piano</part-name></score-part>
  </part-list>
  <part id="P1"><measure number="1"></measure></part>
  <part id="P2"><measure number="1"></measure></part>
</score-partwise>''';

      final error = await validateMusicXml(xmlContent);

      expect(error, isNull);
    });

    test('accepts MusicXML without version attribute', () async {
      final xmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise>
  <part-list>
    <score-part id="P1"><part-name>Piano</part-name></score-part>
  </part-list>
  <part id="P1"><measure number="1"></measure></part>
</score-partwise>''';

      final error = await validateMusicXml(xmlContent);

      expect(error, isNull);
    });
  });
}

/// Creates a minimal valid PDF structure.
List<int> _createMinimalPdf() {
  final header = '%PDF-1.4\n';
  return [
    ...header.codeUnits,
    0x25, 0x25, 0x45, 0x4F, 0x46, // %%EOF
  ];
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

/// Creates a valid minimal JPEG with specified dimensions.
List<int> _createValidJpeg(int width, int height) {
  final w = [(width >> 8) & 0xFF, width & 0xFF];
  final h = [(height >> 8) & 0xFF, height & 0xFF];

  return [
    0xFF, 0xD8, // SOI
    0xFF, 0xE0, 0x00, 0x10, // APP0
    0x4A, 0x46, 0x49, 0x46, 0x00, // JFIF
    0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
    0xFF, 0xC0, 0x00, 0x0B, // SOF0
    0x08, ...h, ...w, 0x01, 0x01, 0x11, 0x00,
    0xFF, 0xD9, // EOI
  ];
}
