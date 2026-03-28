import 'dart:async';
import 'package:flutter/foundation.dart';

import '../g_audio_engine/audio_capture.dart';
import '../g_audio_engine/cens_extractor.dart';
import '../g_audio_engine/otw_matcher.dart';
import '../g_audio_engine/audio_config.dart';
import '../g_audio_engine/models.dart';
import 'follow_config.dart';
import 'models.dart';

/// Main orchestrator for score following.
///
/// Connects: AudioCapture → CENSExtractor → OTWMatcher → UI state
///
/// Usage:
///   final controller = FollowController();
///   await controller.loadReference(referenceFrames);
///   await controller.start();
///   controller.addListener(() {
///     print('Position: ${controller.cursor}');
///   });
class FollowController extends ChangeNotifier {
  final AudioCapture _audio = AudioCapture();
  CENSExtractor? _cens;
  OTWMatcher? _matcher;
  Timer? _pollTimer;

  // State
  FollowState _state = FollowState.idle;
  CursorPosition _cursor = CursorPosition.zero;
  FollowConfig _config = const FollowConfig();
  double _audioLevel = 0.0;
  int _totalMeasures = 0;
  int _currentPage = 0;
  int _totalPages = 1;

  // Smoothing buffer
  final List<int> _measureHistory = [];

  // Page turn callback
  void Function(PageTurnEvent)? onPageTurn;

  // Measure-to-page mapping
  Map<int, int> _measureToPage = {};

  // ── Getters ──────────────────────────────────────────────────────────

  FollowState get state => _state;
  CursorPosition get cursor => _cursor;
  FollowConfig get config => _config;
  double get audioLevel => _audioLevel;
  int get currentMeasure => _cursor.measure;
  double get confidence => _cursor.confidence;
  bool get isFollowing => _state == FollowState.following;
  int get currentPage => _currentPage;

  // ── Configuration ────────────────────────────────────────────────────

  void updateConfig(FollowConfig config) {
    _config = config;
    notifyListeners();
  }

  // ── Reference Loading ────────────────────────────────────────────────

  /// Load reference features from server response.
  void loadReference(List<ReferenceFrame> frames, {
    int totalMeasures = 0,
    int totalPages = 1,
    Map<int, int>? measureToPage,
  }) {
    _matcher = OTWMatcher(frames);
    _cens = CENSExtractor();
    _totalMeasures = totalMeasures;
    _totalPages = totalPages;
    _measureToPage = measureToPage ?? {};
    _state = FollowState.idle;
    notifyListeners();
    debugPrint('[Follow] Reference loaded: ${frames.length} frames, $totalMeasures measures');
  }

  /// Parse reference frames from server JSON response.
  static List<ReferenceFrame> parseFrames(List<dynamic> framesJson) {
    return framesJson
        .map((f) => ReferenceFrame.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  // ── Start / Stop ─────────────────────────────────────────────────────

  /// Start score following.
  Future<bool> start() async {
    if (_matcher == null) {
      _state = FollowState.error;
      notifyListeners();
      return false;
    }

    _state = FollowState.loading;
    notifyListeners();

    // Initialize audio
    _audio.init();
    final ok = await _audio.start();
    if (!ok) {
      _state = FollowState.error;
      notifyListeners();
      return false;
    }

    // Reset state
    _matcher!.reset();
    _cens!.reset();
    _measureHistory.clear();
    _cursor = CursorPosition.zero;

    // Start polling timer
    _pollTimer = Timer.periodic(
      Duration(milliseconds: AudioConfig.hopMs),
      (_) => _processFrame(),
    );

    _state = FollowState.following;
    notifyListeners();
    debugPrint('[Follow] Started');
    return true;
  }

  /// Pause following (keep audio open).
  void pause() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _state = FollowState.paused;
    notifyListeners();
  }

  /// Resume from pause.
  void resume() {
    if (_state != FollowState.paused || _matcher == null) return;
    _pollTimer = Timer.periodic(
      Duration(milliseconds: AudioConfig.hopMs),
      (_) => _processFrame(),
    );
    _state = FollowState.following;
    notifyListeners();
  }

  /// Stop following and release audio.
  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _audio.stop();
    _state = FollowState.idle;
    _audioLevel = 0;
    notifyListeners();
    debugPrint('[Follow] Stopped');
  }

  /// Manually set position (e.g., user taps on a measure).
  void setPosition(int measure, {double beat = 1.0}) {
    _cursor = CursorPosition(
      measure: measure,
      beat: beat,
      confidence: 1.0,
    );
    _measureHistory.clear();
    // Also reset OTW to search near this position
    // (find nearest reference frame for this measure)
    if (_matcher != null) {
      for (int i = 0; i < _matcher!.referenceLength; i++) {
        final ref = _matcher!.getRefFrame(i);
        if (ref.measure >= measure) {
          _matcher!.reset();
          // Advance matcher to approximately this position
          break;
        }
      }
    }
    notifyListeners();
  }

  // ── Core Processing ──────────────────────────────────────────────────

  void _processFrame() {
    if (_cens == null || _matcher == null) return;

    // Get audio data
    // Option A: Use frequency data from browser (faster, browser does FFT)
    final freqData = _audio.getFrequencyData();
    ChromaVector? chroma;

    if (freqData != null && freqData.isNotEmpty) {
      chroma = _cens!.extractFromFrequencyData(freqData);
    } else {
      // Option B: Use raw PCM buffer (Dart FFT)
      final buffer = _audio.getBuffer();
      if (buffer == null || buffer.isEmpty) return;
      chroma = _cens!.extract(buffer);
    }

    _audioLevel = _audio.level;

    // Run OTW matching
    final match = _matcher!.processFrame(chroma);

    // Apply confidence filter
    if (match.confidence < _config.confidenceThreshold) return;

    // Smoothing: majority vote over recent measures
    _measureHistory.add(match.measure);
    if (_measureHistory.length > _config.smoothingWindow) {
      _measureHistory.removeAt(0);
    }
    final smoothedMeasure = _majorityVote(_measureHistory);

    // Update cursor
    final oldMeasure = _cursor.measure;
    _cursor = CursorPosition(
      measure: smoothedMeasure,
      beat: match.beat,
      confidence: match.confidence,
      timeSec: match.timeSec,
    );

    // Check for page turn
    if (_config.autoPageTurnEnabled && smoothedMeasure != oldMeasure) {
      _checkPageTurn(smoothedMeasure);
    }

    notifyListeners();
  }

  void _checkPageTurn(int measure) {
    final newPage = _measureToPage[measure] ?? _currentPage;
    if (newPage != _currentPage) {
      final event = PageTurnEvent(
        fromPage: _currentPage,
        toPage: newPage,
        isAutomatic: true,
      );
      _currentPage = newPage;
      onPageTurn?.call(event);
      debugPrint('[Follow] Auto page turn: ${event.fromPage} → ${event.toPage}');
    }
  }

  int _majorityVote(List<int> values) {
    if (values.isEmpty) return 1;
    final counts = <int, int>{};
    for (final v in values) {
      counts[v] = (counts[v] ?? 0) + 1;
    }
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
