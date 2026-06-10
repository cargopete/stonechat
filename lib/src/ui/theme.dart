import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// stonechat's design system — a "Black & Tan" dark palette: true off-black,
/// cool dark surfaces, and one disciplined warm amber accent (the brand mark's
/// colour). One radius scale, one accent, tinted depth.
abstract final class Stone {
  // Backgrounds (cool, near-black, layered by elevation).
  static const bg = Color(0xFF0B0D11);
  static const surface = Color(0xFF12151C); // bars, sheets
  static const surfaceHigh = Color(0xFF1B1F28); // incoming bubbles, inputs
  static const hairline = Color(0xFF222732);

  // The single accent — warm amber/tan.
  static const accent = Color(0xFFF2A65A);
  static const accentInk = Color(0xFF1A1206); // text on accent fills

  // Outgoing bubble — the "tan".
  static const sent = Color(0xFFE89A52);

  // Text.
  static const ink = Color(0xFFE8EAEF);
  static const inkDim = Color(0xFF8A93A3);
  static const inkFaint = Color(0xFF5B6470);

  // Semantic.
  static const online = Color(0xFF4ADE80);

  // One radius scale.
  static const rBubble = 22.0;
  static const rCard = 18.0;
  static const rPill = 100.0;
}

ThemeData stonechatTheme() {
  const scheme = ColorScheme.dark(
    primary: Stone.accent,
    onPrimary: Stone.accentInk,
    secondary: Stone.accent,
    onSecondary: Stone.accentInk,
    surface: Stone.bg,
    onSurface: Stone.ink,
    surfaceContainerHighest: Stone.surfaceHigh,
    onSurfaceVariant: Stone.inkDim,
    outline: Stone.hairline,
    error: Color(0xFFF87171),
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Stone.bg,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Stone.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Stone.ink,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    textTheme: base.textTheme
        .apply(bodyColor: Stone.ink, displayColor: Stone.ink)
        .copyWith(
          titleLarge: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: Stone.ink,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: Stone.ink,
          ),
          bodyMedium: const TextStyle(fontSize: 15.5, height: 1.3, color: Stone.ink),
          labelSmall: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            color: Stone.inkDim,
          ),
        ),
    iconTheme: const IconThemeData(color: Stone.inkDim),
    dividerTheme: const DividerThemeData(
      color: Stone.hairline,
      thickness: 1,
      space: 1,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Stone.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Stone.rCard),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Stone.surface,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Stone.surfaceHigh,
      contentTextStyle: const TextStyle(color: Stone.ink),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Stone.surfaceHigh,
      hintStyle: const TextStyle(color: Stone.inkFaint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Stone.rPill),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Stone.rPill),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Stone.rPill),
        borderSide: const BorderSide(color: Stone.accent, width: 1.4),
      ),
    ),
  );
}
