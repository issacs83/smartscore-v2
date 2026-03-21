import 'package:flutter/foundation.dart';

/// Comparison provider - wraps Module C
class ComparisonProvider extends ChangeNotifier {
  bool _showComparison = false;
  String? _originalJson;
  String? _editedJson;
  List<Map<String, dynamic>> _changes = [];

  // Getters
  bool get showComparison => _showComparison;
  String? get originalJson => _originalJson;
  String? get editedJson => _editedJson;
  List<Map<String, dynamic>> get changes => _changes;

  /// Enable comparison mode
  void enableComparison(String original, String edited) {
    _originalJson = original;
    _editedJson = edited;
    _showComparison = true;
    _computeChanges();
    debugPrint('[ComparisonProvider] Comparison enabled');
    notifyListeners();
  }

  /// Disable comparison mode
  void disableComparison() {
    _showComparison = false;
    _originalJson = null;
    _editedJson = null;
    _changes = [];
    debugPrint('[ComparisonProvider] Comparison disabled');
    notifyListeners();
  }

  /// Toggle comparison visibility
  void toggleComparison() {
    _showComparison = !_showComparison;
    notifyListeners();
  }

  /// Compute changes between original and edited
  void _computeChanges() {
    _changes = [];

    if (_originalJson == null || _editedJson == null) {
      return;
    }

    // Simple diff: count lines that differ
    final originalLines = _originalJson!.split('\n');
    final editedLines = _editedJson!.split('\n');

    int idx = 0;
    while (idx < originalLines.length && idx < editedLines.length) {
      if (originalLines[idx] != editedLines[idx]) {
        _changes.add({
          'type': 'modified',
          'lineNumber': idx + 1,
          'original': originalLines[idx],
          'edited': editedLines[idx],
        });
      }
      idx++;
    }

    // Lines only in original
    while (idx < originalLines.length) {
      _changes.add({
        'type': 'deleted',
        'lineNumber': idx + 1,
        'line': originalLines[idx],
      });
      idx++;
    }

    // Lines only in edited
    while (idx < editedLines.length) {
      _changes.add({
        'type': 'added',
        'lineNumber': idx + 1,
        'line': editedLines[idx],
      });
      idx++;
    }

    debugPrint('[ComparisonProvider] Found ${_changes.length} changes');
  }

  /// Get change summary
  Map<String, int> getChangeSummary() {
    return {
      'added': _changes.where((c) => c['type'] == 'added').length,
      'modified': _changes.where((c) => c['type'] == 'modified').length,
      'deleted': _changes.where((c) => c['type'] == 'deleted').length,
    };
  }

  /// Dump state for debugging
  Map<String, dynamic> dumpState() {
    return {
      'showComparison': _showComparison,
      'hasOriginal': _originalJson != null,
      'hasEdited': _editedJson != null,
      'changeCount': _changes.length,
      'changeSummary': getChangeSummary(),
    };
  }
}
