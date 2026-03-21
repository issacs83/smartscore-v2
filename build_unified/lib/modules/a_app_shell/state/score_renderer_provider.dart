import 'package:flutter/foundation.dart';
import '../../e_music_normalizer/score_json.dart' as score_model;
import '../../f_score_renderer/layout_engine.dart' as layout;
import '../../f_score_renderer/models.dart';
import '../../f_score_renderer/render_commands.dart' as render;
import '../../f_score_renderer/hit_test.dart' as hit;

/// Score renderer provider - wraps Module F functions
class ScoreRendererProvider extends ChangeNotifier {
  int _currentPage = 0;
  int _totalPages = 1;
  PageLayout? _currentPageLayout;
  List<RenderCommand> _currentRenderCommands = [];
  String? _lastError;
  bool _isRendering = false;

  ScoreRendererProvider();

  // Getters
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  PageLayout? get currentPageLayout => _currentPageLayout;
  List<RenderCommand> get currentRenderCommands => _currentRenderCommands;
  String? get lastError => _lastError;
  bool get isRendering => _isRendering;

  /// Render a page from a typed Score
  bool renderPage(
    score_model.Score score,
    int partIndex,
    int pageNumber,
    LayoutConfig config,
  ) {
    _isRendering = true;
    _lastError = null;
    notifyListeners();

    try {
      // Get total measures for the part
      if (partIndex < 0 || partIndex >= score.parts.length) {
        _lastError = 'Invalid part index: $partIndex';
        _isRendering = false;
        notifyListeners();
        return false;
      }

      final totalMeasures = score.parts[partIndex].measures.length;
      _totalPages = layout.getTotalPages(totalMeasures, config);

      // Validate page number
      if (pageNumber < 0 || pageNumber >= _totalPages) {
        _lastError = 'Page $pageNumber out of range (0-${_totalPages - 1})';
        _isRendering = false;
        notifyListeners();
        return false;
      }

      // Compute layout
      final pageLayout = layout.computePageLayout(score, partIndex, pageNumber, config);

      // Generate render commands
      final renderState = RenderState(
        currentMeasure: null,
        darkMode: config.darkMode,
      );
      final commands = render.generateRenderCommands(score, pageLayout, renderState);

      _currentPage = pageNumber;
      _currentPageLayout = pageLayout;
      _currentRenderCommands = commands;
      _lastError = null;
      _isRendering = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[ScoreRendererProvider] Render error: $e');
      _isRendering = false;
      notifyListeners();
      return false;
    }
  }

  /// Go to next page
  bool nextPage(
    score_model.Score score,
    int partIndex,
    LayoutConfig config,
  ) {
    if (_currentPage >= _totalPages - 1) {
      return false;
    }
    return renderPage(score, partIndex, _currentPage + 1, config);
  }

  /// Go to previous page
  bool previousPage(
    score_model.Score score,
    int partIndex,
    LayoutConfig config,
  ) {
    if (_currentPage <= 0) {
      return false;
    }
    return renderPage(score, partIndex, _currentPage - 1, config);
  }

  /// Hit test - find element at position
  HitTestResult? performHitTest(double x, double y) {
    if (_currentPageLayout == null) return null;

    try {
      return hit.hitTest(x, y, _currentPageLayout!);
    } catch (e) {
      debugPrint('[ScoreRendererProvider] Hit test error: $e');
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
    _currentPageLayout = null;
    _currentRenderCommands = [];
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
      'hasPageLayout': _currentPageLayout != null,
      'renderCommandCount': _currentRenderCommands.length,
    };
  }
}
