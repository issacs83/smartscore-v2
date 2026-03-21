import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'import_error.dart';
import 'logger.dart';
import 'result.dart';
import 'score_entry.dart';

const String _module = 'MemoryScoreLibrary';

/// In-memory only score library for web platform.
/// No dart:io dependencies — all data lives in memory.
class MemoryScoreLibrary {
  final Map<String, ScoreEntry> _store = {};
  final Map<String, Uint8List> _fileStore = {};
  final ModuleLogger _logger = ModuleLogger.instance;

  MemoryScoreLibrary();

  /// No-op initialization for web.
  Future<void> initialize() async {
    _logger.info(_module, 'Initialized (in-memory mode for web)');
  }

  /// Import image bytes into memory.
  Future<Result<ScoreEntry, ImportError>> importImage(
    List<int> bytes,
    String fileName,
  ) async {
    _logger.info(_module, 'Importing image (memory)', data: {'fileName': fileName});

    try {
      if (bytes.isEmpty) {
        return Result.failure(ImportError.imageInvalidFormat);
      }

      final title = fileName.replaceAll(
          RegExp(r'\.(jpg|jpeg|png)$', caseSensitive: false), '');
      final entry = ScoreEntry(
        title: title,
        sourceType: SourceType.image,
      );

      final versionInfo = VersionInfo(
        filePath: 'memory://${entry.id}/original',
        createdAt: DateTime.now().toUtc(),
        sizeBytes: bytes.length,
        metadata: {'originalFileName': fileName},
      );

      final updatedEntry =
          entry.addVersion(VersionType.originalImage, versionInfo);

      _store[entry.id] = updatedEntry;
      _fileStore[versionInfo.filePath] = Uint8List.fromList(bytes);

      _logger.info(_module, 'Image imported successfully', data: {
        'scoreId': entry.id,
        'title': title,
      });

      return Result.success(updatedEntry);
    } catch (e) {
      _logger.error(_module, 'Image import failed: $e');
      return Result.failure(ImportError.storageWriteFailed);
    }
  }

  /// Import MusicXML content into memory.
  Future<Result<ScoreEntry, ImportError>> importMusicXml(
    String content, {
    String? fileName,
  }) async {
    _logger.info(_module, 'Importing MusicXML (memory)');

    try {
      final title = fileName?.replaceAll(
              RegExp(r'\.(musicxml|xml)$', caseSensitive: false), '') ??
          'Untitled';
      final entry = ScoreEntry(
        title: title,
        sourceType: SourceType.musicxml,
      );

      final contentBytes = utf8.encode(content);
      final versionInfo = VersionInfo(
        filePath: 'memory://${entry.id}/musicxml',
        createdAt: DateTime.now().toUtc(),
        sizeBytes: contentBytes.length,
        metadata: {'sourceFile': fileName},
      );

      final updatedEntry =
          entry.addVersion(VersionType.omrMusicxml, versionInfo);

      _store[entry.id] = updatedEntry;
      _fileStore[versionInfo.filePath] = Uint8List.fromList(contentBytes);

      return Result.success(updatedEntry);
    } catch (e) {
      _logger.error(_module, 'MusicXML import failed: $e');
      return Result.failure(ImportError.xmlMalformed);
    }
  }

  /// Gets all scores in the library.
  Future<List<ScoreEntry>> getLibrary({
    String? searchQuery,
  }) async {
    var results = _store.values.toList();

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      results = results
          .where((entry) =>
              entry.title.toLowerCase().contains(query) ||
              (entry.composer?.toLowerCase().contains(query) ?? false))
          .toList();
    }

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  /// Gets a score by ID.
  Future<ScoreEntry?> getScore(String scoreId) async {
    return _store[scoreId];
  }

  /// Deletes a score.
  Future<bool> deleteScore(String scoreId) async {
    final entry = _store.remove(scoreId);
    if (entry != null) {
      for (final version in entry.versions.values) {
        _fileStore.remove(version.filePath);
      }
      return true;
    }
    return false;
  }

  /// Gets the number of scores.
  int get scoreCount => _store.length;

  /// Get file bytes from memory store.
  Uint8List? getFileBytes(String filePath) {
    return _fileStore[filePath];
  }

  /// Store file bytes in memory.
  void storeFileBytes(String filePath, Uint8List bytes) {
    _fileStore[filePath] = bytes;
  }
}
