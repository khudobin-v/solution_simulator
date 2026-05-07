import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── ThemeExtension ────────────────────────────────────────────────────────────

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color cloudCanvas;
  final Color elevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color borderLight;
  final Color accent;
  final Color electricBlue;
  final Color vividCrimson;
  final Color vividTeal;
  final Color skyBlue;
  final Color solidCell;
  final Color semiCell;
  final Color liquidCell;

  const AppColorsExtension({
    required this.cloudCanvas,
    required this.elevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.borderLight,
    required this.accent,
    required this.electricBlue,
    required this.vividCrimson,
    required this.vividTeal,
    required this.skyBlue,
    required this.solidCell,
    required this.semiCell,
    required this.liquidCell,
  });

  static const AppColorsExtension light = AppColorsExtension(
    cloudCanvas:   Color(0xFFFAFAFA),
    elevated:      Color(0xFFFFFFFF),
    textPrimary:   Color(0xFF171717),
    textSecondary: Color(0xFF4D4D4D),
    textMuted:     Color(0xFF7D7D7D),
    borderLight:   Color(0xFFEBEBEB),
    accent:        Color(0xFF171717),
    electricBlue:  Color(0xFF0070F3),
    vividCrimson:  Color(0xFFE5484D),
    vividTeal:     Color(0xFF45DEC5),
    skyBlue:       Color(0xFF52AEFF),
    solidCell:     Color(0xFF171717),
    semiCell:      Color(0xFF7D7D7D),
    liquidCell:    Color(0xFFF0F9FF),
  );

  static const AppColorsExtension dark = AppColorsExtension(
    cloudCanvas:   Color(0xFF0A0A0A),
    elevated:      Color(0xFF141414),
    textPrimary:   Color(0xFFEDEDED),
    textSecondary: Color(0xFFA3A3A3),
    textMuted:     Color(0xFF666666),
    borderLight:   Color(0xFF282828),
    accent:        Color(0xFFEDEDED),
    electricBlue:  Color(0xFF0070F3),
    vividCrimson:  Color(0xFFE5484D),
    vividTeal:     Color(0xFF45DEC5),
    skyBlue:       Color(0xFF52AEFF),
    solidCell:     Color(0xFFE5E5E5),
    semiCell:      Color(0xFF737373),
    liquidCell:    Color(0xFF0D1827),
  );

  @override
  AppColorsExtension copyWith({
    Color? cloudCanvas,
    Color? elevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? borderLight,
    Color? accent,
    Color? electricBlue,
    Color? vividCrimson,
    Color? vividTeal,
    Color? skyBlue,
    Color? solidCell,
    Color? semiCell,
    Color? liquidCell,
  }) {
    return AppColorsExtension(
      cloudCanvas:   cloudCanvas   ?? this.cloudCanvas,
      elevated:      elevated      ?? this.elevated,
      textPrimary:   textPrimary   ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted:     textMuted     ?? this.textMuted,
      borderLight:   borderLight   ?? this.borderLight,
      accent:        accent        ?? this.accent,
      electricBlue:  electricBlue  ?? this.electricBlue,
      vividCrimson:  vividCrimson  ?? this.vividCrimson,
      vividTeal:     vividTeal     ?? this.vividTeal,
      skyBlue:       skyBlue       ?? this.skyBlue,
      solidCell:     solidCell     ?? this.solidCell,
      semiCell:      semiCell      ?? this.semiCell,
      liquidCell:    liquidCell    ?? this.liquidCell,
    );
  }

  @override
  AppColorsExtension lerp(AppColorsExtension? other, double t) {
    if (other == null) return this;
    return AppColorsExtension(
      cloudCanvas:   Color.lerp(cloudCanvas,   other.cloudCanvas,   t)!,
      elevated:      Color.lerp(elevated,      other.elevated,      t)!,
      textPrimary:   Color.lerp(textPrimary,   other.textPrimary,   t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted:     Color.lerp(textMuted,     other.textMuted,     t)!,
      borderLight:   Color.lerp(borderLight,   other.borderLight,   t)!,
      accent:        Color.lerp(accent,        other.accent,        t)!,
      electricBlue:  Color.lerp(electricBlue,  other.electricBlue,  t)!,
      vividCrimson:  Color.lerp(vividCrimson,  other.vividCrimson,  t)!,
      vividTeal:     Color.lerp(vividTeal,     other.vividTeal,     t)!,
      skyBlue:       Color.lerp(skyBlue,       other.skyBlue,       t)!,
      solidCell:     Color.lerp(solidCell,     other.solidCell,     t)!,
      semiCell:      Color.lerp(semiCell,      other.semiCell,      t)!,
      liquidCell:    Color.lerp(liquidCell,    other.liquidCell,    t)!,
    );
  }
}

// ── BuildContext extension ─────────────────────────────────────────────────────

extension AppColorsContext on BuildContext {
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}

// ── Static class (kept for grid_painter.dart which has no context) ────────────

class AppColors {
  static const cloudCanvas   = Color(0xFFFAFAFA);
  static const elevated      = Color(0xFFFFFFFF);
  static const textPrimary   = Color(0xFF171717);
  static const textSecondary = Color(0xFF4D4D4D);
  static const textMuted     = Color(0xFF7D7D7D);
  static const borderLight   = Color(0xFFEBEBEB);
  static const electricBlue  = Color(0xFF0070F3);
  static const vividCrimson  = Color(0xFFE5484D);
  static const vividTeal     = Color(0xFF45DEC5);
  static const skyBlue       = Color(0xFF52AEFF);
  static const solidCell     = Color(0xFF171717);
  static const semiCell      = Color(0xFF7D7D7D);
  static const liquidCell    = Color(0xFFF0F9FF);
}

// ── Theme builders ────────────────────────────────────────────────────────────

ThemeData buildTheme({Color accent = const Color(0xFF171717)}) {
  final colors = AppColorsExtension.light.copyWith(accent: accent);
  final base = ThemeData.light(useMaterial3: true);
  final textTheme = GoogleFonts.interTextTheme(base.textTheme);

  return base.copyWith(
    extensions: [colors],
    colorScheme: ColorScheme.light(
      surface: colors.cloudCanvas,
      primary: colors.textPrimary,
      secondary: colors.electricBlue,
      onPrimary: Colors.white,
      onSurface: colors.textPrimary,
      outline: colors.borderLight,
    ),
    scaffoldBackgroundColor: colors.cloudCanvas,
    textTheme: textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(
        fontSize: 48, fontWeight: FontWeight.w700,
        color: colors.textPrimary, letterSpacing: -0.72,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontSize: 24, fontWeight: FontWeight.w600,
        color: colors.textPrimary, letterSpacing: -0.48,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontSize: 14, fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        fontSize: 14, color: colors.textSecondary,
      ),
      bodySmall: textTheme.bodySmall?.copyWith(
        fontSize: 12, color: colors.textMuted,
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.elevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: colors.borderLight),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.elevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      labelStyle: TextStyle(fontSize: 13, color: colors.textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        side: BorderSide(color: colors.textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      thumbColor: accent,
      inactiveTrackColor: colors.borderLight,
      overlayColor: accent.withAlpha(20),
      trackHeight: 2,
    ),
    dividerTheme: DividerThemeData(
      color: colors.borderLight,
      thickness: 1,
      space: 0,
    ),
  );
}

ThemeData buildDarkTheme({Color accent = const Color(0xFFEDEDED)}) {
  final colors = AppColorsExtension.dark.copyWith(accent: accent);
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = GoogleFonts.interTextTheme(base.textTheme);

  return base.copyWith(
    extensions: [colors],
    colorScheme: ColorScheme.dark(
      surface: colors.cloudCanvas,
      primary: colors.textPrimary,
      secondary: colors.electricBlue,
      onPrimary: Colors.black,
      onSurface: colors.textPrimary,
      outline: colors.borderLight,
    ),
    scaffoldBackgroundColor: colors.cloudCanvas,
    textTheme: textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(
        fontSize: 48, fontWeight: FontWeight.w700,
        color: colors.textPrimary, letterSpacing: -0.72,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontSize: 24, fontWeight: FontWeight.w600,
        color: colors.textPrimary, letterSpacing: -0.48,
      ),
      titleMedium: textTheme.titleMedium?.copyWith(
        fontSize: 14, fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        fontSize: 14, color: colors.textSecondary,
      ),
      bodySmall: textTheme.bodySmall?.copyWith(
        fontSize: 12, color: colors.textMuted,
      ),
    ),
    cardTheme: CardThemeData(
      color: colors.elevated,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: colors.borderLight),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.elevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: colors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      labelStyle: TextStyle(fontSize: 13, color: colors.textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        side: BorderSide(color: colors.textPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      thumbColor: accent,
      inactiveTrackColor: colors.borderLight,
      overlayColor: accent.withAlpha(20),
      trackHeight: 2,
    ),
    dividerTheme: DividerThemeData(
      color: colors.borderLight,
      thickness: 1,
      space: 0,
    ),
  );
}
