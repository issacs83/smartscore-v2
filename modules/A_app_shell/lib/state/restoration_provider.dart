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
  bool _imageSizeWarning = false;
  String? _imageSizeInfo;

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

  /// Whether the image size exceeds the warning threshold (>20MB)
  bool get imageSizeWarning => _imageSizeWarning;

  /// Human-readable image size info (e.g. "25.3MB")
  String? get imageSizeInfo => _imageSizeInfo;

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

  /// Get Korean error message based on error code
  static String getKoreanErrorMessage(String? errorCode, String? fallback) {
    switch (errorCode) {
      case 'E-C01':
        return '이미지가 너무 작습니다. 최소 200x200 픽셀 이상이어야 합니다.';
      case 'E-C02':
        return '이미지가 너무 큽니다 (최대 50MB)';
      case 'E-C03':
        return '지원하지 않는 이미지 형식입니다.';
      case 'E-C04':
        return '이미지 파일이 손상되었습니다.';
      case 'E-C05':
        return '페이지 경계를 감지할 수 없습니다.';
      case 'E-C06':
        return '이진화 처리에 실패했습니다.';
      case 'E-C07':
        return '메모리가 부족합니다. 더 작은 이미지를 사용해주세요.';
      case 'E-C08':
        return '처리 시간 초과';
      case 'E-C10':
        return '서버 연결이 거부되었습니다. 서버가 실행 중인지 확인해주세요.';
      case 'E-C99':
        return '서버에 연결할 수 없습니다';
      default:
        return fallback ?? '알 수 없는 오류가 발생했습니다.';
    }
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

    // Check image size and set warning flag
    _imageSizeInfo = _service.getImageSizeMB(imageBytes);
    _imageSizeWarning = _service.isImageSizeLarge(imageBytes);

    // Validate image size (reject >50MB)
    final sizeError = _service.validateImageSize(imageBytes);
    if (sizeError != null) {
      _state = RestorationState.error;
      _errorMessage = sizeError.userMessage;
      _errorCode = sizeError.failureCode;
      notifyListeners();
      return;
    }

    notifyListeners();

    try {
      final result = await _service.restoreImage(
        imageBytes,
        fileName,
        options: _options,
      );

      if (!result.success) {
        _state = RestorationState.error;
        _errorCode = result.failureCode;
        _errorMessage = getKoreanErrorMessage(
          result.failureCode,
          result.failureReason ?? '복원에 실패했습니다.',
        );
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
      _errorCode = e.failureCode;
      _errorMessage = e.userMessage;
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
    _imageSizeWarning = false;
    _imageSizeInfo = null;
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
      'imageSizeWarning': _imageSizeWarning,
      'imageSizeInfo': _imageSizeInfo,
    };
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
