import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'theme.dart';
import 'router.dart';
import 'state/ui_state_provider.dart';
import 'config.dart';

class SmartScoreApp extends StatelessWidget {
  const SmartScoreApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<UIStateProvider>(
      builder: (context, uiState, _) {
        return MaterialApp.router(
          title: appName,
          theme: AppTheme.createLightTheme(),
          darkTheme: AppTheme.createDarkTheme(),
          themeMode: uiState.darkMode ? ThemeMode.dark : ThemeMode.light,
          routerConfig: createRouter(context),
          debugShowCheckedModeBanner: false,
          supportedLocales: const [
            Locale('en', 'US'),
          ],
        );
      },
    );
  }
}
