import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smartscore_build/modules/a_app_shell/services/restoration_service.dart';

void main() {
  group('RestorationService', () {
    group('checkHealth', () {
      test('returns true when server responds 200', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/api/health');
          return http.Response('{"status":"ok"}', 200);
        });
        final service = RestorationService(
          client: mockClient,
          baseUrl: 'http://localhost:8888',
        );

        final result = await service.checkHealth();
        expect(result, isTrue);

        service.dispose();
      });

      test('returns false when server is unreachable', () async {
        final mockClient = MockClient((request) async {
          throw Exception('Connection refused');
        });
        final service = RestorationService(
          client: mockClient,
          baseUrl: 'http://localhost:8888',
        );

        final result = await service.checkHealth();
        expect(result, isFalse);

        service.dispose();
      });
    });

    group('downloadImage', () {
      test('returns bytes on success', () async {
        final expectedBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        final mockClient = MockClient((request) async {
          expect(request.url.path, '/output/binary.png');
          return http.Response.bytes(expectedBytes, 200);
        });

        final service = RestorationService(
          client: mockClient,
          baseUrl: 'http://localhost:8888',
        );

        final result = await service.downloadImage('/output/binary.png');
        expect(result, expectedBytes);

        service.dispose();
      });

      test('throws RestorationException on 404', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not found', 404);
        });

        final service = RestorationService(
          client: mockClient,
          baseUrl: 'http://localhost:8888',
        );

        expect(
          () => service.downloadImage('/output/missing.png'),
          throwsA(isA<RestorationException>().having(
            (e) => e.type,
            'type',
            RestorationError.restorationFailed,
          )),
        );

        service.dispose();
      });

      test('handles absolute URL', () async {
        final expectedBytes = Uint8List.fromList([10, 20]);
        final mockClient = MockClient((request) async {
          expect(request.url.toString(), 'http://other-server:9999/img.png');
          return http.Response.bytes(expectedBytes, 200);
        });

        final service = RestorationService(
          client: mockClient,
          baseUrl: 'http://localhost:8888',
        );

        final result =
            await service.downloadImage('http://other-server:9999/img.png');
        expect(result, expectedBytes);

        service.dispose();
      });
    });

    group('validateImageSize', () {
      test('returns null for valid size', () {
        final service = RestorationService();
        final smallImage = Uint8List(1024); // 1KB
        expect(service.validateImageSize(smallImage), isNull);
        service.dispose();
      });

      test('returns exception for oversized image', () {
        final service = RestorationService();
        // Create a byte list larger than 50MB
        final bigImage = Uint8List(51 * 1024 * 1024);
        final error = service.validateImageSize(bigImage);
        expect(error, isNotNull);
        expect(error!.type, RestorationError.imageTooLarge);
        expect(error.failureCode, 'E-C02');
        service.dispose();
      });
    });

    group('isImageSizeLarge', () {
      test('returns false for small images', () {
        final service = RestorationService();
        expect(service.isImageSizeLarge(Uint8List(1024)), isFalse);
        service.dispose();
      });

      test('returns true for images over 20MB', () {
        final service = RestorationService();
        final largeImage = Uint8List(21 * 1024 * 1024);
        expect(service.isImageSizeLarge(largeImage), isTrue);
        service.dispose();
      });
    });

    group('getImageSizeMB', () {
      test('formats size correctly', () {
        final service = RestorationService();
        final image = Uint8List(5 * 1024 * 1024); // 5MB
        expect(service.getImageSizeMB(image), '5.0');
        service.dispose();
      });
    });
  });

  group('RestorationResult.fromJson', () {
    test('parses all fields correctly', () {
      final json = {
        'success': true,
        'job_id': 'abc-123',
        'quality_score': 0.92,
        'quality_components': {
          'contrast_ratio': 0.95,
          'sharpness': 0.88,
          'line_straightness': 0.91,
          'noise_level': 0.80,
          'coverage': 0.99,
          'binarization_quality': 0.85,
        },
        'skew_angle': -0.5,
        'page_detected': true,
        'processing_time_ms': 320.5,
        'step_times_ms': {
          'detect_page_bounds': 40.0,
          'binarize': 80.0,
        },
        'output_images': {
          'binary': '/out/bin.png',
          'grayscale': '/out/gray.png',
        },
        'intermediate_images': {
          'after_deskew': '/int/deskew.png',
        },
        'failure_reason': null,
        'failure_code': null,
      };

      final result = RestorationResult.fromJson(json);

      expect(result.success, isTrue);
      expect(result.jobId, 'abc-123');
      expect(result.qualityScore, 0.92);
      expect(result.skewAngle, -0.5);
      expect(result.pageDetected, isTrue);
      expect(result.processingTimeMs, 320.5);
      expect(result.stepTimesMs, hasLength(2));
      expect(result.outputImages['binary'], '/out/bin.png');
      expect(result.intermediateImages, isNotNull);
      expect(result.intermediateImages!['after_deskew'], '/int/deskew.png');
      expect(result.failureReason, isNull);
      expect(result.failureCode, isNull);
    });

    test('handles missing optional fields with defaults', () {
      final json = <String, dynamic>{};
      final result = RestorationResult.fromJson(json);

      expect(result.success, isFalse);
      expect(result.jobId, isNull);
      expect(result.qualityScore, 0.0);
      expect(result.qualityComponents, isNull);
      expect(result.skewAngle, 0.0);
      expect(result.pageDetected, isFalse);
      expect(result.processingTimeMs, 0.0);
      expect(result.stepTimesMs, isEmpty);
      expect(result.outputImages, isEmpty);
      expect(result.intermediateImages, isNull);
    });

    test('qualityGradeLabel returns correct Korean labels', () {
      expect(
        RestorationResult.fromJson({'quality_score': 0.95}).qualityGradeLabel,
        '우수',
      );
      expect(
        RestorationResult.fromJson({'quality_score': 0.80}).qualityGradeLabel,
        '양호',
      );
      expect(
        RestorationResult.fromJson({'quality_score': 0.65}).qualityGradeLabel,
        '보통',
      );
      expect(
        RestorationResult.fromJson({'quality_score': 0.45}).qualityGradeLabel,
        '부족',
      );
      expect(
        RestorationResult.fromJson({'quality_score': 0.30}).qualityGradeLabel,
        '사용 불가',
      );
    });
  });

  group('QualityComponents.fromJson', () {
    test('all 6 components parsed', () {
      final json = {
        'contrast_ratio': 0.9,
        'sharpness': 0.85,
        'line_straightness': 0.78,
        'noise_level': 0.6,
        'coverage': 0.95,
        'binarization_quality': 0.88,
      };

      final qc = QualityComponents.fromJson(json);

      expect(qc.contrastRatio, 0.9);
      expect(qc.sharpness, 0.85);
      expect(qc.lineStraightness, 0.78);
      expect(qc.noiseLevel, 0.6);
      expect(qc.coverage, 0.95);
      expect(qc.binarizationQuality, 0.88);
    });

    test('defaults to 0.0 for missing fields', () {
      final qc = QualityComponents.fromJson({});

      expect(qc.contrastRatio, 0.0);
      expect(qc.sharpness, 0.0);
      expect(qc.lineStraightness, 0.0);
      expect(qc.noiseLevel, 0.0);
      expect(qc.coverage, 0.0);
      expect(qc.binarizationQuality, 0.0);
    });

    test('toMap returns correct map', () {
      const qc = QualityComponents(
        contrastRatio: 0.9,
        sharpness: 0.8,
        lineStraightness: 0.7,
        noiseLevel: 0.6,
        coverage: 0.5,
        binarizationQuality: 0.4,
      );

      final map = qc.toMap();
      expect(map, hasLength(6));
      expect(map['contrast_ratio'], 0.9);
      expect(map['sharpness'], 0.8);
      expect(map['binarization_quality'], 0.4);
    });

    test('labels has all 6 keys', () {
      expect(QualityComponents.labels, hasLength(6));
      expect(QualityComponents.labels.containsKey('contrast_ratio'), isTrue);
      expect(QualityComponents.labels.containsKey('sharpness'), isTrue);
      expect(QualityComponents.labels.containsKey('line_straightness'), isTrue);
      expect(QualityComponents.labels.containsKey('noise_level'), isTrue);
      expect(QualityComponents.labels.containsKey('coverage'), isTrue);
      expect(
          QualityComponents.labels.containsKey('binarization_quality'), isTrue);
    });

    test('weights sum to 1.0', () {
      final sum =
          QualityComponents.weights.values.reduce((a, b) => a + b);
      expect(sum, closeTo(1.0, 0.001));
    });
  });

  group('RestorationOptions', () {
    test('default values', () {
      const opts = RestorationOptions();
      expect(opts.perspectiveCorrection, isTrue);
      expect(opts.deskew, isTrue);
      expect(opts.shadowRemoval, isTrue);
      expect(opts.contrastEnhancement, isTrue);
      expect(opts.binarizationMethod, 'sauvola');
    });

    test('copyWith creates modified copy', () {
      const opts = RestorationOptions();
      final modified = opts.copyWith(
        deskew: false,
        binarizationMethod: 'otsu',
      );

      expect(modified.perspectiveCorrection, isTrue);
      expect(modified.deskew, isFalse);
      expect(modified.shadowRemoval, isTrue);
      expect(modified.binarizationMethod, 'otsu');
    });

    test('copyWith preserves all values when no args given', () {
      const opts = RestorationOptions(
        perspectiveCorrection: false,
        deskew: false,
        shadowRemoval: false,
        contrastEnhancement: false,
        binarizationMethod: 'otsu',
      );
      final copy = opts.copyWith();
      expect(copy.perspectiveCorrection, isFalse);
      expect(copy.deskew, isFalse);
      expect(copy.shadowRemoval, isFalse);
      expect(copy.contrastEnhancement, isFalse);
      expect(copy.binarizationMethod, 'otsu');
    });
  });

  group('RestorationException', () {
    test('toString includes type and message', () {
      const ex = RestorationException(
        type: RestorationError.timeout,
        message: 'Timed out',
        failureCode: 'E-C08',
      );

      expect(ex.toString(), contains('timeout'));
      expect(ex.toString(), contains('Timed out'));
    });

    test('userMessage returns Korean text for each error type', () {
      for (final errorType in RestorationError.values) {
        final ex = RestorationException(
          type: errorType,
          message: 'test',
        );
        expect(ex.userMessage, isNotEmpty);
      }
    });

    test('connectionRefused userMessage', () {
      const ex = RestorationException(
        type: RestorationError.connectionRefused,
        message: 'test',
      );
      expect(ex.userMessage, contains('거부'));
    });
  });
}
