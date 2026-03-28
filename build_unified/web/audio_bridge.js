/**
 * SmartScore Audio Bridge — Web Audio API capture for score following.
 *
 * Provides microphone capture via AnalyserNode, with PCM buffer
 * polling for Dart FFI/JS interop.
 *
 * Usage from Dart (via dart:js):
 *   js.context.callMethod('audioInit');
 *   js.context.callMethod('audioStart');
 *   var buffer = js.context.callMethod('audioGetBuffer');
 *   var level = js.context.callMethod('audioGetLevel');
 *   js.context.callMethod('audioStop');
 */

let _audioContext = null;
let _analyserNode = null;
let _sourceNode = null;
let _mediaStream = null;
let _bufferData = null;
let _isCapturing = false;
let _hasPermission = false;
let _audioLevel = 0.0;

const BUFFER_SIZE = 8192;
const POLL_INTERVAL_MS = 84; // ~12 fps, matches CENS hop length

/**
 * Initialize audio context (call once).
 */
function audioInit() {
  if (_audioContext) return true;
  try {
    _audioContext = new (window.AudioContext || window.webkitAudioContext)({
      sampleRate: 44100,
    });
    _bufferData = new Float32Array(BUFFER_SIZE);
    console.log('[AudioBridge] Initialized, sampleRate:', _audioContext.sampleRate);
    return true;
  } catch (e) {
    console.error('[AudioBridge] Init failed:', e);
    return false;
  }
}

/**
 * Request microphone permission and start capturing.
 */
async function audioStart() {
  if (_isCapturing) return true;

  if (!_audioContext) audioInit();

  // Resume context if suspended (browser autoplay policy)
  if (_audioContext.state === 'suspended') {
    await _audioContext.resume();
  }

  try {
    // Request microphone with minimal processing for clean piano capture
    _mediaStream = await navigator.mediaDevices.getUserMedia({
      audio: {
        echoCancellation: false,
        noiseSuppression: false,
        autoGainControl: false,
        channelCount: 1,
      }
    });

    _hasPermission = true;

    // Create source from microphone
    _sourceNode = _audioContext.createMediaStreamSource(_mediaStream);

    // Create analyser for FFT/buffer access
    _analyserNode = _audioContext.createAnalyser();
    _analyserNode.fftSize = BUFFER_SIZE;
    _analyserNode.smoothingTimeConstant = 0.0; // No smoothing for accurate chroma

    // Connect: mic → analyser (no output to speakers to avoid feedback)
    _sourceNode.connect(_analyserNode);

    _isCapturing = true;
    console.log('[AudioBridge] Capturing started');
    return true;

  } catch (e) {
    console.error('[AudioBridge] Start failed:', e);
    _hasPermission = false;
    return false;
  }
}

/**
 * Stop capturing and release microphone.
 */
function audioStop() {
  if (_sourceNode) {
    _sourceNode.disconnect();
    _sourceNode = null;
  }
  if (_mediaStream) {
    _mediaStream.getTracks().forEach(track => track.stop());
    _mediaStream = null;
  }
  _analyserNode = null;
  _isCapturing = false;
  _audioLevel = 0.0;
  console.log('[AudioBridge] Stopped');
}

/**
 * Get current audio buffer (time-domain PCM samples).
 * Returns a JS array of float32 values [-1.0, 1.0].
 */
function audioGetBuffer() {
  if (!_isCapturing || !_analyserNode) return null;

  _analyserNode.getFloatTimeDomainData(_bufferData);

  // Calculate RMS level
  let sum = 0;
  for (let i = 0; i < _bufferData.length; i++) {
    sum += _bufferData[i] * _bufferData[i];
  }
  _audioLevel = Math.sqrt(sum / _bufferData.length);

  // Return as regular array (Dart can read this via JS interop)
  return Array.from(_bufferData);
}

/**
 * Get frequency-domain data (magnitude spectrum).
 * Returns array of float32 values in dB.
 * This is useful if we want to skip client-side FFT
 * and use the browser's native FFT implementation.
 */
function audioGetFrequencyData() {
  if (!_isCapturing || !_analyserNode) return null;

  const freqData = new Float32Array(_analyserNode.frequencyBinCount);
  _analyserNode.getFloatFrequencyData(freqData);
  return Array.from(freqData);
}

/**
 * Get current audio level (RMS, 0.0 to ~1.0).
 */
function audioGetLevel() {
  return _audioLevel;
}

/**
 * Check if microphone permission has been granted.
 */
function audioHasPermission() {
  return _hasPermission;
}

/**
 * Check if currently capturing.
 */
function audioIsCapturing() {
  return _isCapturing;
}

/**
 * Get audio context sample rate.
 */
function audioGetSampleRate() {
  return _audioContext ? _audioContext.sampleRate : 0;
}
