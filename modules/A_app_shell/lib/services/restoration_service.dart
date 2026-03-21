import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Quality score breakdown model
class QualityScoreBreakdown {
  final double contrast;
  final double sharpness;
  final double lineStraightness;
  final double noiseLevel;
  final double coverage;
  final double binarizationQuality;
  final double overall;

  QualityScoreBreakdown({
    required this.contrast,
    required this.sharpness,
    required this.lineStraightness,
    required this.noiseLevel,
    required this.coverage,
    required this.binarizationQuality,
    required this.overall,
  });

  factory QualityScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return QualityScoreBreakdown(
      contrast: (json['contrast'] as num).toDouble(),
      sharpness: (json['sharpness'] as num).toDouble(),
      lineStraightness: (json['line_straightness'] as num).toDouble(),
      noiseLevel: (json['noise_level'] as num).toDouble(),
      coverage: (json['coverage'] as num).toDouble(),
      binarizationQuality: (json['binarization_quality'] as num).toDouble(),
      overall: (json['overall'] as num).toDouble(),
    );
  }
}

/// Restoration result model
class RestorationResult {
  final Uint8List originalImage;
  final Uint8List restoredImage;
  final Map<String, Uint8List> pipelineSteps;
  final QualityScoreBreakdown qualityScore;

  RestorationResult({
    required this.originalImage,
    required this.restoredImage,
    required this.pipelineSteps,
    required this.qualityScore,
  });
}

/// Service for communicating with the restoration server
class RestorationService {
  final String serverUrl;

  RestorationService({String? serverUrl}) : serverUrl = serverUrl ?? _getServerUrl();

  static String _getServerUrl() {
    // Default to localhost for development
    return 'http://localhost:8081';
  }

  /// Send image to restoration server and get results
  Future<RestorationResult> restoreImage(Uint8List imageData) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$serverUrl/api/restore'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageData,
          filename: 'sheet_music.jpg',
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.body}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseRestorationResponse(json, imageData);
    } on http.ClientException catch (e) {
      throw Exception('Connection error: ${e.message}');
    } catch (e) {
      throw Exception('Restoration failed: $e');
    }
  }

  /// Parse the restoration response from server
  Future<RestorationResult> _parseRestorationResponse(
    Map<String, dynamic> json,
    Uint8List originalImage,
  ) async {
    try {
      // Get restored image
      final restoredImagePath = json['restored_image'] as String?;
      if (restoredImagePath == null) {
        throw Exception('No restored image in response');
      }

      final restoredImage = await _downloadImage(restoredImagePath);

      // Get pipeline steps
      final pipelineStepsJson = json['pipeline_steps'] as Map<String, dynamic>?;
      final pipelineSteps = <String, Uint8List>{};

      if (pipelineStepsJson != null) {
        for (final entry in pipelineStepsJson.entries) {
          try {
            final imageData = await _downloadImage(entry.value as String);
            pipelineSteps[entry.key] = imageData;
          } catch (e) {
            debugPrint('Failed to load pipeline step ${entry.key}: $e');
          }
        }
      }

      // Get quality score
      final qualityScoreJson = json['quality_score'] as Map<String, dynamic>?;
      if (qualityScoreJson == null) {
        throw Exception('No quality score in response');
      }

      final qualityScore = QualityScoreBreakdown.fromJson(qualityScoreJson);

      return RestorationResult(
        originalImage: originalImage,
        restoredImage: restoredImage,
        pipelineSteps: pipelineSteps,
        qualityScore: qualityScore,
      );
    } catch (e) {
      throw Exception('Failed to parse restoration response: $e');
    }
  }

  /// Download image from URL or treat as base64 data
  Future<Uint8List> _downloadImage(String source) async {
    try {
      if (source.startsWith('data:')) {
        // Handle base64 data URI
        final parts = source.split(',');
        if (parts.length != 2) {
          throw Exception('Invalid data URI');
        }
        return base64Decode(parts[1]);
      } else if (source.startsWith('http')) {
        // Handle HTTP URL
        final response = await http.get(Uri.parse(source));
        if (response.statusCode != 200) {
          throw Exception('Failed to download image: ${response.statusCode}');
        }
        return response.bodyBytes;
      } else {
        // Assume it's base64 encoded
        return base64Decode(source);
      }
    } catch (e) {
      throw Exception('Failed to download image: $e');
    }
  }
}
