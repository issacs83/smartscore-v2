import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/restoration_service.dart';

/// State of the restoration process
enum RestorationState {
  idle,
  loading,
  success,
  error,
}

/// Comparison mode for the restoration screen
enum ComparisonMode {
  original,
  restored,
  comparison,
  quality,
}

/// ChangeNotifier that manages Module C restoration state
class RestorationProvider extends ChangeNotifier {
  final RestorationService _service;

  RestorationState _state = RestorationState.idle;
  RestorationResult? _result;
  Uint8List? _originalImageBytes;
  Uint8List? _binaryImageBytes;
  Uint8List? _grayscaleImageBytes;
  ComparisonMode _comparisonMode = ComparisonMode.original;
  RestorationOptions _options = const RestorationOptions();
  String? _errorMessage;
  String? _errorCode;
  bool _showBinary = true;

  RestorationProvider({RestorationService? service})
      : _service = service ?? RestorationService();

  // Getters
  RestorationState get state => _state;
  RestorationResult? get result => _result;
  Uint8List? get originalImageBytes => _originalImageBytes;
  Uint8List? get binaryImageBytes => _binaryImageBytes;
  Uint8List? get grayscaleImageBytes => _grayscaleImageBytes;
  ComparisonMode get comparisonMode => _comparisonMode;
  RestorationOptions get options => _options;
  String? get errorMessage => _errorMessage;
  String? get errorCode => _errorCode;
  bool get showBinary => _showBinary;
  bool get isLoading => _state == RestorationState.loading;
  bool get hasResult => _state == RestorationState.success && _result != null;

  /// Get the currently displayed restored image bytes
  Uint8List? get currentRestoredBytes =>
      _showBinary ? _binaryImageBytes : _grayscaleImageBytes;

  /// Set comparison mode
  void setComparisonMode(ComparisonMode mode) {
    _comparisonMode = mode;
    notifyListeners();
  }

  /// Toggle between binary and grayscale
  void toggleBinaryGrayscale() {
    _showBinary = !_showBinary;
    notifyListeners();
  }

  /// Update restoration options
  void updateOptions(RestorationOptions newOptions) {
    _options = newOptions;
    notifyListeners();
  }

  /// Set original image bytes
  void setOriginalImage(Uint8List bytes) {
    _originalImageBytes = bytes;
    notifyListeners();
  }

  /// Start restoration process
  Future<void> startRestoration(
    Uint8List imageBytes,
    String fileName,
  ) async {
    _originalImageBytes = imageBytes;
    _state = RestorationState.loading;
    _errorMessage = null;
    _errorCode = null;
    _result = null;
    _binaryImageBytes = null;
    _grayscaleImageBytes = null;
    notifyListeners();

    try {
      final result = await _service.restoreImage(
        imageBytes,
        fileName,
        options: _options,
      );

      if (!result.success) {
        _state = RestorationState.error;
        _errorMessage = result.failureReason ?? '복원에 실패했습니다.';
        _errorCode = result.failureCode;
        _result = result;
        notifyListeners();
        return;
      }

      _result = result;

      // Download result images
      await downloadResults(result);

      _state = RestorationState.success;
      _comparisonMode = ComparisonMode.comparison;
      debugPrint(
        '[RestorationProvider] Restoration complete. '
        'Quality: ${result.qualityScore}',
      );
      notifyListeners();
    } on RestorationException catch (e) {
      _state = RestorationState.error;
      _errorMessage = e.message;
      _errorCode = e.failureCode;
      debugPrint('[RestorationProvider] Restoration error: $e');
      notifyListeners();
    } catch (e) {
      _state = RestorationState.error;
      _errorMessage = '예상치 못한 오류가 발생했습니다: $e';
      debugPrint('[RestorationProvider] Unexpected error: $e');
      notifyListeners();
    }
  }

  /// Download result images from the server
  Future<void> downloadResults(RestorationResult result) async {
    final binaryPath = result.outputImages['binary'];
    final grayscalePath = result.outputImages['grayscale'];

    if (binaryPath != null && binaryPath.isNotEmpty) {
      try {
        _binaryImageBytes = await _service.downloadImage(binaryPath);
      } catch (e) {
        debugPrint('[RestorationProvider] Failed to download binary: $e');
      }
    }

    if (grayscalePath != null && grayscalePath.isNotEmpty) {
      try {
        _grayscaleImageBytes = await _service.downloadImage(grayscalePath);
      } catch (e) {
        debugPrint('[RestorationProvider] Failed to download grayscale: $e');
      }
    }
  }

  /// Retry restoration with current options
  Future<void> retry() async {
    if (_originalImageBytes == null) {
      _errorMessage = '원본 이미지가 없습니다.';
      _state = RestorationState.error;
      notifyListeners();
      return;
    }

    await startRestoration(_originalImageBytes!, 'retry_image.jpg');
  }

  /// Check server health
  Future<bool> checkServerHealth() async {
    return _service.checkHealth();
  }

  /// Reset state
  void reset() {
    _state = RestorationState.idle;
    _result = null;
    _originalImageBytes = null;
    _binaryImageBytes = null;
    _grayscaleImageBytes = null;
    _comparisonMode = ComparisonMode.original;
    _errorMessage = null;
    _errorCode = null;
    _showBinary = true;
    notifyListeners();
  }

  /// Dump state for debugging
  Map<String, dynamic> dumpState() {
    return {
      'state': _state.name,
      'hasResult': _result != null,
      'hasOriginalImage': _originalImageBytes != null,
      'hasBinaryImage': _binaryImageBytes != null,
      'hasGrayscaleImage': _grayscaleImageBytes != null,
      'comparisonMode': _comparisonMode.name,
      'showBinary': _showBinary,
      'qualityScore': _result?.qualityScore,
      'errorMessage': _errorMessage,
      'errorCode': _errorCode,
    };
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
