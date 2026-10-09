import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color _lightPrimary = Color(0xFF0B6B65);

  static const Color _lightSurface = Color(0xFFF6FAF8);

  static const Color _lightSurfaceContainer = Color(0xFFEEF5F2);

  static const Color _lightText = Color(0xFF17211F);

  static const Color _lightSecondaryText = Color(0xFF61706C);

  static const Color _darkPrimary = Color(0xFF70D6CA);

  static const Color _darkSurface = Color(0xFF010202);

  static const Color _darkSurfaceContainer = Color(0xFF0F1412);

  static const Color _darkText = Color(0xFFEAF2F0);

  static const Color _darkSecondaryText = Color(0xFFAAB5B2);

  static ThemeData get light {
    return _build(
      brightness: Brightness.light,
      primary: _lightPrimary,
      surface: _lightSurface,
      surfaceContainer: _lightSurfaceContainer,
      text: _lightText,
      secondaryText: _lightSecondaryText,
      cardColor: const Color(0xFFFCFEFD),
    );
  }

  static ThemeData get dark {
    return _build(
      brightness: Brightness.dark,
      primary: _darkPrimary,
      surface: _darkSurface,
      surfaceContainer: _darkSurfaceContainer,
      text: _darkText,
      secondaryText: _darkSecondaryText,
      cardColor: const Color(0xFF0D1210),
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color surface,
    required Color surfaceContainer,
    required Color text,
    required Color secondaryText,
    required Color cardColor,
  }) {
    final isDark = brightness == Brightness.dark;

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: brightness,
        ).copyWith(
          primary: primary,
          surface: surface,
          onSurface: text,
          onSurfaceVariant: secondaryText,
          surfaceContainerLowest: isDark ? const Color(0xFF010202) : null,
          surfaceContainerLow: surfaceContainer,
          surfaceContainer: isDark ? const Color(0xFF131916) : null,
          surfaceContainerHigh: isDark ? const Color(0xFF18201D) : null,
          surfaceContainerHighest: isDark ? const Color(0xFF1E2823) : null,
          primaryContainer: isDark ? const Color(0xFF0D3A35) : null,
          onPrimaryContainer: isDark ? const Color(0xFFC8F4EF) : null,
          outline: isDark ? const Color(0xFF82908B) : null,
          outlineVariant: isDark ? const Color(0xFF3A4944) : null,
        );

    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: Colors.transparent,
    );

    final baseTextTheme = baseTheme.textTheme;

    final textTheme = baseTextTheme.copyWith(
      displaySmall: baseTextTheme.displaySmall?.copyWith(
        color: text,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.1,
        height: 1.08,
      ),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        color: text,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.12,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        color: text,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.65,
        height: 1.14,
      ),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(
        color: text,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.45,
        height: 1.18,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        color: text,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        height: 1.2,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        color: text,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.15,
        height: 1.25,
      ),
      titleSmall: baseTextTheme.titleSmall?.copyWith(
        color: text,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        color: text,
        fontWeight: FontWeight.w400,
        height: 1.48,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        color: text,
        fontWeight: FontWeight.w400,
        height: 1.45,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        color: secondaryText,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.05,
      ),
      labelMedium: baseTextTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
      labelSmall: baseTextTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.65,
      ),
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        toolbarHeight: 72,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: text, size: 25),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: text,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          height: 1.1,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardColor.withValues(alpha: isDark ? 1 : 0.90),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.92 : 0.58,
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor.withValues(alpha: isDark ? 1 : 0.84),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: secondaryText,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: primary,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: secondaryText.withValues(alpha: 0.75),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.94 : 0.72,
            ),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: surfaceContainer,
        selectedColor: colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: textTheme.labelMedium,
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.86 : 0.6,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(
          alpha: isDark ? 0.82 : 0.52,
        ),
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cardColor,
        modalBackgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: isDark
            ? const Color(0xFF131916)
            : colorScheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.90 : 0.65,
            ),
          ),
        ),
      ),
    );
  }
}
