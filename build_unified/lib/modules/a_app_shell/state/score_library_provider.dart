import 'package:flutter/foundation.dart';

/// Score library provider - wraps Module B
class ScoreLibraryProvider extends ChangeNotifier {
  final dynamic moduleB; // ScoreLibrary instance
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

      // Call Module B.getLibrary()
      final result = await moduleB.getLibrary();

      if (result.ok) {
        _allScores = (result.value as List)
            .map((score) => {
                  'id': score.id,
                  'title': score.title,
                  'composer': score.composer ?? '',
                  'sourceType': score.sourceType.toString(),
                  'dateImported': score.dateImported.toIso8601String(),
                  'pageCount': score.pageCount ?? 0,
                  'measureCount': score.measureCount ?? 0,
                })
            .toList();
        _allScores.sort((a, b) =>
            DateTime.parse(b['dateImported'])
                .compareTo(DateTime.parse(a['dateImported'])));
      } else {
        _lastError = result.error?.message ?? 'Unknown error';
        debugPrint('[ScoreLibraryProvider] Load failed: $_lastError');
      }
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

      final result = await moduleB.getScore(scoreId);
      if (result.ok) {
        final score = result.value;
        return {
          'id': score.id,
          'title': score.title,
          'composer': score.composer ?? '',
          'sourceType': score.sourceType.toString(),
          'dateImported': score.dateImported.toIso8601String(),
          'pageCount': score.pageCount ?? 0,
          'measureCount': score.measureCount ?? 0,
          'scoreJson': score.scoreJson, // Raw JSON from Module E
        };
      } else {
        _lastError = result.error?.message ?? 'Unknown error';
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

      final result = await moduleB.deleteScore(scoreId);
      if (result.ok) {
        _allScores.removeWhere((s) => s['id'] == scoreId);
        if (_selectedScoreId == scoreId) {
          _selectedScoreId = null;
        }
        _lastError = null;
        notifyListeners();
        return true;
      } else {
        _lastError = result.error?.message ?? 'Delete failed';
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
