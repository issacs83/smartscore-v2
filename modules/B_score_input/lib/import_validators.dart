import 'dart:async';
import 'dart:io';
import 'package:xml/xml.dart';
import 'import_error.dart';
import 'logger.dart';

const String _module = 'ImportValidators';

/// Validates PDF files for import.
///
/// Returns null if valid, ImportError if invalid.
Future<ImportError?> validatePdfFile(String path) async {
  final logger = ModuleLogger.instance;

  try {
    final file = File(path);

    // Check if file exists
    if (!await file.exists()) {
      logger.warn(_module, 'PDF file not found: $path');
      return ImportError.fileNotFound;
    }

    // Check extension
    if (!path.toLowerCase().endsWith('.pdf')) {
      logger.warn(_module, 'Invalid PDF extension: $path');
      return ImportError.fileInvalidExtension;
    }

    // Check file size (must be reasonable, but don't enforce max here - checked per-page)
    final stat = await file.stat();
    if (stat.size == 0) {
      logger.warn(_module, 'PDF file is empty: $path');
      return ImportError.pdfEmpty;
    }

    // Check for PDF magic bytes
    final bytes = await file.readAsBytes();
    if (bytes.length < 4 || bytes[0] != 0x25 || bytes[1] != 0x50 || bytes[2] != 0x44 || bytes[3] != 0x46) {
      logger.warn(_module, 'File is not a valid PDF: $path');
      return ImportError.pdfCorrupted;
    }

    // Check for password protection (basic check - looks for Encrypt dict)
    final content = String.fromCharCodes(bytes);
    if (content.contains('/Encrypt')) {
      logger.warn(_module, 'PDF appears to be password-protected: $path');
      return ImportError.pdfPasswordProtected;
    }

    logger.debug(_module, 'PDF file validated', data: {'path': path, 'sizeBytes': stat.size});
    return null;
  } catch (e) {
    logger.error(_module, 'Error validating PDF file: $e', data: {'path': path});
    return ImportError.fileAccessDenied;
  }
}

/// Validates image bytes for import.
///
/// Returns null if valid, ImportError if invalid.
Future<ImportError?> validateImageBytes(List<int> bytes) async {
  final logger = ModuleLogger.instance;

  try {
    if (bytes.isEmpty) {
      logger.warn(_module, 'Image bytes are empty');
      return ImportError.imageInvalidFormat;
    }

    // Check file size (≤50 MB)
    if (bytes.length > 50 * 1024 * 1024) {
      logger.warn(_module, 'Image file too large', data: {'sizeBytes': bytes.length});
      return ImportError.imageFileTooLarge;
    }

    // Check for JPEG or PNG magic bytes
    final isJpeg = bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8;
    final isPng = bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;

    if (!isJpeg && !isPng) {
      logger.warn(_module, 'Image is not JPEG or PNG');
      return ImportError.imageInvalidFormat;
    }

    // Parse image dimensions (simplified - check if headers are valid)
    final dimensions = _extractImageDimensions(bytes);
    if (dimensions == null) {
      logger.warn(_module, 'Could not extract image dimensions');
      return ImportError.imageInvalidFormat;
    }

    final (width, height) = dimensions;

    // Check minimum dimensions (200×200)
    if (width < 200 || height < 200) {
      logger.warn(_module, 'Image dimensions too small', data: {'width': width, 'height': height});
      return ImportError.imageDimensionsTooSmall;
    }

    // Check maximum dimensions (4800×3600)
    if (width > 4800 || height > 3600) {
      logger.warn(_module, 'Image dimensions too large', data: {'width': width, 'height': height});
      return ImportError.imageDimensionsTooLarge;
    }

    logger.debug(_module, 'Image validated', data: {
      'sizeBytes': bytes.length,
      'width': width,
      'height': height,
      'format': isJpeg ? 'JPEG' : 'PNG',
    });
    return null;
  } catch (e) {
    logger.error(_module, 'Error validating image: $e');
    return ImportError.imageInvalidFormat;
  }
}

/// Extracts width and height from image bytes.
///
/// Returns (width, height) tuple or null if unable to extract.
(int, int)? _extractImageDimensions(List<int> bytes) {
  try {
    // Check for PNG
    if (bytes.length >= 24 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      // PNG IHDR chunk is at bytes 16-24
      final width = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      final height = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      return (width, height);
    }

    // Check for JPEG - scan for SOF0 (0xFFC0) or SOF2 (0xFFC2) marker
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      int i = 2;
      while (i < bytes.length - 8) {
        if (bytes[i] == 0xFF) {
          final marker = bytes[i + 1];
          if (marker == 0xC0 || marker == 0xC2) {
            // Found SOF marker
            final height = (bytes[i + 5] << 8) | bytes[i + 6];
            final width = (bytes[i + 7] << 8) | bytes[i + 8];
            return (width, height);
          }
          // Skip this segment
          if (marker != 0x00 && marker != 0xFF) {
            final segmentLength = (bytes[i + 2] << 8) | bytes[i + 3];
            i += segmentLength + 2;
          } else {
            i += 2;
          }
        } else {
          i++;
        }
      }
    }

    return null;
  } catch (e) {
    return null;
  }
}

/// Validates MusicXML content for import.
///
/// Returns null if valid, ImportError if invalid.
Future<ImportError?> validateMusicXml(String content) async {
  final logger = ModuleLogger.instance;

  try {
    if (content.trim().isEmpty) {
      logger.warn(_module, 'MusicXML content is empty');
      return ImportError.xmlMalformed;
    }

    // XXE defense: reject XML with DOCTYPE/ENTITY declarations
    if (content.contains('<!DOCTYPE') || content.contains('<!ENTITY')) {
      logger.warn(_module, 'MusicXML contains DOCTYPE/ENTITY declarations (XXE defense)');
      return ImportError.xmlMalformed;
    }

    // Try to parse XML
    final document = XmlDocument.parse(content);

    // Check root element
    final root = document.rootElement;
    if (root.name.local != 'score-partwise' && root.name.local != 'score-timewise') {
      logger.warn(_module, 'Invalid MusicXML root element: ${root.name.local}');
      return ImportError.xmlSchemaInvalid;
    }

    // Check version attribute
    final version = root.getAttribute('version');
    if (version != null && version != '3.0' && version != '3.1') {
      logger.warn(_module, 'Unsupported MusicXML version: $version');
      return ImportError.xmlUnsupportedVersion;
    }

    // Check for parts and measures
    final parts = root.findElements('part').toList();
    if (parts.isEmpty) {
      logger.warn(_module, 'MusicXML has no parts');
      return ImportError.xmlContentEmpty;
    }

    // Check for at least one measure with time signature
    bool hasMeasure = false;
    for (final part in parts) {
      final measures = part.findElements('measure').toList();
      if (measures.isNotEmpty) {
        hasMeasure = true;
        break;
      }
    }

    if (!hasMeasure) {
      logger.warn(_module, 'MusicXML has no measures');
      return ImportError.xmlContentEmpty;
    }

    logger.debug(_module, 'MusicXML validated', data: {
      'partCount': parts.length,
      'version': version ?? 'unknown',
    });
    return null;
  } on XmlParserException catch (e) {
    logger.warn(_module, 'MusicXML parse error: ${e.message}');
    return ImportError.xmlMalformed;
  } catch (e) {
    logger.error(_module, 'Error validating MusicXML: $e');
    return ImportError.xmlMalformed;
  }
}
