import 'package:provider/provider.dart';
import 'app_state.dart';
import 'ui_state_provider.dart';
import 'score_library_provider.dart';
import 'score_renderer_provider.dart';
import 'device_provider.dart';
import 'comparison_provider.dart';
import 'restoration_provider.dart';

/// Creates all providers for the app
List<ChangeNotifierProvider<dynamic>> createProviders(AppState appState) {
  return [
    // UI state
    ChangeNotifierProvider<UIStateProvider>(
      create: (_) => UIStateProvider(),
    ),

    // Score library (Module B)
    ChangeNotifierProvider<ScoreLibraryProvider>(
      create: (_) => ScoreLibraryProvider(appState.moduleB),
    ),

    // Score renderer (Module F) - function-based, no module instance
    ChangeNotifierProvider<ScoreRendererProvider>(
      create: (_) => ScoreRendererProvider(),
    ),

    // Device management (Module K)
    ChangeNotifierProvider<DeviceProvider>(
      create: (_) => DeviceProvider(appState.moduleK),
    ),

    // Comparison (Module C)
    ChangeNotifierProvider<ComparisonProvider>(
      create: (_) => ComparisonProvider(),
    ),

    // Restoration (Module C image restoration)
    ChangeNotifierProvider<RestorationProvider>(
      create: (_) => RestorationProvider(),
    ),
  ];
}
