import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'config.dart';
import 'screens/home_screen.dart';
import 'screens/score_viewer_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/capture_screen.dart';
import 'screens/debug_screen.dart';

/// Creates the GoRouter configuration for the app
GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: kDebugMode,
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        pageBuilder: (context, state) {
          return const NoTransitionPage(child: HomeScreen());
        },
        routes: [
          GoRoute(
            path: 'library',
            name: 'library',
            pageBuilder: (context, state) {
              return const NoTransitionPage(child: HomeScreen());
            },
          ),
          GoRoute(
            path: 'viewer/:id',
            name: 'viewer',
            pageBuilder: (context, state) {
              final scoreId = state.pathParameters['id']!;
              return MaterialPage(
                child: ScoreViewerScreen(scoreId: scoreId),
              );
            },
          ),
          GoRoute(
            path: 'settings',
            name: 'settings',
            pageBuilder: (context, state) {
              return const MaterialPage(child: SettingsScreen());
            },
          ),
          GoRoute(
            path: 'capture',
            name: 'capture',
            pageBuilder: (context, state) {
              return const MaterialPage(child: CaptureScreen());
            },
          ),
          if (enableDebugMode)
            GoRoute(
              path: 'debug',
              name: 'debug',
              pageBuilder: (context, state) {
                return const MaterialPage(child: DebugScreen());
              },
            ),
        ],
      ),
    ],
    errorPageBuilder: (context, state) {
      return MaterialPage(
        child: Scaffold(
          appBar: AppBar(title: const Text('Page Not Found')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('404 - Route not found'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Go Home'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Custom page transition that doesn't animate
class NoTransitionPage<T> extends Page<T> {
  final Widget child;

  const NoTransitionPage({required this.child});

  @override
  Route<T> createRoute(BuildContext context) {
    return PageRouteBuilder<T>(
      settings: this,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          child,
    );
  }
}
