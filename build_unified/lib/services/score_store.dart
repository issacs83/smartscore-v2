import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

/// Persistent score storage using Hive (IndexedDB on web, file on mobile).
///
/// Stores imported/scanned scores with their MusicXML and optional PNG.
/// Survives page refreshes and app restarts.
class ScoreStore {
  static const _boxName = 'scores';
  static const _pngBoxName = 'score_pngs';
  static const _counterKey = '__next_id';

  static Box<Map>? _box;
  static Box<String>? _pngBox;
  static bool _initialized = false;

  /// Initialize Hive. Call once in main().
  static Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<Map>(_boxName);
    _pngBox = await Hive.openBox<String>(_pngBoxName);
    _initialized = true;
    debugPrint('[ScoreStore] Initialized: ${_box!.length} scores');
  }

  /// Add a new imported score. Returns generated score ID.
  static String addScore(String title, String xml, {String? pngBase64}) {
    final box = _box!;
    // Monotonically increasing counter to avoid ID collision
    final nextId = (box.get(_counterKey)?['value'] as int?) ?? 0;
    final id = 'import_$nextId';
    box.put(_counterKey, {'value': nextId + 1});
    box.put(id, {'title': title, 'xml': xml});
    if (pngBase64 != null) {
      _pngBox!.put(id, pngBase64);
    }
    debugPrint('[ScoreStore] Added "$title" as $id');
    return id;
  }

  /// Get MusicXML for a score.
  static String? getXml(String scoreId) {
    return (_box?.get(scoreId) as Map?)?['xml'] as String?;
  }

  /// Get title for a score.
  static String getTitle(String scoreId) {
    return (_box?.get(scoreId) as Map?)?['title'] as String? ?? scoreId;
  }

  /// Get rendered PNG (base64) for a score.
  static String? getRenderedPng(String scoreId) {
    return _pngBox?.get(scoreId);
  }

  /// Set rendered PNG for a score.
  static void setRenderedPng(String scoreId, String pngBase64) {
    _pngBox?.put(scoreId, pngBase64);
  }

  /// Check if a score exists.
  static bool exists(String scoreId) {
    return _box?.containsKey(scoreId) ?? false;
  }

  /// Delete a score.
  static void delete(String scoreId) {
    _box?.delete(scoreId);
    _pngBox?.delete(scoreId);
  }

  /// All imported score IDs (excluding counter key).
  static List<String> get allIds {
    if (_box == null) return [];
    return _box!.keys
        .where((k) => k is String && k != _counterKey)
        .cast<String>()
        .toList();
  }

  /// All imported scores as {id: {title, xml}}.
  static Map<String, Map<String, String>> get allImported {
    if (_box == null) return {};
    final result = <String, Map<String, String>>{};
    for (final key in allIds) {
      final data = _box!.get(key);
      if (data != null) {
        result[key as String] = {
          'title': (data['title'] as String?) ?? key,
          'xml': (data['xml'] as String?) ?? '',
        };
      }
    }
    return result;
  }

  /// Check if a scoreId is an imported (user) score.
  static bool isImported(String scoreId) {
    return scoreId.startsWith('import_') && exists(scoreId);
  }
}
