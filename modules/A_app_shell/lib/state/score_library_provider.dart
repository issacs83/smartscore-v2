import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../b_score_input/score_entry.dart';
import '../../b_score_input/score_library.dart';

/// Score library provider - wraps Module B
class ScoreLibraryProvider extends ChangeNotifier {
  final ScoreLibrary? moduleB;
  List<Map<String, dynamic>> _allScores = [];
  String? _selectedScoreId;
  bool _isLoading = false;
  String? _lastError;

  ScoreLibraryProvider(this.moduleB);

  // Getters
  List<Map<String, dynamic>> get allScores => _allScores;
  String? get selectedScoreId => _selectedScoreId;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  /// Load all scores from library
  Future<void> loadLibrary() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      if (moduleB == null) {
        throw Exception('Module B not initialized');
      }

      final results = await moduleB!.getLibrary();
      _allScores = results
          .map((score) => {
                'id': score.id,
                'title': score.title,
                'composer': score.composer ?? '',
                'sourceType': score.sourceType.toString(),
                'dateImported': score.createdAt.toIso8601String(),
                'pageCount': score.versions.length,
                'measureCount': 0,
              })
          .toList();
      _allScores.sort((a, b) =>
          DateTime.parse(b['dateImported'])
              .compareTo(DateTime.parse(a['dateImported'])));
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[ScoreLibraryProvider] Load exception: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Get single score by ID
  Future<Map<String, dynamic>?> getScore(String scoreId) async {
    try {
      if (moduleB == null) {
        throw Exception('Module B not initialized');
      }

      final score = await moduleB!.getScore(scoreId);
      if (score != null) {
        return {
          'id': score.id,
          'title': score.title,
          'composer': score.composer ?? '',
          'sourceType': score.sourceType.toString(),
          'dateImported': score.createdAt.toIso8601String(),
          'pageCount': score.versions.length,
          'measureCount': 0,
        };
      } else {
        _lastError = 'Score not found';
        return null;
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[ScoreLibraryProvider] getScore error: $e');
      return null;
    }
  }

  /// Delete a score
  Future<bool> deleteScore(String scoreId) async {
    try {
      if (moduleB == null) {
        throw Exception('Module B not initialized');
      }

      final result = await moduleB!.deleteScore(scoreId);
      if (result) {
        _allScores.removeWhere((s) => s['id'] == scoreId);
        if (_selectedScoreId == scoreId) {
          _selectedScoreId = null;
        }
        _lastError = null;
        notifyListeners();
        return true;
      } else {
        _lastError = 'Delete failed';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[ScoreLibraryProvider] Delete error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Select a score
  void selectScore(String scoreId) {
    _selectedScoreId = scoreId;
    notifyListeners();
  }

  /// Get image bytes for a score's original image
  Future<Uint8List?> getImageBytes(String scoreId) async {
    try {
      if (moduleB == null) {
        throw Exception('Module B not initialized');
      }

      final score = await moduleB!.getScore(scoreId);
      if (score == null) return null;

      final versionInfo = score.getVersion(VersionType.originalImage);
      if (versionInfo == null) return null;

      final file = File(versionInfo.filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
      return null;
    } catch (e) {
      debugPrint('[ScoreLibraryProvider] getImageBytes error: $e');
      return null;
    }
  }

  /// Clear error
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  /// Dump state for debugging
  Map<String, dynamic> dumpState() {
    return {
      'totalScores': _allScores.length,
      'selectedScoreId': _selectedScoreId,
      'isLoading': _isLoading,
      'lastError': _lastError,
      'scores': _allScores,
    };
  }
}
