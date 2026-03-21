import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Error types for restoration operations
enum RestorationError {
  serverUnavailable,
  uploadFailed,
  invalidImage,
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

  @override
  String toString() => 'RestorationException($type): $message';
}

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
  final Duration _timeout;

  RestorationService({
    this.baseUrl = 'http://localhost:8888',
    http.Client? client,
    Duration? timeout,
  })  : _client = client ?? http.Client(),
        _timeout = timeout ?? const Duration(seconds: 60);

  /// Restore an image via Module C server
  Future<RestorationResult> restoreImage(
    Uint8List imageBytes,
    String fileName, {
    RestorationOptions? options,
  }) async {
    final opts = options ?? const RestorationOptions();

    final uri = Uri.parse(
      '$baseUrl/api/restore'
      '?perspective=${opts.perspectiveCorrection}'
      '&deskew=${opts.deskew}'
      '&shadows=${opts.shadowRemoval}'
      '&contrast=${opts.contrastEnhancement}'
      '&binarization=${opts.binarizationMethod}',
    );

    try {
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: fileName,
      ));

      final streamedResponse = await request.send().timeout(_timeout);
      final body = await streamedResponse.stream.bytesToString();

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
    } on RestorationException {
      rethrow;
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw const RestorationException(
          type: RestorationError.timeout,
          message: '처리 시간이 초과되었습니다. 다시 시도해주세요.',
          failureCode: 'E-C08',
        );
      }
      throw RestorationException(
        type: RestorationError.serverUnavailable,
        message: '복원 서버에 연결할 수 없습니다: $e',
      );
    }
  }

  /// Download an image from the server
  Future<Uint8List> downloadImage(String imagePath) async {
    final url = imagePath.startsWith('http')
        ? imagePath
        : '$baseUrl$imagePath';

    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }

      throw RestorationException(
        type: RestorationError.restorationFailed,
        message: '이미지 다운로드 실패: ${response.statusCode}',
      );
    } catch (e) {
      if (e is RestorationException) rethrow;
      throw RestorationException(
        type: RestorationError.serverUnavailable,
        message: '이미지 다운로드 중 오류 발생: $e',
      );
    }
  }

  /// Check server health
  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/api/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Dispose of the HTTP client
  void dispose() {
    _client.close();
  }
}
