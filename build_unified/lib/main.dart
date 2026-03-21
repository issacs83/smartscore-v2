import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'modules/a_app_shell/app.dart';
import 'modules/a_app_shell/state/app_state.dart';
import 'modules/a_app_shell/state/providers.dart';
import 'modules/a_app_shell/config.dart';

void main() async {
  // Initialize logging first
  _initializeLogging();

  // Initialize error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
    _handleError(details);
  };

  // Configure platform channels
  _configurePlatform();

  // Boot logging
  debugPrint('[SmartScore] Boot: Starting application initialization...');
  final startTime = DateTime.now();

  // Initialize services
  debugPrint('[SmartScore] Boot: Initializing AppState...');
  final appState = await AppState.initialize();
  debugPrint('[SmartScore] Boot: AppState initialized');

  debugPrint('[SmartScore] Boot: Initializing providers...');
  final providers = createProviders(appState);
  debugPrint('[SmartScore] Boot: Providers created');

  final bootTime = DateTime.now().difference(startTime);
  debugPrint(
    '[SmartScore] Boot: Application ready in ${bootTime.inMilliseconds}ms',
  );

  runApp(
    ErrorBoundary(
      child: MultiProvider(
        providers: providers,
        child: const SmartScoreApp(),
      ),
    ),
  );
}

/// Initializes logging for the application
void _initializeLogging() {
  if (!kDebugMode) return;

  // Configure logging format
  final now = DateTime.now();
  final dateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
  debugPrint('[$dateTime] SmartScore Logging initialized');
}

/// Configures platform-specific settings
void _configurePlatform() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
}

/// Global error handler
void _handleError(FlutterErrorDetails details) {
  debugPrint('[SmartScore] ERROR: ${details.exceptionAsString()}');
  debugPrint('[SmartScore] STACK: ${details.stack}');
}

/// Global error boundary widget that wraps the entire app
class ErrorBoundary extends StatefulWidget {
  final Widget child;

  const ErrorBoundary({
    required this.child,
    Key? key,
  }) : super(key: key);

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  @override
  void initState() {
    super.initState();
    // Set up global error handler
    FlutterError.onError = (details) {
      _showErrorDialog(details);
    };
  }

  void _showErrorDialog(FlutterErrorDetails details) {
    debugPrint('[SmartScore] Showing error dialog: ${details.exceptionAsString()}');

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Oops! An Error Occurred'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SmartScore encountered an unexpected error. '
                  'Please try again or restart the application.',
                ),
                const SizedBox(height: 16),
                if (kDebugMode)
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        details.exceptionAsString(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
