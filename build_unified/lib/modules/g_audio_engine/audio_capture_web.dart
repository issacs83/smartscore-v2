// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

/// Web implementation of audio capture using Web Audio API.
/// Communicates with audio_bridge.js via JS interop.
class AudioCapture {
  bool _initialized = false;

  /// Initialize audio context.
  bool init() {
    if (_initialized) return true;
    final result = js.context.callMethod('audioInit') as bool? ?? false;
    _initialized = result;
    return result;
  }

  /// Start microphone capture (async, requests permission).
  Future<bool> start() async {
    if (!_initialized) init();
    // audioStart is async in JS, but dart:js doesn't support await on JS promises
    // Use a workaround: call and poll for result
    js.context.callMethod('audioStart');
    // Wait briefly for permission dialog
    await Future.delayed(const Duration(milliseconds: 500));
    return isCapturing;
  }

  /// Stop capturing and release microphone.
  void stop() {
    js.context.callMethod('audioStop');
  }

  /// Get current PCM buffer (time-domain samples).
  /// Returns list of float values [-1.0, 1.0], or null if not capturing.
  List<double>? getBuffer() {
    final result = js.context.callMethod('audioGetBuffer');
    if (result == null) return null;
    // Convert JS array to Dart list
    final jsArray = result as js.JsArray;
    return List<double>.generate(
      jsArray.length,
      (i) => (jsArray[i] as num).toDouble(),
    );
  }

  /// Get frequency-domain data (magnitude spectrum in dB).
  /// Uses browser's native FFT — faster than Dart FFT.
  List<double>? getFrequencyData() {
    final result = js.context.callMethod('audioGetFrequencyData');
    if (result == null) return null;
    final jsArray = result as js.JsArray;
    return List<double>.generate(
      jsArray.length,
      (i) => (jsArray[i] as num).toDouble(),
    );
  }

  /// Current audio level (RMS, 0.0 to ~1.0).
  double get level =>
      (js.context.callMethod('audioGetLevel') as num?)?.toDouble() ?? 0.0;

  /// Whether microphone permission was granted.
  bool get hasPermission =>
      js.context.callMethod('audioHasPermission') as bool? ?? false;

  /// Whether currently capturing audio.
  bool get isCapturing =>
      js.context.callMethod('audioIsCapturing') as bool? ?? false;

  /// Audio context sample rate.
  int get sampleRate =>
      (js.context.callMethod('audioGetSampleRate') as num?)?.toInt() ?? 0;
}
