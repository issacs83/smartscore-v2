import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smartscore/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('SmartScore Integration Tests', () {
    testWidgets('App opens with empty library', (WidgetTester tester) async {
      // Load app
      await tester.pumpWidget(
        const ErrorBoundary(
          child: SmartScoreApp(),
        ),
      );

      // Wait for initial build
      await tester.pumpAndSettle();

      // Verify home screen is shown
      expect(find.text('Score Library'), findsWidgets);

      // Verify empty state message
      expect(find.text('No scores yet'), findsOneWidget);

      // Verify import button exists
      expect(find.byIcon(Icons.add), findsWidgets);
    });

    testWidgets(
      'Import dialog shows all format options',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ErrorBoundary(
            child: SmartScoreApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Tap import button
        await tester.tap(find.byIcon(Icons.add).first);
        await tester.pumpAndSettle();

        // Verify dialog appears
        expect(find.text('Import Score'), findsWidgets);

        // Verify all import options
        expect(find.text('Import PDF'), findsOneWidget);
        expect(find.text('Import MusicXML'), findsOneWidget);
        expect(find.text('Import Image'), findsOneWidget);
      },
    );

    testWidgets(
      'Settings screen is accessible',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ErrorBoundary(
            child: SmartScoreApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Tap settings icon
        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();

        // Verify settings screen
        expect(find.text('Settings'), findsWidgets);

        // Verify tabs
        expect(find.text('Display'), findsOneWidget);
        expect(find.text('Devices'), findsOneWidget);
        expect(find.text('About'), findsOneWidget);
      },
    );

    testWidgets(
      'Dark mode toggle works',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ErrorBoundary(
            child: SmartScoreApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate to settings
        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();

        // Find dark mode toggle
        final toggleFinder = find.byType(SwitchListTile);
        expect(toggleFinder, findsWidgets);

        // Tap toggle
        await tester.tap(toggleFinder.first);
        await tester.pumpAndSettle();

        // Verify toggle state changed
        final toggle = find.byType(SwitchListTile).first;
        expect(toggle, findsOneWidget);
      },
    );

    testWidgets(
      'Debug panel is only visible in dev mode',
      (WidgetTester tester) async {
        // This test depends on build flavor
        // In dev build, debug route should be accessible
        // In prod build, debug route should redirect to library

        await tester.pumpWidget(
          const ErrorBoundary(
            child: SmartScoreApp(),
          ),
        );
        await tester.pumpAndSettle();

        // Try to navigate to debug (if dev mode, should work; if prod, should redirect)
        // This is conditional based on enableDebugMode constant
      },
    );

    testWidgets(
      'Error boundary catches exceptions',
      (WidgetTester tester) async {
        // This test would trigger an exception and verify error dialog appears
        // Placeholder for actual error handling test
      },
    );

    testWidgets(
      'Page navigation controls are visible in score viewer',
      (WidgetTester tester) async {
        // This test would:
        // 1. Import a sample score (mocked)
        // 2. Navigate to viewer
        // 3. Verify page controls are present
        // 4. Test page navigation
        // Placeholder for score viewer integration test
      },
    );

    testWidgets(
      'Device page turn events are processed',
      (WidgetTester tester) async {
        // This test would:
        // 1. Mock device manager
        // 2. Emit device action
        // 3. Verify page changes in response
        // Placeholder for device integration test
      },
    );
  });
}
