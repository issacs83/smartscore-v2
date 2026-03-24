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

  static const light = ScoreColors(
    background: Color(0xFFFFFDE7),
    noteColor: Color(0xFF1A1A1A),
    staffLine: Color(0xFF2A2A2A),
    measureBar: Color(0xFF3A3A3A),
    highlight: Color(0x401A56DB),
    annotationPen: Color(0xFFC62828),
    annotationHighlight: Color(0x99FDD835),
  );

  static const dark = ScoreColors(
    background: Color(0xFF1A1A1E),
    noteColor: Color(0xFFE8E8E8),
    staffLine: Color(0xFFD0D0D0),
    measureBar: Color(0xFFC0C0C0),
    highlight: Color(0x40A8C7FA),
    annotationPen: Color(0xFFEF9A9A),
    annotationHighlight: Color(0x66FDD835),
  );
}

/// Complete Material 3 theme for SmartScore.
class AppTheme {
  // Primary brand color — deep blue (readable on score backgrounds)
  static const Color _seedColor = Color(0xFF1A56DB);

  // Score display constants used by ScorePainter
  static const Color scoreBackgroundLight = Color(0xFFFFFDE7);
  static const Color scoreBackgroundDark = Color(0xFF1A1A1E);
  static const Color scoreBackgroundNight = Color(0xFF121212);
  static const Color scoreBackgroundSepia = Color(0xFFF5EDD6);

  // Source-type badge colors
  static const Color sourcePdf = Color(0xFFC62828);
  static const Color sourceMusicXml = Color(0xFF1565C0);
  static const Color sourceImage = Color(0xFFE65100);
  static const Color sourceMidi = Color(0xFF2E7D32);

  // -----------------------------------------------------------------------
  // Light Theme
  // -----------------------------------------------------------------------
  static ThemeData createLightTheme() {
    final base = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );

    final colorScheme = base.copyWith(
      primary: const Color(0xFF1A56DB),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD6E4FF),
      onPrimaryContainer: const Color(0xFF001A41),
      secondary: const Color(0xFF5E6AD2),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE2E0FF),
      tertiary: const Color(0xFFB5853A),
      surface: const Color(0xFFFAFAFA),
      onSurface: const Color(0xFF1A1C1E),
      onSurfaceVariant: const Color(0xFF42474E),
      outline: const Color(0xFF72787E),
      outlineVariant: const Color(0xFFC2C7CE),
      error: const Color(0xFFB3261E),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scoreBackgroundLight,
      extensions: const [ScoreColors.light],

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFFAFAFA),
        foregroundColor: const Color(0xFF1A1C1E),
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Color(0xFF1A1C1E),
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF42474E),
          size: 24,
        ),
      ),

      // NavigationBar (bottom tabs)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFFAFAFA),
        indicatorColor: const Color(0xFFD6E4FF),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A56DB),
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFF42474E),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF1A56DB), size: 24);
          }
          return const IconThemeData(color: Color(0xFF42474E), size: 24);
        }),
        elevation: 3,
        height: 80,
      ),

      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF1A56DB),
        foregroundColor: Colors.white,
        elevation: 3,
        focusElevation: 6,
        hoverElevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: Colors.white,
        shadowColor: const Color(0x1A000000),
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        elevation: 6,
        shadowColor: const Color(0x1A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        titleTextStyle: const TextStyle(
          color: Color(0xFF1A1C1E),
          fontSize: 24,
          fontWeight: FontWeight.w400,
        ),
        contentTextStyle: const TextStyle(
          color: Color(0xFF42474E),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),

      // BottomSheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFFF8F9FB),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: Color(0xFF72787E),
        dragHandleSize: Size(32, 4),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF0F2F5),
        selectedColor: const Color(0xFFD6E4FF),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1C1E),
        ),
        side: const BorderSide(color: Color(0xFFC2C7CE)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      // FilledButton
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor:
              WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0x1F1A1C1E);
            }
            return const Color(0xFF1A56DB);
          }),
          foregroundColor:
              WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.disabled)) {
              return const Color(0x611A1C1E);
            }
            return Colors.white;
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          ),
        ),
      ),

      // OutlinedButton
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor:
              WidgetStateProperty.all(const Color(0xFF1A56DB)),
          side: WidgetStateProperty.all(
            const BorderSide(color: Color(0xFF72787E)),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
        ),
      ),

      // TextButton
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor:
              WidgetStateProperty.all(const Color(0xFF1A56DB)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
          ),
        ),
      ),

      // Slider
      sliderTheme: SliderThemeData(
        activeTrackColor: const Color(0xFF1A56DB),
        inactiveTrackColor: const Color(0xFFD6E4FF),
        thumbColor: const Color(0xFF1A56DB),
        overlayColor: const Color(0x1F1A56DB),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
        valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
        valueIndicatorColor: const Color(0xFF1A56DB),
        valueIndicatorTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF0F2F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC2C7CE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB3261E)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFF72787E)),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E3E8),
        thickness: 1,
        space: 1,
      ),

      // ListTile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minLeadingWidth: 0,
      ),

      // Typography
      textTheme: _buildTextTheme(brightness: Brightness.light),
    );
  }

  // -----------------------------------------------------------------------
  // Dark Theme
  // -----------------------------------------------------------------------
  static ThemeData createDarkTheme() {
    final base = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );

    final colorScheme = base.copyWith(
      primary: const Color(0xFFA8C7FA),
      onPrimary: const Color(0xFF002D6B),
      primaryContainer: const Color(0xFF004494),
      onPrimaryContainer: const Color(0xFFD6E4FF),
      secondary: const Color(0xFFBFC2FF),
      onSecondary: const Color(0xFF272986),
      secondaryContainer: const Color(0xFF3E40A4),
      tertiary: const Color(0xFFE6B967),
      surface: const Color(0xFF131416),
      onSurface: const Color(0xFFE2E2E6),
      onSurfaceVariant: const Color(0xFFC5C6CC),
      outline: const Color(0xFF8E9099),
      outlineVariant: const Color(0xFF43474E),
      error: const Color(0xFFFFB4AB),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scoreBackgroundDark,
      extensions: const [ScoreColors.dark],

      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1E2228),
        foregroundColor: const Color(0xFFE2E2E6),
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Color(0xFFE2E2E6),
          fontSize: 22,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFFC5C6CC),
          size: 24,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1E2228),
        indicatorColor: const Color(0xFF004494),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFFA8C7FA),
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Color(0xFFC5C6CC),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFFA8C7FA), size: 24);
          }
          return const IconThemeData(color: Color(0xFFC5C6CC), size: 24);
        }),
        elevation: 3,
        height: 80,
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF004494),
        foregroundColor: Color(0xFFA8C7FA),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF1E2228),
        shadowColor: Colors.black26,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E2228),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        titleTextStyle: const TextStyle(
          color: Color(0xFFE2E2E6),
          fontSize: 24,
          fontWeight: FontWeight.w400,
        ),
        contentTextStyle: const TextStyle(
          color: Color(0xFFC5C6CC),
          fontSize: 14,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E2228),
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
        dragHandleColor: Color(0xFF8E9099),
        dragHandleSize: Size(32, 4),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF2A2D34),
        selectedColor: const Color(0xFF004494),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFFE2E2E6),
        ),
        side: const BorderSide(color: Color(0xFF43474E)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: const Color(0xFFA8C7FA),
        inactiveTrackColor: const Color(0xFF004494),
        thumbColor: const Color(0xFFA8C7FA),
        overlayColor: const Color(0x1FA8C7FA),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        valueIndicatorColor: const Color(0xFF004494),
        valueIndicatorTextStyle: const TextStyle(
          color: Color(0xFFA8C7FA),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2A2D34),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF43474E)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFA8C7FA), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: Color(0xFF8E9099)),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF2A2D34),
        thickness: 1,
        space: 1,
      ),

      textTheme: _buildTextTheme(brightness: Brightness.dark),
    );
  }

  // -----------------------------------------------------------------------
  // Shared text theme builder
  // -----------------------------------------------------------------------
  static TextTheme _buildTextTheme({required Brightness brightness}) {
    final Color textHigh =
        brightness == Brightness.light ? const Color(0xFF1A1C1E) : const Color(0xFFE2E2E6);
    final Color textMed =
        brightness == Brightness.light ? const Color(0xFF42474E) : const Color(0xFFC5C6CC);
    final Color textLow =
        brightness == Brightness.light ? const Color(0xFF72787E) : const Color(0xFF8E9099);

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        color: textHigh,
        letterSpacing: -0.25,
        height: 1.12,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: textHigh,
        height: 1.16,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: textHigh,
        height: 1.22,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w400,
        color: textHigh,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w400,
        color: textHigh,
        height: 1.29,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: textHigh,
        height: 1.33,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: textHigh,
        height: 1.27,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textHigh,
        letterSpacing: 0.15,
        height: 1.50,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textHigh,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textHigh,
        letterSpacing: 0.5,
        height: 1.50,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textMed,
        letterSpacing: 0.25,
        height: 1.43,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: textLow,
        letterSpacing: 0.4,
        height: 1.33,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textHigh,
        letterSpacing: 0.1,
        height: 1.43,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textMed,
        letterSpacing: 0.5,
        height: 1.33,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: textLow,
        letterSpacing: 0.5,
        height: 1.45,
      ),
    );
  }
}
