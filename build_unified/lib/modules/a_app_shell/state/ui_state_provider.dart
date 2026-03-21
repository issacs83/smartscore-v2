import 'package:flutter/foundation.dart';
import '../config.dart';
import '../../f_score_renderer/models.dart';

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

  /// Get current layout configuration using the models.dart LayoutConfig
  LayoutConfig getLayoutConfig() {
    return LayoutConfig(
      measuresPerSystem: _measuresPerSystem,
      systemsPerPage: _systemsPerPage,
      zoom: _zoomLevel,
      darkMode: _darkMode,
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
