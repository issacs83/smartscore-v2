import 'dart:math' as math;
import 'dart:typed_data';

import 'audio_config.dart';
import 'models.dart';

/// CENS (Chroma Energy Normalized Statistics) feature extractor.
///
/// Converts raw PCM audio buffer into a 12-dimensional chroma vector.
/// Pipeline: Window → FFT → Power Spectrum → Chroma Bins → Normalize →
///           Quantize → Smooth → L2 Normalize
class CENSExtractor {
  final int _fftSize;
  final int _sampleRate;
  final Float64List _hannWindow;
  final List<List<double>> _smoothBuffer = [];

  CENSExtractor({
    int fftSize = AudioConfig.fftSize,
    int sampleRate = AudioConfig.sampleRate,
  })  : _fftSize = fftSize,
        _sampleRate = sampleRate,
        _hannWindow = _createHannWindow(fftSize);

  /// Extract CENS chroma vector from PCM samples.
  ChromaVector extract(List<double> samples) {
    // 1. Apply Hann window
    final windowed = _applyWindow(samples);

    // 2. FFT → power spectrum
    final spectrum = _fft(windowed);

    // 3. Map to 12 chroma bins
    final chroma = _spectrumToChroma(spectrum);

    // 4. L1 normalize
    _l1Normalize(chroma);

    // 5. Quantize to discrete levels
    _quantize(chroma, AudioConfig.censQuantLevels);

    // 6. Smooth (rolling mean over window)
    _smoothBuffer.add(List.from(chroma));
    if (_smoothBuffer.length > AudioConfig.censSmoothing) {
      _smoothBuffer.removeAt(0);
    }
    final smoothed = _smooth();

    // 7. L2 normalize
    _l2Normalize(smoothed);

    return ChromaVector(smoothed);
  }

  /// Extract chroma directly from frequency-domain data (browser FFT).
  /// This skips steps 1-2 (the browser already did FFT via AnalyserNode).
  ChromaVector extractFromFrequencyData(List<double> freqDataDb) {
    // Convert dB to linear power
    final power = List<double>.generate(
      freqDataDb.length,
      (i) => math.pow(10, freqDataDb[i] / 10).toDouble(),
    );

    // 3. Map to chroma bins
    final chroma = _spectrumToChromaFromPower(power, freqDataDb.length);

    // 4-7. Same normalization pipeline
    _l1Normalize(chroma);
    _quantize(chroma, AudioConfig.censQuantLevels);
    _smoothBuffer.add(List.from(chroma));
    if (_smoothBuffer.length > AudioConfig.censSmoothing) {
      _smoothBuffer.removeAt(0);
    }
    final smoothed = _smooth();
    _l2Normalize(smoothed);

    return ChromaVector(smoothed);
  }

  /// Reset smoothing buffer (call when starting a new capture session).
  void reset() => _smoothBuffer.clear();

  // ── Private helpers ──────────────────────────────────────────────────

  Float64List _applyWindow(List<double> samples) {
    final n = math.min(samples.length, _fftSize);
    final result = Float64List(_fftSize);
    for (int i = 0; i < n; i++) {
      result[i] = samples[i] * _hannWindow[i];
    }
    return result;
  }

  /// Radix-2 Cooley-Tukey FFT. Returns magnitude spectrum (N/2 + 1 bins).
  List<double> _fft(Float64List input) {
    final n = input.length;
    // Bit-reversal permutation
    final real = Float64List(n);
    final imag = Float64List(n);
    for (int i = 0; i < n; i++) {
      real[_bitReverse(i, n)] = input[i];
    }

    // FFT butterfly
    for (int size = 2; size <= n; size *= 2) {
      final halfSize = size ~/ 2;
      final angle = -2.0 * math.pi / size;
      for (int i = 0; i < n; i += size) {
        for (int j = 0; j < halfSize; j++) {
          final wr = math.cos(angle * j);
          final wi = math.sin(angle * j);
          final tr = real[i + j + halfSize] * wr - imag[i + j + halfSize] * wi;
          final ti = real[i + j + halfSize] * wi + imag[i + j + halfSize] * wr;
          real[i + j + halfSize] = real[i + j] - tr;
          imag[i + j + halfSize] = imag[i + j] - ti;
          real[i + j] += tr;
          imag[i + j] += ti;
        }
      }
    }

    // Magnitude spectrum (first half + DC)
    final halfN = n ~/ 2 + 1;
    return List<double>.generate(halfN, (i) {
      return real[i] * real[i] + imag[i] * imag[i]; // power spectrum
    });
  }

  int _bitReverse(int x, int n) {
    int bits = 0;
    int temp = n;
    while (temp > 1) {
      bits++;
      temp >>= 1;
    }
    int result = 0;
    for (int i = 0; i < bits; i++) {
      result = (result << 1) | (x & 1);
      x >>= 1;
    }
    return result;
  }

  /// Map FFT power spectrum to 12 chroma bins.
  List<double> _spectrumToChroma(List<double> powerSpectrum) {
    final chroma = List<double>.filled(12, 0.0);
    final binFreqRes = _sampleRate / _fftSize;

    for (int bin = 1; bin < powerSpectrum.length; bin++) {
      final freq = bin * binFreqRes;
      if (freq < 27.5 || freq > 4200) continue; // A0 to C8

      // Frequency to pitch class: 12 * log2(f / C0)
      final midiNote = 69 + 12 * _log2(freq / 440.0);
      if (midiNote < AudioConfig.midiMin || midiNote > AudioConfig.midiMax) {
        continue;
      }
      final pitchClass = midiNote.round() % 12;
      chroma[pitchClass] += powerSpectrum[bin];
    }
    return chroma;
  }

  /// Map power array (from browser FFT) to 12 chroma bins.
  List<double> _spectrumToChromaFromPower(List<double> power, int nBins) {
    final chroma = List<double>.filled(12, 0.0);
    // AnalyserNode fftSize/2 bins, frequency resolution = sampleRate / fftSize
    final binFreqRes = _sampleRate / (_fftSize);

    for (int bin = 1; bin < nBins; bin++) {
      final freq = bin * binFreqRes;
      if (freq < 27.5 || freq > 4200) continue;
      final midiNote = 69 + 12 * _log2(freq / 440.0);
      if (midiNote < AudioConfig.midiMin || midiNote > AudioConfig.midiMax) {
        continue;
      }
      final pitchClass = midiNote.round() % 12;
      chroma[pitchClass] += power[bin];
    }
    return chroma;
  }

  double _log2(double x) => math.log(x) / math.ln2;

  void _l1Normalize(List<double> v) {
    double sum = 0;
    for (final x in v) sum += x.abs();
    if (sum > 1e-10) {
      for (int i = 0; i < v.length; i++) v[i] /= sum;
    }
  }

  void _quantize(List<double> v, int levels) {
    for (int i = 0; i < v.length; i++) {
      v[i] = (v[i] * (levels - 1)).roundToDouble();
    }
  }

  List<double> _smooth() {
    final result = List<double>.filled(12, 0.0);
    for (final frame in _smoothBuffer) {
      for (int i = 0; i < 12; i++) result[i] += frame[i];
    }
    final n = _smoothBuffer.length;
    if (n > 0) {
      for (int i = 0; i < 12; i++) result[i] /= n;
    }
    return result;
  }

  void _l2Normalize(List<double> v) {
    double sum = 0;
    for (final x in v) sum += x * x;
    final norm = math.sqrt(sum);
    if (norm > 1e-10) {
      for (int i = 0; i < v.length; i++) v[i] /= norm;
    }
  }

  static Float64List _createHannWindow(int size) {
    final w = Float64List(size);
    for (int i = 0; i < size; i++) {
      w[i] = 0.5 * (1 - math.cos(2 * math.pi * i / (size - 1)));
    }
    return w;
  }
}
