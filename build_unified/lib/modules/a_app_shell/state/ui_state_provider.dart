import 'package:flutter/foundation.dart';
import '../config.dart';

/// UI state provider for app-level settings
class UIStateProvider extends ChangeNotifier {
  bool _darkMode = false;
  double _zoomLevel = 1.0;
  bool _debugMode = enableDebugMode;
  int _systemsPerPage = 2;
  int _measuresPerSystem = 4;

  // Getters
  bool get darkMode => _darkMode;
  double get zoomLevel => _zoomLevel;
  bool get debugMode => _debugMode;
  int get systemsPerPage => _systemsPerPage;
  int get measuresPerSystem => _measuresPerSystem;

  // Setters
  void setDarkMode(bool value) {
    if (_darkMode != value) {
      _darkMode = value;
      debugPrint('[UIStateProvider] Dark mode set to $value');
      notifyListeners();
    }
  }

  void setZoomLevel(double value) {
    // Clamp zoom to 0.5x - 2.0x
    final clampedValue = value.clamp(0.5, 2.0);
    if (_zoomLevel != clampedValue) {
      _zoomLevel = clampedValue;
      debugPrint('[UIStateProvider] Zoom level set to $clampedValue');
      notifyListeners();
    }
  }

  void setDebugMode(bool value) {
    if (_debugMode != value) {
      _debugMode = value;
      debugPrint('[UIStateProvider] Debug mode set to $value');
      notifyListeners();
    }
  }

  void setSystemsPerPage(int value) {
    if (_systemsPerPage != value) {
      _systemsPerPage = value;
      debugPrint('[UIStateProvider] Systems per page set to $value');
      notifyListeners();
    }
  }

  void setMeasuresPerSystem(int value) {
    if (_measuresPerSystem != value) {
      _measuresPerSystem = value;
      debugPrint('[UIStateProvider] Measures per system set to $value');
      notifyListeners();
    }
  }

  /// Get current layout configuration
  LayoutConfig getLayoutConfig() {
    return LayoutConfig(
      measuresPerSystem: _measuresPerSystem,
      systemsPerPage: _systemsPerPage,
      zoomLevel: _zoomLevel,
    );
  }

  /// Dump state for debugging
  Map<String, dynamic> dumpState() {
    return {
      'darkMode': _darkMode,
      'zoomLevel': _zoomLevel,
      'debugMode': _debugMode,
      'systemsPerPage': _systemsPerPage,
      'measuresPerSystem': _measuresPerSystem,
    };
  }
}

/// Layout configuration
class LayoutConfig {
  final int measuresPerSystem;
  final int systemsPerPage;
  final double zoomLevel;

  // Standard page dimensions (inches)
  final double pageWidth;
  final double pageHeight;

  // Margins (points)
  final double topMargin;
  final double bottomMargin;
  final double leftMargin;
  final double rightMargin;

  LayoutConfig({
    required this.measuresPerSystem,
    required this.systemsPerPage,
    required this.zoomLevel,
    this.pageWidth = 8.5, // Letter width in inches
    this.pageHeight = 11.0, // Letter height in inches
    this.topMargin = 40,
    this.bottomMargin = 40,
    this.leftMargin = 40,
    this.rightMargin = 40,
  });

  /// Convert to JSON for Module F
  Map<String, dynamic> toJson() {
    return {
      'measuresPerSystem': measuresPerSystem,
      'systemsPerPage': systemsPerPage,
      'zoomLevel': zoomLevel,
      'pageWidth': pageWidth,
      'pageHeight': pageHeight,
      'topMargin': topMargin,
      'bottomMargin': bottomMargin,
      'leftMargin': leftMargin,
      'rightMargin': rightMargin,
    };
  }
}
