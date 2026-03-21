import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartscore_build/modules/a_app_shell/widgets/image_comparison_slider.dart';

/// Creates a minimal valid 1x1 PNG as Uint8List.
Uint8List _createMinimalPng() {
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01,
    0x00, 0x00, 0x00, 0x01,
    0x08, 0x02,
    0x00, 0x00, 0x00,
    0x90, 0x77, 0x53, 0xDE,
    0x00, 0x00, 0x00, 0x0C,
    0x49, 0x44, 0x41, 0x54,
    0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00,
    0x00, 0x04, 0x00, 0x01,
    0x02, 0x8A, 0x6A, 0x25,
    0x00, 0x00, 0x00, 0x00,
    0x49, 0x45, 0x4E, 0x44,
    0xAE, 0x42, 0x60, 0x82,
  ]);
}

void main() {
  group('ImageComparisonSlider', () {
    testWidgets('renders with two images', (tester) async {
      final original = _createMinimalPng();
      final restored = _createMinimalPng();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: ImageComparisonSlider(
                originalImage: original,
                restoredImage: restored,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Should render two Image.memory widgets (original and restored)
      expect(find.byType(Image), findsAtLeast(2));
    });

    testWidgets('displays "원본" and "복원" labels', (tester) async {
      final original = _createMinimalPng();
      final restored = _createMinimalPng();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: ImageComparisonSlider(
                originalImage: original,
                restoredImage: restored,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('원본'), findsOneWidget);
      expect(find.text('복원'), findsOneWidget);
    });

    testWidgets('custom labels are displayed', (tester) async {
      final original = _createMinimalPng();
      final restored = _createMinimalPng();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: ImageComparisonSlider(
                originalImage: original,
                restoredImage: restored,
                leftLabel: 'Before',
                rightLabel: 'After',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Before'), findsOneWidget);
      expect(find.text('After'), findsOneWidget);
    });

    testWidgets('has a drag handle icon', (tester) async {
      final original = _createMinimalPng();
      final restored = _createMinimalPng();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: ImageComparisonSlider(
                originalImage: original,
                restoredImage: restored,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.drag_handle), findsOneWidget);
    });

    testWidgets('responds to horizontal drag', (tester) async {
      final original = _createMinimalPng();
      final restored = _createMinimalPng();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: ImageComparisonSlider(
                originalImage: original,
                restoredImage: restored,
                initialPosition: 0.5,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the GestureDetector and drag it
      final gesture = find.byType(GestureDetector);
      expect(gesture, findsOneWidget);

      // Drag to the right
      await tester.drag(gesture, const Offset(100, 0));
      await tester.pump();

      // The widget should still render without errors after drag
      expect(find.byType(ImageComparisonSlider), findsOneWidget);
    });

    testWidgets('initial position can be customized', (tester) async {
      final original = _createMinimalPng();
      final restored = _createMinimalPng();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: ImageComparisonSlider(
                originalImage: original,
                restoredImage: restored,
                initialPosition: 0.3,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Widget renders without error with custom initial position
      expect(find.byType(ImageComparisonSlider), findsOneWidget);
    });
  });
}
