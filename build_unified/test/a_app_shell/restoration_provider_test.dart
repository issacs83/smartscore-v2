import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartscore_build/modules/a_app_shell/services/restoration_service.dart';
import 'package:smartscore_build/modules/a_app_shell/state/restoration_provider.dart';

/// A fake RestorationService that can be controlled without HTTP calls.
class FakeRestorationService extends RestorationService {
  final RestorationResult? _fakeResult;
  final RestorationException? _fakeError;
  final Uint8List _fakeImageBytes;

  FakeRestorationService({
    RestorationResult? fakeResult,
    RestorationException? fakeError,
    Uint8List? fakeImageBytes,
  })  : _fakeResult = fakeResult,
        _fakeError = fakeError,
        _fakeImageBytes = fakeImageBytes ?? Uint8List.fromList([1, 2, 3]),
        super(baseUrl: 'http://fake:8888');

  @override
  Future<RestorationResult> restoreImage(
    Uint8List imageBytes,
    String fileName, {
    RestorationOptions? options,
  }) async {
    // Still validate image size like the real service
    final sizeError = validateImageSize(imageBytes);
    if (sizeError != null) throw sizeError;

    if (_fakeError != null) throw _fakeError!;
    return _fakeResult!;
  }

  @override
  Future<Uint8List> downloadImage(String imagePath) async {
    return _fakeImageBytes;
  }

  @override
  Future<bool> checkHealth() async => true;
}

RestorationResult _makeSuccessResult() {
  return RestorationResult.fromJson({
    'success': true,
    'job_id': 'job-ok',
    'quality_score': 0.88,
    'quality_components': {
      'contrast_ratio': 0.9,
      'sharpness': 0.85,
      'line_straightness': 0.8,
      'noise_level': 0.7,
      'coverage': 0.95,
      'binarization_quality': 0.9,
    },
    'skew_angle': 0.5,
    'page_detected': true,
    'processing_time_ms': 300.0,
    'step_times_ms': <String, dynamic>{},
    'output_images': {
      'binary': '/out/bin.png',
      'grayscale': '/out/gray.png',
    },
  });
}

void main() {
  group('RestorationProvider', () {
    test('initial state is idle', () {
      final provider = RestorationProvider(
        service: FakeRestorationService(fakeResult: _makeSuccessResult()),
      );

      expect(provider.state, RestorationState.idle);
      expect(provider.result, isNull);
      expect(provider.originalImageBytes, isNull);
      expect(provider.binaryImageBytes, isNull);
      expect(provider.grayscaleImageBytes, isNull);
      expect(provider.errorMessage, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.hasResult, isFalse);
      expect(provider.imageSizeWarning, isFalse);
      expect(provider.imageSizeInfo, isNull);

      provider.dispose();
    });

    test('startRestoration: idle -> loading -> success', () async {
      final provider = RestorationProvider(
        service: FakeRestorationService(fakeResult: _makeSuccessResult()),
      );
      final states = <RestorationState>[];
      provider.addListener(() {
        states.add(provider.state);
      });

      final imageBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
      await provider.startRestoration(imageBytes, 'test.jpg');

      expect(states, contains(RestorationState.loading));
      expect(states.last, RestorationState.success);
      expect(provider.state, RestorationState.success);
      expect(provider.result, isNotNull);
      expect(provider.result!.qualityScore, 0.88);
      expect(provider.hasResult, isTrue);
      expect(provider.originalImageBytes, imageBytes);
      expect(provider.binaryImageBytes, isNotNull);
      expect(provider.grayscaleImageBytes, isNotNull);
      expect(provider.comparisonMode, ComparisonMode.comparison);

      provider.dispose();
    });

    test('startRestoration: idle -> loading -> error on service failure',
        () async {
      final provider = RestorationProvider(
        service: FakeRestorationService(
          fakeError: const RestorationException(
            type: RestorationError.serverUnavailable,
            message: 'Server down',
            failureCode: 'E-C99',
          ),
        ),
      );
      final states = <RestorationState>[];
      provider.addListener(() {
        states.add(provider.state);
      });

      final imageBytes = Uint8List.fromList([0xFF, 0xD8]);
      await provider.startRestoration(imageBytes, 'test.jpg');

      expect(states, contains(RestorationState.loading));
      expect(states.last, RestorationState.error);
      expect(provider.state, RestorationState.error);
      expect(provider.errorMessage, isNotNull);
      expect(provider.errorCode, 'E-C99');
      expect(provider.hasResult, isFalse);

      provider.dispose();
    });

    test('retry: error -> loading -> success', () async {
      final provider = RestorationProvider(
        service: FakeRestorationService(fakeResult: _makeSuccessResult()),
      );

      // First set up with an image
      final imageBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
      await provider.startRestoration(imageBytes, 'test.jpg');
      expect(provider.state, RestorationState.success);

      // Retry should also succeed
      await provider.retry();
      expect(provider.state, RestorationState.success);
      expect(provider.hasResult, isTrue);

      provider.dispose();
    });

    test('retry without original image sets error', () async {
      final provider = RestorationProvider(
        service: FakeRestorationService(fakeResult: _makeSuccessResult()),
      );

      await provider.retry();

      expect(provider.state, RestorationState.error);
      expect(provider.errorMessage, contains('원본 이미지'));

      provider.dispose();
    });

    test('updateOptions stores new options', () {
      final provider = RestorationProvider(
        service: FakeRestorationService(fakeResult: _makeSuccessResult()),
      );
      bool notified = false;
      provider.addListener(() => notified = true);

      const newOptions = RestorationOptions(
        perspectiveCorrection: false,
        deskew: false,
        binarizationMethod: 'otsu',
      );

      provider.updateOptions(newOptions);

      expect(provider.options.perspectiveCorrection, isFalse);
      expect(provider.options.deskew, isFalse);
      expect(provider.options.binarizationMethod, 'otsu');
      expect(notified, isTrue);

      provider.dispose();
    });

    test('reset: any state -> idle, clears data', () async {
      final provider = RestorationProvider(
        service: FakeRestorationService(fakeResult: _makeSuccessResult()),
      );

      final imageBytes = Uint8List.fromList([0xFF, 0xD8]);
      await provider.startRestoration(imageBytes, 'test.jpg');
      expect(provider.state, RestorationState.success);

      provider.reset();

      expect(provider.state, RestorationState.idle);
      expect(provider.result, isNull);
      expect(provider.originalImageBytes, isNull);
      expect(provider.binaryImageBytes, isNull);
      expect(provider.grayscaleImageBytes, isNull);
      expect(provider.errorMessage, isNull);
      expect(provider.errorCode, isNull);
      expect(provider.comparisonMode, ComparisonMode.original);
      expect(provider.showBinary, isTrue);
      expect(provider.imageSizeWarning, isFalse);
      expect(provider.imageSizeInfo, isNull);

      provider.dispose();
    });

    test('downloadResults populates image bytes', () async {
      final fakeBytes = Uint8List.fromList([10, 20, 30]);
      final provider = RestorationProvider(
        service: FakeRestorationService(
          fakeResult: _makeSuccessResult(),
          fakeImageBytes: fakeBytes,
        ),
      );

      final result = RestorationResult.fromJson({
        'success': true,
        'quality_score': 0.85,
        'skew_angle': 0.0,
        'page_detected': true,
        'processing_time_ms': 200.0,
        'step_times_ms': <String, dynamic>{},
        'output_images': {
          'binary': '/out/bin.png',
          'grayscale': '/out/gray.png',
        },
      });

      await provider.downloadResults(result);

      expect(provider.binaryImageBytes, fakeBytes);
      expect(provider.grayscaleImageBytes, fakeBytes);

      provider.dispose();
    });

    test('setComparisonMode updates mode', () {
      final provider = RestorationProvider(
        service: FakeRestorationService(fakeResult: _makeSuccessResult()),
      );
      bool notified = false;
      provider.addListener(() => notified = true);

      provider.setComparisonMode(ComparisonMode.quality);

      expect(provider.comparisonMode, ComparisonMode.quality);
      expect(notified, isTrue);

      provider.dispose();
    });

    test('toggleBinaryGrayscale switches showBinary', () {
      final provider = RestorationProvider(
        service: FakeRestorationService(fakeResult: _makeSuccessResult()),
      );

      expect(provider.showBinary, isTrue);
      provider.toggleBinaryGrayscale();
      expect(provider.showBinary, isFalse);
      provider.toggleBinaryGrayscale();
      expect(provider.showBinary, isTrue);

      provider.dispose();
    });

    test('dumpState returns expected keys', () {
      final provider = RestorationProvider(
        service: FakeRestorationService(fakeResult: _makeSuccessResult()),
      );

      final dump = provider.dumpState();
      expect(dump, containsPair('state', 'idle'));
      expect(dump, containsPair('hasResult', false));
      expect(dump, containsPair('hasOriginalImage', false));
      expect(dump, containsPair('imageSizeWarning', false));
      expect(dump, containsPair('imageSizeInfo', null));

      provider.dispose();
    });

    test('getKoreanErrorMessage returns correct messages', () {
      expect(
        RestorationProvider.getKoreanErrorMessage('E-C01', null),
        contains('너무 작습니다'),
      );
      expect(
        RestorationProvider.getKoreanErrorMessage('E-C02', null),
        contains('너무 큽니다'),
      );
      expect(
        RestorationProvider.getKoreanErrorMessage('E-C08', null),
        contains('시간 초과'),
      );
      expect(
        RestorationProvider.getKoreanErrorMessage('E-C10', null),
        contains('거부'),
      );
      expect(
        RestorationProvider.getKoreanErrorMessage(null, '대체 메시지'),
        '대체 메시지',
      );
      expect(
        RestorationProvider.getKoreanErrorMessage(null, null),
        contains('알 수 없는'),
      );
    });

    test('startRestoration with oversized image goes to error', () async {
      final provider = RestorationProvider(
        service: FakeRestorationService(fakeResult: _makeSuccessResult()),
      );

      // Create an image larger than 50MB
      final bigImage = Uint8List(51 * 1024 * 1024);
      await provider.startRestoration(bigImage, 'big.jpg');

      expect(provider.state, RestorationState.error);
      expect(provider.errorCode, 'E-C02');

      provider.dispose();
    });

    test('startRestoration with unsuccessful result goes to error', () async {
      final failResult = RestorationResult.fromJson({
        'success': false,
        'quality_score': 0.0,
        'skew_angle': 0.0,
        'page_detected': false,
        'processing_time_ms': 0.0,
        'step_times_ms': <String, dynamic>{},
        'output_images': <String, dynamic>{},
        'failure_reason': 'Image corrupt',
        'failure_code': 'E-C04',
      });

      final provider = RestorationProvider(
        service: FakeRestorationService(fakeResult: failResult),
      );

      final imageBytes = Uint8List.fromList([0xFF]);
      await provider.startRestoration(imageBytes, 'bad.jpg');

      expect(provider.state, RestorationState.error);
      expect(provider.errorCode, 'E-C04');

      provider.dispose();
    });
  });
}
