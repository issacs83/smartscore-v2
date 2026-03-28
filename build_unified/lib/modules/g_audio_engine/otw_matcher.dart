import 'dart:math' as math;

import 'models.dart';

/// Online Time Warping (OTW) score follower.
///
/// Implements Dixon's OTW variant for real-time alignment of live audio
/// to a pre-computed reference feature sequence.
///
/// Based on:
/// - Dixon, S. "Live tracking of musical performances using On-line
///   Time Warping" (DAFx 2005)
/// - Caren & Egozy, "Real-time In-browser Time Warping for Live
///   Score Following" (WAC 2024)
///
/// Usage:
///   final matcher = OTWMatcher(referenceFrames);
///   // For each live audio frame:
///   final result = matcher.processFrame(liveChromaVector);
///   print('Position: measure ${result.measure}, beat ${result.beat}');
class OTWMatcher {
  final List<ReferenceFrame> _reference;

  /// Search window size (reference frames to check per live frame).
  final int searchWindow;

  /// Maximum consecutive steps in one direction before forcing diagonal.
  final int maxRunCount;

  /// Diagonal step weight (lower = prefer diagonal = smoother tracking).
  final double diagonalWeight;

  // OTW state
  late List<double> _prevColumn;
  late List<double> _currColumn;
  int _liveIndex = 0;
  int _bestRefIndex = 0;
  int _runCount = 0;
  int _lastDirection = 0; // 0=diagonal, 1=horizontal, 2=vertical

  OTWMatcher(
    this._reference, {
    this.searchWindow = 300,
    this.maxRunCount = 3,
    this.diagonalWeight = 0.4,
  }) {
    reset();
  }

  /// Reset matcher state (call when restarting following).
  void reset() {
    final n = _reference.length;
    _prevColumn = List<double>.filled(n, double.infinity);
    _currColumn = List<double>.filled(n, double.infinity);
    _prevColumn[0] = 0;
    _liveIndex = 0;
    _bestRefIndex = 0;
    _runCount = 0;
    _lastDirection = 0;
  }

  /// Number of reference frames.
  int get referenceLength => _reference.length;

  /// Current estimated position in the reference.
  int get currentRefIndex => _bestRefIndex;

  /// Process one live chroma frame and return match result.
  MatchResult processFrame(ChromaVector liveChroma) {
    final n = _reference.length;
    _liveIndex++;

    // Compute search range (avoid scanning entire reference)
    final lo = math.max(0, _bestRefIndex - searchWindow ~/ 2);
    final hi = math.min(n, _bestRefIndex + searchWindow ~/ 2);

    // Initialize current column
    for (int j = 0; j < n; j++) {
      _currColumn[j] = double.infinity;
    }

    double bestCost = double.infinity;
    int bestJ = _bestRefIndex;

    for (int j = lo; j < hi; j++) {
      // Cost of aligning live frame _liveIndex with reference frame j
      final dist = liveChroma.cosineDistance(_reference[j].chroma);

      // Three possible predecessors:
      // 1. Diagonal (i-1, j-1) — both advance
      // 2. Horizontal (i-1, j) — live advances, ref stays (insertion)
      // 3. Vertical (i, j-1) — ref advances, live stays (deletion)
      double diagCost = (j > 0 && _prevColumn[j - 1] < double.infinity)
          ? _prevColumn[j - 1] + dist * diagonalWeight
          : double.infinity;

      double horizCost = (_prevColumn[j] < double.infinity)
          ? _prevColumn[j] + dist
          : double.infinity;

      double vertCost = (j > 0 && _currColumn[j - 1] < double.infinity)
          ? _currColumn[j - 1] + dist
          : double.infinity;

      // Apply run count constraint (prevent getting stuck)
      if (_runCount >= maxRunCount) {
        if (_lastDirection == 1) horizCost = double.infinity; // block horizontal
        if (_lastDirection == 2) vertCost = double.infinity;  // block vertical
      }

      // Find minimum
      double minCost = diagCost;
      int direction = 0;
      if (horizCost < minCost) {
        minCost = horizCost;
        direction = 1;
      }
      if (vertCost < minCost) {
        minCost = vertCost;
        direction = 2;
      }

      _currColumn[j] = minCost;

      if (minCost < bestCost) {
        bestCost = minCost;
        bestJ = j;

        // Update run count
        if (direction == _lastDirection && direction != 0) {
          _runCount++;
        } else {
          _runCount = 0;
          _lastDirection = direction;
        }
      }
    }

    // Enforce monotonicity: don't go backward
    if (bestJ < _bestRefIndex) {
      bestJ = _bestRefIndex;
    }
    _bestRefIndex = bestJ;

    // Swap columns
    final temp = _prevColumn;
    _prevColumn = _currColumn;
    _currColumn = temp;

    // Build result
    final ref = _reference[_bestRefIndex.clamp(0, n - 1)];
    final avgCost = bestCost / math.max(_liveIndex, 1);
    // Confidence: inverse of average cost, clamped to [0, 1]
    final confidence = (1.0 - avgCost.clamp(0.0, 1.0));

    return MatchResult(
      refIndex: _bestRefIndex,
      measure: ref.measure,
      beat: ref.beat,
      timeSec: ref.timeSec,
      confidence: confidence,
      cost: bestCost,
    );
  }

  /// Get the reference frame at a given index.
  ReferenceFrame getRefFrame(int index) =>
      _reference[index.clamp(0, _reference.length - 1)];
}
