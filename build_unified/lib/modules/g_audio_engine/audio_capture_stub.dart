/// Stub implementation for non-web platforms.
/// Will be replaced with native audio capture in Phase 5.
class AudioCapture {
  bool init() => false;
  Future<bool> start() async => false;
  void stop() {}
  List<double>? getBuffer() => null;
  List<double>? getFrequencyData() => null;
  double get level => 0.0;
  bool get hasPermission => false;
  bool get isCapturing => false;
  int get sampleRate => 0;
}
