/// User-tunable configuration for score following.
class FollowConfig {
  /// Minimum confidence to accept OTW match (0.0 - 1.0).
  final double confidenceThreshold;

  /// Number of measures to look ahead for page turn pre-loading.
  final int lookaheadMeasures;

  /// Smoothing window (number of frames for EMA).
  final int smoothingWindow;

  /// Enable automatic page turning.
  final bool autoPageTurnEnabled;

  /// Page turn animation duration in milliseconds.
  final int pageTurnAnimationMs;

  /// User-adjustable latency compensation in milliseconds.
  final double latencyCompensationMs;

  /// Show visual cursor on current measure.
  final bool showCursor;

  /// Show confidence indicator (debug).
  final bool showConfidenceIndicator;

  const FollowConfig({
    this.confidenceThreshold = 0.4,
    this.lookaheadMeasures = 2,
    this.smoothingWindow = 5,
    this.autoPageTurnEnabled = true,
    this.pageTurnAnimationMs = 300,
    this.latencyCompensationMs = 0,
    this.showCursor = true,
    this.showConfidenceIndicator = false,
  });

  FollowConfig copyWith({
    double? confidenceThreshold,
    int? lookaheadMeasures,
    int? smoothingWindow,
    bool? autoPageTurnEnabled,
    int? pageTurnAnimationMs,
    double? latencyCompensationMs,
    bool? showCursor,
    bool? showConfidenceIndicator,
  }) {
    return FollowConfig(
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      lookaheadMeasures: lookaheadMeasures ?? this.lookaheadMeasures,
      smoothingWindow: smoothingWindow ?? this.smoothingWindow,
      autoPageTurnEnabled: autoPageTurnEnabled ?? this.autoPageTurnEnabled,
      pageTurnAnimationMs: pageTurnAnimationMs ?? this.pageTurnAnimationMs,
      latencyCompensationMs: latencyCompensationMs ?? this.latencyCompensationMs,
      showCursor: showCursor ?? this.showCursor,
      showConfidenceIndicator: showConfidenceIndicator ?? this.showConfidenceIndicator,
    );
  }
}
