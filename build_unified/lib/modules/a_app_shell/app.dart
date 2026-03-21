import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'router.dart';
import 'state/ui_state_provider.dart';
import 'config.dart';

class SmartScoreApp extends StatefulWidget {
  const SmartScoreApp({super.key});

  @override
  State<SmartScoreApp> createState() => _SmartScoreAppState();
}

class _SmartScoreAppState extends State<SmartScoreApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createRouter();
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UIStateProvider>(
      builder: (context, uiState, _) {
        return MaterialApp.router(
          title: appName,
          theme: AppTheme.createLightTheme(),
          darkTheme: AppTheme.createDarkTheme(),
          themeMode: uiState.darkMode ? ThemeMode.dark : ThemeMode.light,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
          supportedLocales: const [
            Locale('en', 'US'),
          ],
        );
      },
    );
  }
}
