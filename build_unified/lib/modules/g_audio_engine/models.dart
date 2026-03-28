/// Data models for the audio engine.

/// 12-dimensional chroma vector (pitch class energy distribution).
/// Order: C, C#, D, D#, E, F, F#, G, G#, A, A#, B
class ChromaVector {
  final List<double> values; // length 12

  const ChromaVector(this.values);

  double operator [](int i) => values[i];
  int get length => values.length;

  /// Cosine distance: 1 - (u · v) / (|u| * |v|)
  double cosineDistance(ChromaVector other) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < 12; i++) {
      dot += values[i] * other.values[i];
      normA += values[i] * values[i];
      normB += other.values[i] * other.values[i];
    }
    final denom = _sqrt(normA) * _sqrt(normB);
    if (denom < 1e-10) return 1.0;
    return 1.0 - (dot / denom);
  }

  static double _sqrt(double v) {
    if (v <= 0) return 0;
    double x = v;
    for (int i = 0; i < 10; i++) {
      x = (x + v / x) / 2;
    }
    return x;
  }

  @override
  String toString() =>
      'Chroma(${values.map((v) => v.toStringAsFixed(2)).join(', ')})';
}

/// A single reference frame with chroma + musical position.
class ReferenceFrame {
  final int index;
  final double timeSec;
  final int measure;
  final double beat;
  final ChromaVector chroma;

  const ReferenceFrame({
    required this.index,
    required this.timeSec,
    required this.measure,
    required this.beat,
    required this.chroma,
  });

  factory ReferenceFrame.fromJson(Map<String, dynamic> json) {
    return ReferenceFrame(
      index: json['index'] as int,
      timeSec: (json['time_sec'] as num).toDouble(),
      measure: json['measure'] as int,
      beat: (json['beat'] as num).toDouble(),
      chroma: ChromaVector(
        (json['chroma'] as List).map((v) => (v as num).toDouble()).toList(),
      ),
    );
  }
}

/// Result of OTW matching for a single live frame.
class MatchResult {
  final int refIndex;      // matched reference frame index
  final int measure;       // musical measure number
  final double beat;       // beat within measure
  final double timeSec;    // estimated time position
  final double confidence; // match confidence (0.0 - 1.0)
  final double cost;       // accumulated cost (lower = better)

  const MatchResult({
    required this.refIndex,
    required this.measure,
    required this.beat,
    required this.timeSec,
    required this.confidence,
    required this.cost,
  });

  @override
  String toString() =>
      'Match(m$measure:${beat.toStringAsFixed(1)}, conf=${confidence.toStringAsFixed(2)})';
}

/// Audio engine state.
enum AudioState { idle, initializing, capturing, error }
