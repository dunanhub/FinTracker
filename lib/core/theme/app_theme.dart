import 'package:flutter/material.dart';

import 'theme_preset.dart';

class FinThemeColors extends ThemeExtension<FinThemeColors> {
  final Color heroStart;
  final Color heroEnd;
  final Color heroForeground;
  final Color softAccent;

  final Color income;
  final Color expense;
  final Color transfer;

  const FinThemeColors({
    required this.heroStart,
    required this.heroEnd,
    required this.heroForeground,
    required this.softAccent,
    required this.income,
    required this.expense,
    required this.transfer,
  });

  @override
  FinThemeColors copyWith({
    Color? heroStart,
    Color? heroEnd,
    Color? heroForeground,
    Color? softAccent,
    Color? income,
    Color? expense,
    Color? transfer,
  }) {
    return FinThemeColors(
      heroStart: heroStart ?? this.heroStart,
      heroEnd: heroEnd ?? this.heroEnd,
      heroForeground: heroForeground ?? this.heroForeground,
      softAccent: softAccent ?? this.softAccent,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      transfer: transfer ?? this.transfer,
    );
  }

  @override
  FinThemeColors lerp(
    covariant ThemeExtension<FinThemeColors>? other,
    double t,
  ) {
    if (other is! FinThemeColors) {
      return this;
    }

    return FinThemeColors(
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      heroForeground: Color.lerp(heroForeground, other.heroForeground, t)!,
      softAccent: Color.lerp(softAccent, other.softAccent, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
    );
  }
}

extension FinThemeContext on BuildContext {
  FinThemeColors get finColors {
    return Theme.of(this).extension<FinThemeColors>()!;
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData light(AppThemePreset preset) {
    return _buildTheme(preset: preset, brightness: Brightness.light);
  }

  static ThemeData dark(AppThemePreset preset) {
    return _buildTheme(preset: preset, brightness: Brightness.dark);
  }

  static ThemeData _buildTheme({
    required AppThemePreset preset,
    required Brightness brightness,
  }) {
    final palette = _getPalette(preset, brightness);

    final scheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
    ).copyWith(
      primary: palette.primary,
      onPrimary: palette.primaryForeground,
      secondary: palette.secondary,
      surface: palette.surface,
      onSurface: palette.text,
      onSurfaceVariant: palette.muted,
      outlineVariant: palette.outline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.background,

      extensions: [
        FinThemeColors(
          heroStart: palette.heroStart,
          heroEnd: palette.heroEnd,
          heroForeground: palette.heroForeground,
          softAccent: palette.softAccent,
          income: const Color(0xFF58A882),
          expense: const Color(0xFFE36E7D),
          transfer: const Color(0xFF718FCB),
        ),
      ],

      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.text,
      ),

      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          color: palette.text,
        ),
        headlineMedium: TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: palette.text,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: palette.text,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: palette.text,
        ),
        bodyLarge: TextStyle(fontSize: 16, color: palette.text),
        bodyMedium: TextStyle(fontSize: 14, color: palette.muted),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.input,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: palette.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: palette.primary, width: 1.4),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: palette.primary,
          foregroundColor: palette.primaryForeground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),

      dividerTheme: DividerThemeData(color: palette.outline),
    );
  }

  static _ThemePalette _getPalette(
    AppThemePreset preset,
    Brightness brightness,
  ) {
    final dark = brightness == Brightness.dark;

    switch (preset) {
      case AppThemePreset.white:
        return dark
            ? const _ThemePalette(
              background: Color(0xFF141414),
              surface: Color(0xFF1E1E1E),
              input: Color(0xFF252525),
              primary: Color(0xFFD8D5CE),
              primaryForeground: Color(0xFF1A1A1A),
              secondary: Color(0xFF33312D),
              text: Color(0xFFF5F4F1),
              muted: Color(0xFFA7A39B),
              outline: Color(0xFF303030),
              softAccent: Color(0xFF2D2B28),
              heroStart: Color(0xFFE3DFD7),
              heroEnd: Color(0xFFC7C1B8),
              heroForeground: Color(0xFF25231F),
            )
            : const _ThemePalette(
              background: Color(0xFFF8F7F4),
              surface: Colors.white,
              input: Color(0xFFFCFBF9),
              primary: Color(0xFF817C72),
              primaryForeground: Colors.white,
              secondary: Color(0xFFECE9E3),
              text: Color(0xFF25231F),
              muted: Color(0xFF8E8980),
              outline: Color(0xFFEAE6DF),
              softAccent: Color(0xFFF0EDE7),
              heroStart: Color(0xFFEDEAE4),
              heroEnd: Color(0xFFD6D0C7),
              heroForeground: Color(0xFF25231F),
            );

      case AppThemePreset.black:
        return dark
            ? const _ThemePalette(
              background: Color(0xFF0F1012),
              surface: Color(0xFF18191D),
              input: Color(0xFF202126),
              primary: Color(0xFFD8DADE),
              primaryForeground: Color(0xFF151619),
              secondary: Color(0xFF292A30),
              text: Color(0xFFF4F4F5),
              muted: Color(0xFF9B9CA3),
              outline: Color(0xFF292B31),
              softAccent: Color(0xFF25262C),
              heroStart: Color(0xFF32343A),
              heroEnd: Color(0xFF18191D),
              heroForeground: Colors.white,
            )
            : const _ThemePalette(
              background: Color(0xFFF5F5F6),
              surface: Colors.white,
              input: Color(0xFFFAFAFA),
              primary: Color(0xFF303238),
              primaryForeground: Colors.white,
              secondary: Color(0xFFE5E6E8),
              text: Color(0xFF1D1E22),
              muted: Color(0xFF81838A),
              outline: Color(0xFFE8E9EB),
              softAccent: Color(0xFFE7E8EA),
              heroStart: Color(0xFF45484F),
              heroEnd: Color(0xFF27292E),
              heroForeground: Colors.white,
            );

      case AppThemePreset.gray:
        return dark
            ? const _ThemePalette(
              background: Color(0xFF151922),
              surface: Color(0xFF1D2330),
              input: Color(0xFF252C3A),
              primary: Color(0xFF9CA7B9),
              primaryForeground: Color(0xFF141820),
              secondary: Color(0xFF2B3444),
              text: Color(0xFFF2F4F8),
              muted: Color(0xFFA2AABA),
              outline: Color(0xFF303949),
              softAccent: Color(0xFF2A3240),
              heroStart: Color(0xFF697487),
              heroEnd: Color(0xFF414A5A),
              heroForeground: Colors.white,
            )
            : const _ThemePalette(
              background: Color(0xFFF5F6F8),
              surface: Colors.white,
              input: Color(0xFFFAFBFC),
              primary: Color(0xFF7F899A),
              primaryForeground: Colors.white,
              secondary: Color(0xFFDDE1E8),
              text: Color(0xFF2A303B),
              muted: Color(0xFF8A92A0),
              outline: Color(0xFFE7E9ED),
              softAccent: Color(0xFFE4E7EC),
              heroStart: Color(0xFF919BAA),
              heroEnd: Color(0xFF687385),
              heroForeground: Colors.white,
            );

      case AppThemePreset.pink:
        return dark
            ? const _ThemePalette(
              background: Color(0xFF191316),
              surface: Color(0xFF241B20),
              input: Color(0xFF2E2329),
              primary: Color(0xFFD98DA6),
              primaryForeground: Color(0xFF25171D),
              secondary: Color(0xFF392731),
              text: Color(0xFFF8F1F4),
              muted: Color(0xFFB7A6AE),
              outline: Color(0xFF392B32),
              softAccent: Color(0xFF38262F),
              heroStart: Color(0xFFB76884),
              heroEnd: Color(0xFF794657),
              heroForeground: Colors.white,
            )
            : const _ThemePalette(
              background: Color(0xFFFFF7FA),
              surface: Colors.white,
              input: Color(0xFFFFFBFC),
              primary: Color(0xFFD989A4),
              primaryForeground: Colors.white,
              secondary: Color(0xFFF4DCE5),
              text: Color(0xFF33262C),
              muted: Color(0xFF9A8991),
              outline: Color(0xFFF1E4E9),
              softAccent: Color(0xFFF7E3EA),
              heroStart: Color(0xFFDE91AA),
              heroEnd: Color(0xFFC46F8C),
              heroForeground: Colors.white,
            );

      case AppThemePreset.navy:
        return dark
            ? const _ThemePalette(
              background: Color(0xFF101722),
              surface: Color(0xFF192233),
              input: Color(0xFF202B3D),
              primary: Color(0xFF8AA0D0),
              primaryForeground: Color(0xFF101722),
              secondary: Color(0xFF293650),
              text: Color(0xFFF3F6FC),
              muted: Color(0xFFA4AEC3),
              outline: Color(0xFF2B374C),
              softAccent: Color(0xFF28364F),
              heroStart: Color(0xFF3E537F),
              heroEnd: Color(0xFF25375C),
              heroForeground: Colors.white,
            )
            : const _ThemePalette(
              background: Color(0xFFF6F8FC),
              surface: Colors.white,
              input: Color(0xFFFBFCFE),
              primary: Color(0xFF465D8F),
              primaryForeground: Colors.white,
              secondary: Color(0xFFDDE5F4),
              text: Color(0xFF20283A),
              muted: Color(0xFF8590A5),
              outline: Color(0xFFE6EAF1),
              softAccent: Color(0xFFE5EAF5),
              heroStart: Color(0xFF506AA1),
              heroEnd: Color(0xFF344B7D),
              heroForeground: Colors.white,
            );

      case AppThemePreset.blue:
        return dark
            ? const _ThemePalette(
              background: Color(0xFF101924),
              surface: Color(0xFF192433),
              input: Color(0xFF202D3E),
              primary: Color(0xFF78A8EA),
              primaryForeground: Color(0xFF101924),
              secondary: Color(0xFF263A51),
              text: Color(0xFFF2F7FD),
              muted: Color(0xFFA2B1C4),
              outline: Color(0xFF2A394B),
              softAccent: Color(0xFF263A50),
              heroStart: Color(0xFF68A0E3),
              heroEnd: Color(0xFF477CBF),
              heroForeground: Colors.white,
            )
            : const _ThemePalette(
              background: Color(0xFFF4F9FE),
              surface: Colors.white,
              input: Color(0xFFFAFDFF),
              primary: Color(0xFF5F91D2),
              primaryForeground: Colors.white,
              secondary: Color(0xFFDCEAF9),
              text: Color(0xFF202B39),
              muted: Color(0xFF8493A4),
              outline: Color(0xFFE3EBF3),
              softAccent: Color(0xFFE2EFFB),
              heroStart: Color(0xFF68A0E3),
              heroEnd: Color(0xFF477CBF),
              heroForeground: Colors.white,
            );
    }
  }
}

class _ThemePalette {
  final Color background;
  final Color surface;
  final Color input;

  final Color primary;
  final Color primaryForeground;
  final Color secondary;

  final Color text;
  final Color muted;
  final Color outline;

  final Color softAccent;

  final Color heroStart;
  final Color heroEnd;
  final Color heroForeground;

  const _ThemePalette({
    required this.background,
    required this.surface,
    required this.input,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.text,
    required this.muted,
    required this.outline,
    required this.softAccent,
    required this.heroStart,
    required this.heroEnd,
    required this.heroForeground,
  });
}
