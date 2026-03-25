import 'package:flutter/material.dart';

/// Score-specific color extension for music notation rendering.
/// Accessed via: Theme.of(context).extension<ScoreColors>()
@immutable
class ScoreColors extends ThemeExtension<ScoreColors> {
  final Color background;
  final Color noteColor;
  final Color staffLine;
  final Color measureBar;
  final Color highlight;
  final Color annotationPen;
  final Color annotationHighlight;

  const ScoreColors({
    required this.background,
    required this.noteColor,
    required this.staffLine,
    required this.measureBar,
    required this.highlight,
    required this.annotationPen,
    required this.annotationHighlight,
  });

  @override
  ScoreColors copyWith({
    Color? background,
    Color? noteColor,
    Color? staffLine,
    Color? measureBar,
    Color? highlight,
    Color? annotationPen,
    Color? annotationHighlight,
  }) {
    return ScoreColors(
      background: background ?? this.background,
      noteColor: noteColor ?? this.noteColor,
      staffLine: staffLine ?? this.staffLine,
      measureBar: measureBar ?? this.measureBar,
      highlight: highlight ?? this.highlight,
      annotationPen: annotationPen ?? this.annotationPen,
      annotationHighlight: annotationHighlight ?? this.annotationHighlight,
    );
  }

  @override
  ScoreColors lerp(ScoreColors? other, double t) {
    if (other == null) return this;
    return ScoreColors(
      background: Color.lerp(background, other.background, t)!,
      noteColor: Color.lerp(noteColor, other.noteColor, t)!,
      staffLine: Color.lerp(staffLine, other.staffLine, t)!,
      measureBar: Color.lerp(measureBar, other.measureBar, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      annotationPen: Color.lerp(annotationPen, other.annotationPen, t)!,
      annotationHighlight:
          Color.lerp(annotationHighlight, other.annotationHighlight, t)!,
    );
  }

  // Clean white for reading (forScore-inspired)
  static const light = ScoreColors(
    background: Color(0xFFFFFFFF),
    noteColor: Color(0xFF1A1A1A),
    staffLine: Color(0xFF2A2A2A),
    measureBar: Color(0xFF3A3A3A),
    highlight: Color(0x405C6BC0),
    annotationPen: Color(0xFFD32F2F),
    annotationHighlight: Color(0x99FFD54F),
  );

  static const dark = ScoreColors(
    background: Color(0xFF121212),
    noteColor: Color(0xFFEEEEEE),
    staffLine: Color(0xFFDDDDDD),
    measureBar: Color(0xFFCCCCCC),
    highlight: Color(0x407986CB),
    annotationPen: Color(0xFFEF9A9A),
    annotationHighlight: Color(0x66FFD54F),
  );
}

/// Premium Material 3 theme for SmartScore — forScore/Piascore quality.
class AppTheme {
  // Brand palette — deep indigo primary, violet accent
  static const Color _primaryIndigo = Color(0xFF3730A3);   // indigo-700
  static const Color _primaryLight = Color(0xFF4F46E5);    // indigo-600
  static const Color _accentViolet = Color(0xFF7C3AED);    // violet-600
  static const Color _accentAmber = Color(0xFFF59E0B);     // amber-500

  // UI font family
  static const String _fontFamily = 'Roboto';

  // Score display backgrounds
  static const Color scoreBackgroundLight = Color(0xFFFFFFFF);
  static const Color scoreBackgroundDark = Color(0xFF121212);
  static const Color scoreBackgroundNight = Color(0xFF0D0D0D);
  static const Color scoreBackgroundSepia = Color(0xFFF5EDD6);

  // Source-type badge colors
  static const Color sourcePdf = Color(0xFFDC2626);
  static const Color sourceMusicXml = Color(0xFF2563EB);
  static const Color sourceImage = Color(0xFFEA580C);
  static const Color sourceMidi = Color(0xFF16A34A);

  // Gradient helpers used across screens
  static LinearGradient get primaryGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
      );

  static LinearGradient get primaryGradientVertical => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF4F46E5), Color(0xFF6D28D9)],
      );

  static LinearGradient get darkHeroGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
      );

  // -----------------------------------------------------------------------
  // Light Theme
  // -----------------------------------------------------------------------
  static ThemeData createLightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryIndigo,
      brightness: Brightness.light,
    ).copyWith(
      primary: _primaryLight,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE0E7FF),
      onPrimaryContainer: const Color(0xFF1E1B4B),
      secondary: _accentViolet,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFEDE9FE),
      onSecondaryContainer: const Color(0xFF2E1065),
      tertiary: _accentAmber,
      onTertiary: Colors.white,
      surface: const Color(0xFFFAFAFA),
      onSurface: const Color(0xFF111827),
      surfaceContainerHighest: const Color(0xFFF3F4F6),
      onSurfaceVariant: const Color(0xFF374151),
      outline: const Color(0xFF9CA3AF),
      outlineVariant: const Color(0xFFE5E7EB),
      error: const Color(0xFFDC2626),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF8F9FB),
      fontFamily: _fontFamily,
      extensions: const [ScoreColors.light],

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFAFAFA),
        foregroundColor: Color(0xFF111827),
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Color(0x0F000000),
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: Color(0xFF111827),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(
          color: Color(0xFF374151),
          size: 24,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE0E7FF),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4F46E5),
            );
          }
          return const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B7280),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF4F46E5), size: 24);
          }
          return const IconThemeData(color: Color(0xFF6B7280), size: 24);
        }),
        elevation: 0,
        height: 72,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 8,
        hoverElevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        shadowColor: const Color(0x14000000),
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: const Color(0x1A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: Color(0xFF111827),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: Color(0xFF374151),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        elevation: 12,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: Color(0xFFD1D5DB),
        dragHandleSize: Size(40, 4),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFFE0E7FF),
        checkmarkColor: _primaryLight,
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFF374151),
        ),
        side: const BorderSide(color: Color(0xFFE5E7EB), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFFE5E7EB);
            }
            return _primaryLight;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0xFF9CA3AF);
            }
            return Colors.white;
          }),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 0;
            return 2;
          }),
          shadowColor: WidgetStateProperty.all(
            _primaryLight.withValues(alpha: 0.4),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          ),
          minimumSize: WidgetStateProperty.all(const Size(0, 48)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(_primaryLight),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return const BorderSide(color: Color(0xFF4F46E5), width: 2);
            }
            return const BorderSide(color: Color(0xFFD1D5DB), width: 1.5);
          }),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          ),
          minimumSize: WidgetStateProperty.all(const Size(0, 48)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(_primaryLight),
          textStyle: WidgetStateProperty.all(
            const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
        ),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: _primaryLight,
        inactiveTrackColor: const Color(0xFFE0E7FF),
        thumbColor: _primaryLight,
        overlayColor: _primaryLight.withValues(alpha: 0.15),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
        valueIndicatorColor: _primaryIndigo,
        valueIndicatorTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: Color(0xFF9CA3AF),
          fontSize: 14,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFFF3F4F6),
        thickness: 1,
        space: 1,
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 20),
        minLeadingWidth: 0,
      ),

      textTheme: _buildTextTheme(brightness: Brightness.light),
    );
  }

  // -----------------------------------------------------------------------
  // Dark Theme
  // -----------------------------------------------------------------------
  static ThemeData createDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primaryIndigo,
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF818CF8),
      onPrimary: const Color(0xFF1E1B4B),
      primaryContainer: const Color(0xFF312E81),
      onPrimaryContainer: const Color(0xFFE0E7FF),
      secondary: const Color(0xFFA78BFA),
      onSecondary: const Color(0xFF2E1065),
      secondaryContainer: const Color(0xFF4C1D95),
      onSecondaryContainer: const Color(0xFFEDE9FE),
      tertiary: const Color(0xFFFBBF24),
      surface: const Color(0xFF111827),
      onSurface: const Color(0xFFF9FAFB),
      surfaceContainerHighest: const Color(0xFF1F2937),
      onSurfaceVariant: const Color(0xFF9CA3AF),
      outline: const Color(0xFF374151),
      outlineVariant: const Color(0xFF1F2937),
      error: const Color(0xFFF87171),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      fontFamily: _fontFamily,
      extensions: const [ScoreColors.dark],

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF111827),
        foregroundColor: Color(0xFFF9FAFB),
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black38,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          color: Color(0xFFF9FAFB),
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(
          color: Color(0xFFD1D5DB),
          size: 24,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF111827),
        indicatorColor: const Color(0xFF312E81),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: _fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF818CF8),
            );
          }
          return const TextStyle(
            fontFamily: _fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B7280),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF818CF8), size: 24);
          }
          return const IconThemeData(color: Color(0xFF6B7280), size: 24);
        }),
        elevation: 0,
        height: 72,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF1F2937),
        shadowColor: Colors.black54,
        elevation: 2,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1F2937),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: Color(0xFFF9FAFB),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: Color(0xFF9CA3AF),
          fontSize: 14,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1F2937),
        elevation: 12,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: Color(0xFF4B5563),
        dragHandleSize: Size(40, 4),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1F2937),
        selectedColor: const Color(0xFF312E81),
        checkmarkColor: const Color(0xFF818CF8),
        labelStyle: const TextStyle(
          fontFamily: _fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: Color(0xFFD1D5DB),
        ),
        side: const BorderSide(color: Color(0xFF374151), width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: const Color(0xFF818CF8),
        inactiveTrackColor: const Color(0xFF312E81),
        thumbColor: const Color(0xFF818CF8),
        overlayColor: const Color(0x1F818CF8),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        valueIndicatorColor: const Color(0xFF4F46E5),
        valueIndicatorTextStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1F2937),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF374151)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF374151)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF818CF8), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
          fontFamily: _fontFamily,
          color: Color(0xFF6B7280),
          fontSize: 14,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF1F2937),
        thickness: 1,
        space: 1,
      ),

      textTheme: _buildTextTheme(brightness: Brightness.dark),
    );
  }

  // -----------------------------------------------------------------------
  // Shared text theme
  // -----------------------------------------------------------------------
  static TextTheme _buildTextTheme({required Brightness brightness}) {
    final Color textHigh = brightness == Brightness.light
        ? const Color(0xFF111827)
        : const Color(0xFFF9FAFB);
    final Color textMed = brightness == Brightness.light
        ? const Color(0xFF374151)
        : const Color(0xFFD1D5DB);
    final Color textLow = brightness == Brightness.light
        ? const Color(0xFF6B7280)
        : const Color(0xFF9CA3AF);

    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 57,
        fontWeight: FontWeight.w300,
        color: textHigh,
        letterSpacing: -0.5,
        height: 1.12,
      ),
      displayMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 45,
        fontWeight: FontWeight.w300,
        color: textHigh,
        letterSpacing: -0.3,
        height: 1.16,
      ),
      displaySmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: textHigh,
        height: 1.22,
      ),
      headlineLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: textHigh,
        letterSpacing: -0.5,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: textHigh,
        letterSpacing: -0.3,
        height: 1.29,
      ),
      headlineSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: textHigh,
        letterSpacing: -0.2,
        height: 1.33,
      ),
      titleLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textHigh,
        letterSpacing: -0.1,
        height: 1.27,
      ),
      titleMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textHigh,
        letterSpacing: 0,
        height: 1.50,
      ),
      titleSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textHigh,
        letterSpacing: 0,
        height: 1.43,
      ),
      bodyLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textHigh,
        height: 1.55,
      ),
      bodyMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textMed,
        height: 1.50,
      ),
      bodySmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textLow,
        height: 1.45,
      ),
      labelLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: textHigh,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      labelMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textMed,
        letterSpacing: 0.2,
        height: 1.33,
      ),
      labelSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textLow,
        letterSpacing: 0.3,
        height: 1.45,
      ),
    );
  }
}
