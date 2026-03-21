import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Error types for restoration operations
enum RestorationError {
  serverUnavailable,
  connectionRefused,
  uploadFailed,
  invalidImage,
  imageTooLarge,
  restorationFailed,
  timeout,
}

/// Exception thrown by RestorationService
class RestorationException implements Exception {
  final RestorationError type;
  final String message;
  final String? failureCode;

  const RestorationException({
    required this.type,
    required this.message,
    this.failureCode,
  });

  /// Korean user-friendly error message based on error type
  String get userMessage {
    switch (type) {
      case RestorationError.serverUnavailable:
        return '서버에 연결할 수 없습니다';
      case RestorationError.connectionRefused:
        return '서버 연결이 거부되었습니다. 서버가 실행 중인지 확인해주세요.';
      case RestorationError.uploadFailed:
        return '이미지 업로드에 실패했습니다';
      case RestorationError.invalidImage:
        return '유효하지 않은 이미지입니다';
      case RestorationError.imageTooLarge:
        return '이미지가 너무 큽니다 (최대 50MB)';
      case RestorationError.restorationFailed:
        return '이미지 복원에 실패했습니다';
      case RestorationError.timeout:
        return '처리 시간 초과';
    }
  }

  @override
  String toString() => 'RestorationException($type): $message';
}

/// Maximum allowed image size in bytes (50MB)
const int maxImageSizeBytes = 50 * 1024 * 1024;

/// Warning threshold for image size in bytes (20MB)
const int warnImageSizeBytes = 20 * 1024 * 1024;

/// Options for image restoration
class RestorationOptions {
  final bool perspectiveCorrection;
  final bool deskew;
  final bool shadowRemoval;
  final bool contrastEnhancement;
  final String binarizationMethod;

  const RestorationOptions({
    this.perspectiveCorrection = true,
    this.deskew = true,
    this.shadowRemoval = true,
    this.contrastEnhancement = true,
    this.binarizationMethod = 'sauvola',
  });

  RestorationOptions copyWith({
    bool? perspectiveCorrection,
    bool? deskew,
    bool? shadowRemoval,
    bool? contrastEnhancement,
    String? binarizationMethod,
  }) {
    return RestorationOptions(
      perspectiveCorrection:
          perspectiveCorrection ?? this.perspectiveCorrection,
      deskew: deskew ?? this.deskew,
      shadowRemoval: shadowRemoval ?? this.shadowRemoval,
      contrastEnhancement:
          contrastEnhancement ?? this.contrastEnhancement,
      binarizationMethod: binarizationMethod ?? this.binarizationMethod,
    );
  }
}

/// Quality score components from Module C
class QualityComponents {
  final double contrastRatio;
  final double sharpness;
  final double lineStraightness;
  final double noiseLevel;
  final double coverage;
  final double binarizationQuality;

  const QualityComponents({
    required this.contrastRatio,
    required this.sharpness,
    required this.lineStraightness,
    required this.noiseLevel,
    required this.coverage,
    required this.binarizationQuality,
  });

  factory QualityComponents.fromJson(Map<String, dynamic> json) {
    return QualityComponents(
      contrastRatio: (json['contrast_ratio'] as num?)?.toDouble() ?? 0.0,
      sharpness: (json['sharpness'] as num?)?.toDouble() ?? 0.0,
      lineStraightness:
          (json['line_straightness'] as num?)?.toDouble() ?? 0.0,
      noiseLevel: (json['noise_level'] as num?)?.toDouble() ?? 0.0,
      coverage: (json['coverage'] as num?)?.toDouble() ?? 0.0,
      binarizationQuality:
          (json['binarization_quality'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, double> toMap() {
    return {
      'contrast_ratio': contrastRatio,
      'sharpness': sharpness,
      'line_straightness': lineStraightness,
      'noise_level': noiseLevel,
      'coverage': coverage,
      'binarization_quality': binarizationQuality,
    };
  }

  /// Korean labels for each component
  static const Map<String, String> labels = {
    'contrast_ratio': '대비',
    'sharpness': '선명도',
    'line_straightness': '직선성',
    'noise_level': '노이즈',
    'coverage': '커버리지',
    'binarization_quality': '이진화',
  };

  /// Weights for each component
  static const Map<String, double> weights = {
    'contrast_ratio': 0.25,
    'sharpness': 0.20,
    'line_straightness': 0.20,
    'noise_level': 0.15,
    'coverage': 0.10,
    'binarization_quality': 0.10,
  };
}

/// Result from image restoration
class RestorationResult {
  final bool success;
  final String? jobId;
  final double qualityScore;
  final QualityComponents? qualityComponents;
  final double skewAngle;
  final bool pageDetected;
  final double processingTimeMs;
  final Map<String, double> stepTimesMs;
  final Map<String, String> outputImages;
  final Map<String, String>? intermediateImages;
  final String? failureReason;
  final String? failureCode;

  const RestorationResult({
    required this.success,
    this.jobId,
    required this.qualityScore,
    this.qualityComponents,
    required this.skewAngle,
    required this.pageDetected,
    required this.processingTimeMs,
    required this.stepTimesMs,
    required this.outputImages,
    this.intermediateImages,
    this.failureReason,
    this.failureCode,
  });

  factory RestorationResult.fromJson(Map<String, dynamic> json) {
    return RestorationResult(
      success: json['success'] as bool? ?? false,
      jobId: json['job_id'] as String?,
      qualityScore: (json['quality_score'] as num?)?.toDouble() ?? 0.0,
      qualityComponents: json['quality_components'] is Map<String, dynamic>
          ? QualityComponents.fromJson(
              json['quality_components'] as Map<String, dynamic>)
          : null,
      skewAngle: (json['skew_angle'] as num?)?.toDouble() ?? 0.0,
      pageDetected: json['page_detected'] as bool? ?? false,
      processingTimeMs:
          (json['processing_time_ms'] as num?)?.toDouble() ?? 0.0,
      stepTimesMs: _parseDoubleMap(json['step_times_ms']),
      outputImages: _parseStringMap(json['output_images']),
      intermediateImages: json['intermediate_images'] != null
          ? _parseStringMap(json['intermediate_images'])
          : null,
      failureReason: json['failure_reason'] as String?,
      failureCode: json['failure_code'] as String?,
    );
  }

  static Map<String, double> _parseDoubleMap(dynamic value) {
    if (value is! Map) return {};
    return value.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
  }

  static Map<String, String> _parseStringMap(dynamic value) {
    if (value is! Map) return {};
    return value.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  /// Get the quality grade label in Korean
  String get qualityGradeLabel {
    if (qualityScore >= 0.90) return '우수';
    if (qualityScore >= 0.75) return '양호';
    if (qualityScore >= 0.60) return '보통';
    if (qualityScore >= 0.40) return '부족';
    return '사용 불가';
  }
}

/// HTTP client for Module C restoration server
class RestorationService {
  final String baseUrl;
  final http.Client _client;
  final Duration _restoreTimeout;
  final Duration _downloadTimeout;

  RestorationService({
    this.baseUrl = 'http://localhost:8888',
    http.Client? client,
    Duration? restoreTimeout,
    Duration? downloadTimeout,
  })  : _client = client ?? http.Client(),
        _restoreTimeout = restoreTimeout ?? const Duration(seconds: 30),
        _downloadTimeout = downloadTimeout ?? const Duration(seconds: 10);

  /// Validate image size before upload.
  /// Returns null if valid, or a RestorationException if invalid.
  RestorationException? validateImageSize(Uint8List imageBytes) {
    if (imageBytes.lengthInBytes > maxImageSizeBytes) {
      final sizeMB =
          (imageBytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
      return RestorationException(
        type: RestorationError.imageTooLarge,
        message: '이미지가 너무 큽니다 (${sizeMB}MB). 최대 50MB까지 지원합니다.',
        failureCode: 'E-C02',
      );
    }
    return null;
  }

  /// Check if image size exceeds warning threshold (20MB)
  bool isImageSizeLarge(Uint8List imageBytes) {
    return imageBytes.lengthInBytes > warnImageSizeBytes;
  }

  /// Get image size in MB as a formatted string
  String getImageSizeMB(Uint8List imageBytes) {
    return (imageBytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1);
  }

  /// Restore an image via Module C server
  Future<RestorationResult> restoreImage(
    Uint8List imageBytes,
    String fileName, {
    RestorationOptions? options,
  }) async {
    // Validate image size before upload
    final sizeError = validateImageSize(imageBytes);
    if (sizeError != null) {
      throw sizeError;
    }

    final opts = options ?? const RestorationOptions();

    final uri = Uri.parse(
      '$baseUrl/api/restore'
      '?perspective=${opts.perspectiveCorrection}'
      '&deskew=${opts.deskew}'
      '&shadows=${opts.shadowRemoval}'
      '&contrast=${opts.contrastEnhancement}'
      '&binarization=${opts.binarizationMethod}',
    );

    final sizeKB = (imageBytes.lengthInBytes / 1024).round();
    debugPrint('[Restoration] POST /api/restore — size: ${sizeKB}KB, file: $fileName');
    final stopwatch = Stopwatch()..start();

    try {
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: fileName,
      ));

      final streamedResponse =
          await request.send().timeout(_restoreTimeout);
      final body = await streamedResponse.stream.bytesToString();
      stopwatch.stop();
      debugPrint('[Restoration] Response: ${streamedResponse.statusCode} in ${stopwatch.elapsedMilliseconds}ms');

      if (streamedResponse.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        return RestorationResult.fromJson(json);
      }

      // Try to parse error response
      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        final failureCode = json['failure_code'] as String?;
        throw RestorationException(
          type: RestorationError.restorationFailed,
          message: json['failure_reason'] as String? ??
              'Server returned ${streamedResponse.statusCode}',
          failureCode: failureCode,
        );
      } catch (e) {
        if (e is RestorationException) rethrow;
        throw RestorationException(
          type: RestorationError.uploadFailed,
          message: 'Server returned ${streamedResponse.statusCode}: $body',
        );
      }
    } on RestorationException catch (e) {
      debugPrint('[Restoration] Error: ${e.type.name} — ${e.message}');
      rethrow;
    } on TimeoutException {
      debugPrint('[Restoration] Error: TimeoutException — restore timeout');
      throw const RestorationException(
        type: RestorationError.timeout,
        message: '처리 시간이 초과되었습니다. 다시 시도해주세요.',
        failureCode: 'E-C08',
      );
    } catch (e) {
      debugPrint('[Restoration] Error: ${e.runtimeType} — $e');
      if (e.toString().contains('TimeoutException')) {
        throw const RestorationException(
          type: RestorationError.timeout,
          message: '처리 시간이 초과되었습니다. 다시 시도해주세요.',
          failureCode: 'E-C08',
        );
      }
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('SocketException')) {
        throw const RestorationException(
          type: RestorationError.connectionRefused,
          message: '서버 연결이 거부되었습니다. 복원 서버가 실행 중인지 확인해주세요.',
          failureCode: 'E-C10',
        );
      }
      throw RestorationException(
        type: RestorationError.serverUnavailable,
        message: '복원 서버에 연결할 수 없습니다: $e',
        failureCode: 'E-C99',
      );
    }
  }

  /// Download an image from the server
  Future<Uint8List> downloadImage(String imagePath) async {
    final url = imagePath.startsWith('http')
        ? imagePath
        : '$baseUrl$imagePath';

    final stopwatch = Stopwatch()..start();

    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(_downloadTimeout);

      stopwatch.stop();

      if (response.statusCode == 200) {
        final sizeKB = (response.bodyBytes.lengthInBytes / 1024).round();
        debugPrint('[Restoration] Download: $imagePath — ${sizeKB}KB in ${stopwatch.elapsedMilliseconds}ms');
        return response.bodyBytes;
      }

      debugPrint('[Restoration] Error: downloadFailed — status ${response.statusCode}');
      throw RestorationException(
        type: RestorationError.restorationFailed,
        message: '이미지 다운로드 실패: ${response.statusCode}',
      );
    } on RestorationException {
      rethrow;
    } on TimeoutException {
      debugPrint('[Restoration] Error: TimeoutException — download timeout');
      throw const RestorationException(
        type: RestorationError.timeout,
        message: '이미지 다운로드 시간이 초과되었습니다.',
        failureCode: 'E-C08',
      );
    } catch (e) {
      debugPrint('[Restoration] Error: ${e.runtimeType} — $e');
      if (e.toString().contains('Connection refused') ||
          e.toString().contains('SocketException')) {
        throw const RestorationException(
          type: RestorationError.connectionRefused,
          message: '서버 연결이 거부되었습니다. 서버가 실행 중인지 확인해주세요.',
          failureCode: 'E-C10',
        );
      }
      throw RestorationException(
        type: RestorationError.serverUnavailable,
        message: '이미지 다운로드 중 오류 발생: $e',
      );
    }
  }

  /// Check server health
  Future<bool> checkHealth() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 10));
      stopwatch.stop();
      final ok = response.statusCode == 200;
      debugPrint('[Restoration] Health: ${ok ? "OK" : "FAIL(${response.statusCode})"} in ${stopwatch.elapsedMilliseconds}ms');
      return ok;
    } on TimeoutException {
      stopwatch.stop();
      debugPrint('[Restoration] Health: TIMEOUT in ${stopwatch.elapsedMilliseconds}ms');
      return false;
    } catch (e) {
      stopwatch.stop();
      debugPrint('[Restoration] Health: ERROR(${e.runtimeType}) in ${stopwatch.elapsedMilliseconds}ms');
      return false;
    }
  }

  /// Dispose of the HTTP client
  void dispose() {
    _client.close();
  }
}
