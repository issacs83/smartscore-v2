import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'import_error.dart';
import 'import_validators.dart';
import 'logger.dart';
import 'result.dart';
import 'score_entry.dart';

const String _module = 'ScoreLibrary';

/// Sort order for library queries.
enum SortOrder {
  newestFirst,
  oldestFirst,
  titleAsc,
  titleDesc,
  composerAsc,
  composerDesc,
}

/// In-memory score library with file-based storage.
///
/// Uses a Map-based store with SQLite-compatible API shape for now.
/// Manages imports, persistence, and version control.
class ScoreLibrary {
  final String basePath;
  final Map<String, ScoreEntry> _store = {};
  final ModuleLogger _logger = ModuleLogger.instance;

  late final Directory _versionsDir;

  ScoreLibrary(this.basePath);

  /// Initializes the library, creating necessary directories.
  Future<void> initialize() async {
    _logger.info(_module, 'Initializing library', data: {'basePath': basePath});

    try {
      _versionsDir = Directory('$basePath/versions');
      if (!await _versionsDir.exists()) {
        await _versionsDir.create(recursive: true);
      }
      _logger.info(_module, 'Library initialized successfully');
    } catch (e) {
      _logger.error(_module, 'Failed to initialize library: $e');
      rethrow;
    }
  }

  /// Imports a PDF file and creates a new ScoreEntry.
  Future<Result<ScoreEntry, ImportError>> importPdf(String filePath) async {
    _logger.info(_module, 'Importing PDF', data: {'path': filePath});

    try {
      // Validate PDF
      final validationError = await validatePdfFile(filePath);
      if (validationError != null) {
        return Result.failure(validationError);
      }

      final file = File(filePath);
      final fileName = file.path.split('/').last;
      final title = fileName.replaceAll('.pdf', '');

      // Create ScoreEntry
      final entry = ScoreEntry(
        title: title,
        sourceType: SourceType.pdf,
      );

      // Store original PDF bytes as image placeholder
      final bytes = await file.readAsBytes();
      final versionInfo = VersionInfo(
        filePath: _getVersionPath(entry.id, VersionType.originalImage),
        createdAt: DateTime.now().toUtc(),
        sizeBytes: bytes.length,
        metadata: {'source': 'pdf_import'},
      );

      // Write file
      await _writeVersionFile(versionInfo, bytes);

      // Add version to entry
      final updatedEntry = entry.addVersion(VersionType.originalImage, versionInfo);

      // Store in library
      _store[entry.id] = updatedEntry;

      _logger.info(_module, 'PDF imported successfully', data: {
        'scoreId': entry.id,
        'title': title,
        'sizeBytes': bytes.length,
      });

      return Result.success(updatedEntry);
    } catch (e) {
      _logger.error(_module, 'PDF import failed: $e', data: {'path': filePath});
      return Result.failure(ImportError.storageWriteFailed);
    }
  }

  /// Imports image bytes and creates a new ScoreEntry.
  Future<Result<ScoreEntry, ImportError>> importImage(
    List<int> bytes,
    String fileName,
  ) async {
    _logger.info(_module, 'Importing image', data: {'fileName': fileName, 'sizeBytes': bytes.length});

    try {
      // Validate image
      final validationError = await validateImageBytes(bytes);
      if (validationError != null) {
        return Result.failure(validationError);
      }

      // Create ScoreEntry
      final title = fileName.replaceAll(RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false), '');
      final entry = ScoreEntry(
        title: title,
        sourceType: SourceType.image,
      );

      // Create version info
      final versionInfo = VersionInfo(
        filePath: _getVersionPath(entry.id, VersionType.originalImage),
        createdAt: DateTime.now().toUtc(),
        sizeBytes: bytes.length,
        metadata: {'originalFileName': fileName},
      );

      // Write file
      await _writeVersionFile(versionInfo, bytes);

      // Add version to entry
      final updatedEntry = entry.addVersion(VersionType.originalImage, versionInfo);

      // Store in library
      _store[entry.id] = updatedEntry;

      _logger.info(_module, 'Image imported successfully', data: {
        'scoreId': entry.id,
        'title': title,
        'fileName': fileName,
      });

      return Result.success(updatedEntry);
    } catch (e) {
      _logger.error(_module, 'Image import failed: $e', data: {'fileName': fileName});
      return Result.failure(ImportError.storageWriteFailed);
    }
  }

  /// Imports MusicXML content and creates a new ScoreEntry.
  Future<Result<ScoreEntry, ImportError>> importMusicXml(
    String content, {
    String? fileName,
  }) async {
    _logger.info(_module, 'Importing MusicXML', data: {'fileName': fileName});

    try {
      // Validate MusicXML
      final validationError = await validateMusicXml(content);
      if (validationError != null) {
        return Result.failure(validationError);
      }

      // Create ScoreEntry with default title
      final title = fileName?.replaceAll(RegExp(r'\.(musicxml|xml)$', caseSensitive: false), '') ?? 'Untitled';
      final entry = ScoreEntry(
        title: title,
        sourceType: SourceType.musicxml,
      );

      // Store MusicXML as version
      final contentBytes = utf8.encode(content);
      final xmlVersionInfo = VersionInfo(
        filePath: _getVersionPath(entry.id, VersionType.omrMusicxml),
        createdAt: DateTime.now().toUtc(),
        sizeBytes: contentBytes.length,
        metadata: {'sourceFile': fileName},
      );

      await _writeVersionFile(xmlVersionInfo, contentBytes);

      var updatedEntry = entry.addVersion(VersionType.omrMusicxml, xmlVersionInfo);

      // TODO: Generate Score JSON via Module E parser
      // For now, store the XML as-is with a placeholder JSON version
      final scoreJsonContent = _generatePlaceholderScoreJson(content);
      final scoreJsonBytes = utf8.encode(scoreJsonContent);
      final jsonVersionInfo = VersionInfo(
        filePath: _getVersionPath(entry.id, VersionType.omrScoreJson),
        createdAt: DateTime.now().toUtc(),
        sizeBytes: scoreJsonBytes.length,
        metadata: {'generated': true, 'fromMusicXml': true},
      );

      await _writeVersionFile(jsonVersionInfo, scoreJsonBytes);
      updatedEntry = updatedEntry.addVersion(VersionType.omrScoreJson, jsonVersionInfo);

      // Store in library
      _store[entry.id] = updatedEntry;

      _logger.info(_module, 'MusicXML imported successfully', data: {
        'scoreId': entry.id,
        'title': title,
        'contentSizeBytes': contentBytes.length,
      });

      return Result.success(updatedEntry);
    } catch (e) {
      _logger.error(_module, 'MusicXML import failed: $e');
      return Result.failure(ImportError.xmlMalformed);
    }
  }

  /// Gets all scores in the library, optionally filtered and sorted.
  Future<List<ScoreEntry>> getLibrary({
    String? searchQuery,
    SortOrder? sort,
  }) async {
    _logger.debug(_module, 'Getting library', data: {
      'scoreCount': _store.length,
      'hasSearch': searchQuery != null,
      'sort': sort?.toString(),
    });

    var results = _store.values.toList();

    // Filter by search query
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      results = results
          .where((entry) =>
              entry.title.toLowerCase().contains(query) ||
              (entry.composer?.toLowerCase().contains(query) ?? false))
          .toList();
    }

    // Sort
    switch (sort ?? SortOrder.newestFirst) {
      case SortOrder.newestFirst:
        results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case SortOrder.oldestFirst:
        results.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case SortOrder.titleAsc:
        results.sort((a, b) => a.title.compareTo(b.title));
      case SortOrder.titleDesc:
        results.sort((a, b) => b.title.compareTo(a.title));
      case SortOrder.composerAsc:
        results.sort((a, b) =>
            (a.composer ?? '').compareTo(b.composer ?? ''));
      case SortOrder.composerDesc:
        results.sort((a, b) =>
            (b.composer ?? '').compareTo(a.composer ?? ''));
    }

    return results;
  }

  /// Gets a single score by ID.
  Future<ScoreEntry?> getScore(String id) async {
    _logger.debug(_module, 'Getting score', data: {'id': id});
    return _store[id];
  }

  /// Deletes a score and all its version files.
  Future<bool> deleteScore(String id) async {
    _logger.info(_module, 'Deleting score', data: {'id': id});

    try {
      final entry = _store[id];
      if (entry == null) {
        _logger.warn(_module, 'Score not found for deletion', data: {'id': id});
        return false;
      }

      // Delete all version files
      final scoreDir = Directory('${_versionsDir.path}/$id');
      if (await scoreDir.exists()) {
        await scoreDir.delete(recursive: true);
      }

      // Remove from store
      _store.remove(id);

      _logger.info(_module, 'Score deleted successfully', data: {'id': id});
      return true;
    } catch (e) {
      _logger.error(_module, 'Failed to delete score: $e', data: {'id': id});
      return false;
    }
  }

  /// Updates a score entry.
  Future<bool> updateScore(String id, ScoreEntry updated) async {
    _logger.info(_module, 'Updating score', data: {'id': id});

    try {
      if (_store[id] == null) {
        _logger.warn(_module, 'Score not found for update', data: {'id': id});
        return false;
      }

      // Validate updated entry
      final error = updated.validate();
      if (error != null) {
        _logger.warn(_module, 'Invalid score data: $error', data: {'id': id});
        return false;
      }

      _store[id] = updated;
      _logger.info(_module, 'Score updated successfully', data: {'id': id});
      return true;
    } catch (e) {
      _logger.error(_module, 'Failed to update score: $e', data: {'id': id});
      return false;
    }
  }

  /// Adds a version to an existing score.
  Future<bool> addVersion(
    String scoreId,
    VersionType type,
    String filePath,
    int sizeBytes,
  ) async {
    _logger.info(_module, 'Adding version', data: {
      'scoreId': scoreId,
      'type': type.label,
      'sizeBytes': sizeBytes,
    });

    try {
      final entry = _store[scoreId];
      if (entry == null) {
        _logger.warn(_module, 'Score not found for version addition', data: {'scoreId': scoreId});
        return false;
      }

      final versionInfo = VersionInfo(
        filePath: filePath,
        createdAt: DateTime.now().toUtc(),
        sizeBytes: sizeBytes,
      );

      final updated = entry.addVersion(type, versionInfo);
      _store[scoreId] = updated;

      _logger.info(_module, 'Version added successfully', data: {'scoreId': scoreId});
      return true;
    } catch (e) {
      _logger.error(_module, 'Failed to add version: $e', data: {'scoreId': scoreId});
      return false;
    }
  }

  /// Gets a version by type.
  VersionInfo? getVersion(String scoreId, VersionType type) {
    return _store[scoreId]?.getVersion(type);
  }

  /// Gets the full path for a version file.
  String _getVersionPath(String scoreId, VersionType type) {
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    return '${_versionsDir.path}/$scoreId/${type.label}_$timestamp${type.fileExtension}';
  }

  /// Writes version file to disk.
  Future<void> _writeVersionFile(VersionInfo info, List<int> data) async {
    final file = File(info.filePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data);
  }

  /// Generates a placeholder Score JSON from MusicXML.
  ///
  /// TODO: This should be replaced with actual Module E parser output.
  String _generatePlaceholderScoreJson(String musicXmlContent) {
    return '''{
  "version": "1.0",
  "metadata": {
    "importedFromMusicXml": true,
    "generatedAt": "${DateTime.now().toIso8601String()}"
  },
  "parts": []
}''';
  }
}

/// Extension for string to bytes conversion
extension StringToBytes on String {
  List<int> get utf8 {
    return utf8Encode(this);
  }
}

List<int> utf8Encode(String str) {
  return const Utf8Encoder().convert(str);
}
