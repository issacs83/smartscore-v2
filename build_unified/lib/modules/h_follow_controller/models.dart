/// Data models for the follow controller.

/// Follow controller state.
enum FollowState { idle, loading, following, paused, error }

/// Current cursor position in the score.
class CursorPosition {
  final int measure;
  final double beat;
  final double confidence;
  final double timeSec;

  const CursorPosition({
    required this.measure,
    required this.beat,
    required this.confidence,
    this.timeSec = 0,
  });

  static const zero = CursorPosition(measure: 1, beat: 1, confidence: 0);

  @override
  String toString() => 'Cursor(m$measure:${beat.toStringAsFixed(1)}, conf=${confidence.toStringAsFixed(2)})';
}

/// Page turn event.
class PageTurnEvent {
  final int fromPage;
  final int toPage;
  final bool isAutomatic;
  final DateTime timestamp;

  PageTurnEvent({
    required this.fromPage,
    required this.toPage,
    required this.isAutomatic,
  }) : timestamp = DateTime.now();
}
