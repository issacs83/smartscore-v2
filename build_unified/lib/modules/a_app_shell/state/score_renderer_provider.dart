import 'package:flutter/foundation.dart';

/// Score renderer provider - wraps Module F
class ScoreRendererProvider extends ChangeNotifier {
  final dynamic moduleF; // LayoutEngine instance
  int _currentPage = 0;
  int _totalPages = 1;
  Map<String, dynamic> _currentPageLayout = {};
  String? _lastError;
  bool _isRendering = false;

  ScoreRendererProvider(this.moduleF);

  // Getters
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  Map<String, dynamic> get currentPageLayout => _currentPageLayout;
  String? get lastError => _lastError;
  bool get isRendering => _isRendering;

  /// Render a page
  Future<bool> renderPage(
    Map<String, dynamic> scoreJson,
    int pageNumber,
    Map<String, dynamic> layoutConfig,
  ) async {
    _isRendering = true;
    _lastError = null;
    notifyListeners();

    try {
      if (moduleF == null) {
        throw Exception('Module F not initialized');
      }

      // Get total pages first
      final totalPagesResult = await moduleF.getTotalPages(
        scoreJson,
        layoutConfig,
      );

      if (!totalPagesResult.ok) {
        _lastError = totalPagesResult.error?.message ?? 'Unknown error';
        _isRendering = false;
        notifyListeners();
        return false;
      }

      _totalPages = totalPagesResult.value as int;

      // Validate page number
      if (pageNumber < 0 || pageNumber >= _totalPages) {
        _lastError = 'Page $pageNumber out of range (0-${_totalPages - 1})';
        _isRendering = false;
        notifyListeners();
        return false;
      }

      // Render the page via Module F
      final renderResult = await moduleF.renderPage(
        scoreJson,
        pageNumber,
        layoutConfig,
      );

      if (renderResult.ok) {
        _currentPage = pageNumber;
        _currentPageLayout = renderResult.value as Map<String, dynamic>;
        _lastError = null;
        _isRendering = false;
        notifyListeners();
        return true;
      } else {
        _lastError = renderResult.error?.message ?? 'Render failed';
        _isRendering = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[ScoreRendererProvider] Render error: $e');
      _isRendering = false;
      notifyListeners();
      return false;
    }
  }

  /// Go to next page
  Future<bool> nextPage(
    Map<String, dynamic> scoreJson,
    Map<String, dynamic> layoutConfig,
  ) async {
    if (_currentPage >= _totalPages - 1) {
      return false;
    }
    return renderPage(scoreJson, _currentPage + 1, layoutConfig);
  }

  /// Go to previous page
  Future<bool> previousPage(
    Map<String, dynamic> scoreJson,
    Map<String, dynamic> layoutConfig,
  ) async {
    if (_currentPage <= 0) {
      return false;
    }
    return renderPage(scoreJson, _currentPage - 1, layoutConfig);
  }

  /// Hit test - find element at position
  Future<Map<String, dynamic>?> hitTest(
    Map<String, dynamic> scoreJson,
    double x,
    double y,
    Map<String, dynamic> layoutConfig,
  ) async {
    try {
      if (moduleF == null) {
        return null;
      }

      final result = await moduleF.hitTest(
        scoreJson,
        x,
        y,
        layoutConfig,
      );

      if (result.ok) {
        return result.value as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('[ScoreRendererProvider] Hit test error: $e');
      return null;
    }
  }

  /// Get measure information at page and position
  Future<Map<String, dynamic>?> getMeasureAtPosition(
    Map<String, dynamic> scoreJson,
    double x,
    double y,
  ) async {
    try {
      if (moduleF == null) {
        return null;
      }

      final hitResult = await hitTest(scoreJson, x, y, {});
      if (hitResult != null) {
        return {
          'measureNumber': hitResult['measureNumber'],
          'part': hitResult['part'],
          'staff': hitResult['staff'],
        };
      }
      return null;
    } catch (e) {
      debugPrint('[ScoreRendererProvider] getMeasureAtPosition error: $e');
      return null;
    }
  }

  /// Clear error
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  /// Reset state
  void reset() {
    _currentPage = 0;
    _totalPages = 1;
    _currentPageLayout = {};
    _lastError = null;
    _isRendering = false;
    notifyListeners();
  }

  /// Dump state for debugging
  Map<String, dynamic> dumpState() {
    return {
      'currentPage': _currentPage,
      'totalPages': _totalPages,
      'isRendering': _isRendering,
      'lastError': _lastError,
      'pageLayoutKeys': _currentPageLayout.keys.toList(),
    };
  }
}
