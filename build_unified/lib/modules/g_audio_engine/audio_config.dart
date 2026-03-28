/// Audio engine configuration constants.
class AudioConfig {
  /// FFT size (number of time-domain samples per frame).
  static const int fftSize = 8192;

  /// Hop interval in milliseconds (~84ms = ~12 fps).
  static const int hopMs = 84;

  /// Target sample rate for CENS computation.
  static const int sampleRate = 44100;

  /// Number of chroma bins (pitch classes).
  static const int chromaBins = 12;

  /// CENS smoothing window length (frames).
  static const int censSmoothing = 5;

  /// CENS quantization levels.
  static const int censQuantLevels = 5;

  /// MIDI note range for chroma mapping.
  static const int midiMin = 21;  // A0 (27.5 Hz)
  static const int midiMax = 108; // C8 (4186 Hz)

  /// Pitch class names.
  static const pitchClasses = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];
}
