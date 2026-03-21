import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartscore_build/modules/a_app_shell/screens/restoration_screen.dart';
import 'package:smartscore_build/modules/a_app_shell/services/restoration_service.dart';
import 'package:smartscore_build/modules/a_app_shell/state/restoration_provider.dart';
import 'package:smartscore_build/modules/a_app_shell/state/score_library_provider.dart';

/// A fake ScoreLibraryProvider that returns null from getScore,
/// so _loadAndRestore exits early without side effects.
class _FakeScoreLibraryProvider extends ScoreLibraryProvider {
  _FakeScoreLibraryProvider() : super(null);

  @override
  Future<Map<String, dynamic>?> getScore(String scoreId) async => null;

  @override
  Future<Uint8List?> getImageBytes(String scoreId) async => null;
}

/// A fake RestorationService that avoids real HTTP.
class _FakeRestorationService extends RestorationService {
  final bool shouldSucceed;

  _FakeRestorationService({this.shouldSucceed = false})
      : super(baseUrl: 'http://fake:0');

  @override
  Future<RestorationResult> restoreImage(
    Uint8List imageBytes,
    String fileName, {
    RestorationOptions? options,
  }) async {
    if (shouldSucceed) {
      return RestorationResult.fromJson({
        'success': true,
        'job_id': 'job-ok',
        'quality_score': 0.85,
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
        'output_images': <String, dynamic>{},
      });
    }
    throw const RestorationException(
      type: RestorationError.serverUnavailable,
      message: 'fake error',
    );
  }

  @override
  Future<Uint8List> downloadImage(String imagePath) async {
    return Uint8List(0);
  }

  @override
  Future<bool> checkHealth() async => false;
}

Widget _buildTestApp({required RestorationProvider provider}) {
  return MaterialApp(
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<RestorationProvider>.value(value: provider),
        ChangeNotifierProvider<ScoreLibraryProvider>.value(
          value: _FakeScoreLibraryProvider(),
        ),
      ],
      child: const RestorationScreen(scoreId: 'test-score'),
    ),
  );
}

void main() {
  group('RestorationScreen', () {
    testWidgets('shows idle text in initial state', (tester) async {
      final provider = RestorationProvider(
        service: _FakeRestorationService(),
      );

      await tester.pumpWidget(_buildTestApp(provider: provider));
      // pump once to let post-frame callback run (getScore returns null -> early exit)
      await tester.pumpAndSettle();

      // Provider stays idle because _loadAndRestore exits early
      expect(find.text('이미지를 불러오는 중...'), findsOneWidget);

      provider.dispose();
    });

    testWidgets('shows app bar title', (tester) async {
      final provider = RestorationProvider(
        service: _FakeRestorationService(),
      );

      await tester.pumpWidget(_buildTestApp(provider: provider));
      await tester.pumpAndSettle();

      expect(find.text('이미지 복원'), findsOneWidget);

      provider.dispose();
    });

    testWidgets('shows error message with retry button on failure',
        (tester) async {
      final provider = RestorationProvider(
        service: _FakeRestorationService(),
      );

      // Put provider into error state before rendering
      final imageBytes = Uint8List.fromList([0xFF, 0xD8]);
      await provider.startRestoration(imageBytes, 'test.jpg');
      expect(provider.state, RestorationState.error);

      await tester.pumpWidget(_buildTestApp(provider: provider));
      await tester.pumpAndSettle();

      expect(find.text('복원 실패'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.text('돌아가기'), findsOneWidget);

      provider.dispose();
    });

    testWidgets('renders 4 tabs when in success state', (tester) async {
      final provider = RestorationProvider(
        service: _FakeRestorationService(shouldSucceed: true),
      );

      // Use a valid 1x1 transparent GIF (smallest valid image)
      final validImage = _createValidGif();
      await provider.startRestoration(validImage, 'test.gif');
      expect(provider.state, RestorationState.success);

      await tester.pumpWidget(_buildTestApp(provider: provider));
      await tester.pump();

      // The 4 tab labels should be present in the TabBar
      expect(find.text('원본'), findsOneWidget);
      expect(find.text('복원'), findsOneWidget);
      expect(find.text('비교'), findsOneWidget);
      expect(find.text('품질'), findsOneWidget);

      provider.dispose();
    });

    testWidgets('shows loading indicator during restoration', (tester) async {
      // Use a service that never completes so we stay in loading state
      final slowService = _SlowRestorationService();
      final provider = RestorationProvider(service: slowService);

      final imageBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]);
      // Start restoration but don't await — we want to catch the loading state
      // ignore: unawaited_futures
      provider.startRestoration(imageBytes, 'test.jpg');

      await tester.pumpWidget(_buildTestApp(provider: provider));
      await tester.pump(); // one frame to render

      expect(provider.state, RestorationState.loading);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the pending future so test can clean up
      slowService.complete();
      await tester.pumpAndSettle();

      provider.dispose();
    });
  });
}

/// Creates a valid 1x1 transparent GIF89a image.
Uint8List _createValidGif() {
  return Uint8List.fromList([
    // GIF89a header
    0x47, 0x49, 0x46, 0x38, 0x39, 0x61,
    // Logical screen descriptor: 1x1
    0x01, 0x00, 0x01, 0x00,
    // GCT flag=0, color resolution, sort, size
    0x00,
    // Background color index
    0x00,
    // Pixel aspect ratio
    0x00,
    // Image descriptor
    0x2C, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
    // LZW minimum code size
    0x02,
    // Sub-block: 2 bytes of data
    0x02, 0x44, 0x01,
    // Block terminator
    0x00,
    // Trailer
    0x3B,
  ]);
}

/// A service that never completes restoreImage, keeping provider in loading state.
class _SlowRestorationService extends RestorationService {
  final Completer<RestorationResult> completer = Completer<RestorationResult>();

  _SlowRestorationService() : super(baseUrl: 'http://fake:0');

  @override
  Future<RestorationResult> restoreImage(
    Uint8List imageBytes,
    String fileName, {
    RestorationOptions? options,
  }) {
    // Return a future that never completes (no timer)
    return completer.future;
  }

  @override
  Future<Uint8List> downloadImage(String imagePath) async {
    return Uint8List(0);
  }

  @override
  Future<bool> checkHealth() async => false;

  /// Complete the pending future to allow cleanup
  void complete() {
    if (!completer.isCompleted) {
      completer.completeError(const RestorationException(
        type: RestorationError.timeout,
        message: 'cleanup',
      ));
    }
  }
}
