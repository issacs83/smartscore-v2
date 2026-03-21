import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartscore_build/modules/a_app_shell/services/restoration_service.dart';
import 'package:smartscore_build/modules/a_app_shell/widgets/quality_score_card.dart';

void main() {
  group('QualityScoreCard', () {
    Widget buildCard({
      required double overallScore,
      QualityComponents? components,
      double? processingTimeMs,
      double? skewAngle,
      bool compact = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: QualityScoreCard(
              overallScore: overallScore,
              components: components,
              processingTimeMs: processingTimeMs,
              skewAngle: skewAngle,
              compact: compact,
            ),
          ),
        ),
      );
    }

    testWidgets('renders overall score correctly', (tester) async {
      await tester.pumpWidget(buildCard(overallScore: 0.85));
      await tester.pump();

      // Score displayed as percentage integer
      expect(find.text('85'), findsOneWidget);
      expect(find.text('품질 점수'), findsOneWidget);
      expect(find.text('양호'), findsOneWidget);
    });

    testWidgets('shows "우수" for score >= 0.90', (tester) async {
      await tester.pumpWidget(buildCard(overallScore: 0.95));
      await tester.pump();

      expect(find.text('우수'), findsOneWidget);
    });

    testWidgets('shows "사용 불가" for score < 0.40', (tester) async {
      await tester.pumpWidget(buildCard(overallScore: 0.30));
      await tester.pump();

      expect(find.text('사용 불가'), findsOneWidget);
    });

    testWidgets('shows "보통" for score 0.60-0.74', (tester) async {
      await tester.pumpWidget(buildCard(overallScore: 0.65));
      await tester.pump();

      expect(find.text('보통'), findsOneWidget);
    });

    testWidgets('shows "부족" for score 0.40-0.59', (tester) async {
      await tester.pumpWidget(buildCard(overallScore: 0.45));
      await tester.pump();

      expect(find.text('부족'), findsOneWidget);
    });

    testWidgets('shows all 6 component bars when components provided',
        (tester) async {
      final components = QualityComponents(
        contrastRatio: 0.9,
        sharpness: 0.85,
        lineStraightness: 0.8,
        noiseLevel: 0.7,
        coverage: 0.95,
        binarizationQuality: 0.88,
      );

      await tester.pumpWidget(buildCard(
        overallScore: 0.85,
        components: components,
      ));
      await tester.pump();

      // Check all 6 Korean labels are present
      expect(find.text('대비'), findsOneWidget);
      expect(find.text('선명도'), findsOneWidget);
      expect(find.text('직선성'), findsOneWidget);
      expect(find.text('노이즈'), findsOneWidget);
      expect(find.text('커버리지'), findsOneWidget);
      expect(find.text('이진화'), findsOneWidget);

      // Should have 6 LinearProgressIndicator for components
      // plus 1 CircularProgressIndicator for overall
      expect(
        find.byType(LinearProgressIndicator),
        findsNWidgets(6),
      );
    });

    testWidgets('shows processing time', (tester) async {
      await tester.pumpWidget(buildCard(
        overallScore: 0.85,
        processingTimeMs: 450.0,
      ));
      await tester.pump();

      expect(find.text('처리 시간: '), findsOneWidget);
      expect(find.text('450ms'), findsOneWidget);
    });

    testWidgets('shows processing time in seconds for >= 1000ms',
        (tester) async {
      await tester.pumpWidget(buildCard(
        overallScore: 0.85,
        processingTimeMs: 2500.0,
      ));
      await tester.pump();

      expect(find.text('2.5초'), findsOneWidget);
    });

    testWidgets('shows skew angle', (tester) async {
      await tester.pumpWidget(buildCard(
        overallScore: 0.85,
        skewAngle: 1.5,
      ));
      await tester.pump();

      expect(find.text('기울기: '), findsOneWidget);
      expect(find.text('1.5°'), findsOneWidget);
    });

    testWidgets('compact mode shows minimal info', (tester) async {
      final components = QualityComponents(
        contrastRatio: 0.9,
        sharpness: 0.85,
        lineStraightness: 0.8,
        noiseLevel: 0.7,
        coverage: 0.95,
        binarizationQuality: 0.88,
      );

      await tester.pumpWidget(buildCard(
        overallScore: 0.85,
        components: components,
        processingTimeMs: 300.0,
        compact: true,
      ));
      await tester.pump();

      // Compact mode should show score and label but not details
      expect(find.text('85'), findsOneWidget);
      expect(find.text('양호'), findsOneWidget);

      // Should NOT show component labels in compact mode
      expect(find.text('대비'), findsNothing);
      expect(find.text('선명도'), findsNothing);
      expect(find.text('처리 시간: '), findsNothing);

      // Should NOT show the full "품질 점수" header
      expect(find.text('품질 점수'), findsNothing);
    });

    testWidgets('no components section when components is null',
        (tester) async {
      await tester.pumpWidget(buildCard(overallScore: 0.75));
      await tester.pump();

      // The "세부 점수" section header should not appear
      expect(find.text('세부 점수'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('weight percentages are displayed', (tester) async {
      final components = QualityComponents(
        contrastRatio: 0.9,
        sharpness: 0.85,
        lineStraightness: 0.8,
        noiseLevel: 0.7,
        coverage: 0.95,
        binarizationQuality: 0.88,
      );

      await tester.pumpWidget(buildCard(
        overallScore: 0.85,
        components: components,
      ));
      await tester.pump();

      // Check weight labels are present
      expect(find.text('(25%)'), findsOneWidget); // contrast_ratio
      expect(find.text('(20%)'), findsNWidgets(2)); // sharpness + line_straightness
      expect(find.text('(15%)'), findsOneWidget); // noise_level
      expect(find.text('(10%)'), findsNWidgets(2)); // coverage + binarization_quality
    });
  });
}
