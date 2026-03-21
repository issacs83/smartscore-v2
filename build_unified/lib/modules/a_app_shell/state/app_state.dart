import 'package:flutter/foundation.dart';

/// Central application state
/// Holds references to all major modules and their states
class AppState extends ChangeNotifier {
  // Module references
  dynamic moduleB; // ScoreLibrary
  dynamic moduleE; // MusicXmlParser
  dynamic moduleF; // LayoutEngine
  dynamic moduleK; // DeviceManager

  // State
  String? _activeScoreId;
  Map<String, dynamic> _currentScoreJson = {};
  int _currentPage = 0;
  List<Map<String, dynamic>> _eventLog = [];
  DateTime _bootTime = DateTime.now();

  // Getters
  String? get activeScoreId => _activeScoreId;
  Map<String, dynamic> get currentScoreJson => _currentScoreJson;
  int get currentPage => _currentPage;
  List<Map<String, dynamic>> get eventLog => _eventLog;
  DateTime get bootTime => _bootTime;

  AppState({
    this.moduleB,
    this.moduleE,
    this.moduleF,
    this.moduleK,
  });

  /// Initialize app state asynchronously
  static Future<AppState> initialize() async {
    debugPrint('[AppState] Initializing...');
    final state = AppState();
    state._bootTime = DateTime.now();
    debugPrint('[AppState] Initialized at ${state._bootTime}');
    return state;
  }

  /// Set the active score
  void setActiveScore(String scoreId, Map<String, dynamic> scoreJson) {
    _activeScoreId = scoreId;
    _currentScoreJson = scoreJson;
    _currentPage = 0;
    _logEvent('score_loaded', {'scoreId': scoreId});
    debugPrint('[AppState] Active score set: $scoreId');
    notifyListeners();
  }

  /// Clear active score
  void clearActiveScore() {
    _activeScoreId = null;
    _currentScoreJson = {};
    _currentPage = 0;
    _logEvent('score_unloaded', {});
    debugPrint('[AppState] Active score cleared');
    notifyListeners();
  }

  /// Navigate to page
  void goToPage(int pageNumber) {
    if (_activeScoreId == null) {
      debugPrint('[AppState] Cannot go to page: no active score');
      return;
    }

    _currentPage = pageNumber;
    _logEvent('page_changed', {'page': pageNumber});
    debugPrint('[AppState] Page changed to $pageNumber');
    notifyListeners();
  }

  /// Next page
  void nextPage() {
    goToPage(_currentPage + 1);
  }

  /// Previous page
  void previousPage() {
    if (_currentPage > 0) {
      goToPage(_currentPage - 1);
    }
  }

  /// Log an event
  void logEvent(String eventType, Map<String, dynamic> data) {
    _logEvent(eventType, data);
  }

  void _logEvent(String eventType, Map<String, dynamic> data) {
    final event = {
      'timestamp': DateTime.now().toIso8601String(),
      'type': eventType,
      'data': data,
    };
    _eventLog.add(event);

    // Keep only last 100 events
    if (_eventLog.length > 100) {
      _eventLog.removeAt(0);
    }

    if (kDebugMode) {
      debugPrint('[AppState] Event: $eventType -> $data');
    }
  }

  /// Dump state for debugging
  Map<String, dynamic> dumpState() {
    return {
      'activeScoreId': _activeScoreId,
      'currentPage': _currentPage,
      'currentScoreJsonKeys': _currentScoreJson.keys.toList(),
      'eventLogLength': _eventLog.length,
      'bootTime': _bootTime.toIso8601String(),
      'uptime': DateTime.now().difference(_bootTime).inMilliseconds,
    };
  }
}
