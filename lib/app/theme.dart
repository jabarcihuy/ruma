import 'package:flutter/material.dart';

abstract final class RumaColors {
  static const background = Color(0xFFF6F7F3);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF20241F);
  static const muted = Color(0xFF56614F);
  static const accent = Color(0xFFCF4924);
  static const accentInk = Color(0xFFA9361C);
  static const peach = Color(0xFFFFE6D6);
  static const soft = Color(0xFFFFF0E7);
  static const line = Color(0xFFE0E4DC);
  static const subtle = Color(0xFFEBEEE7);
  static const sage = Color(0xFFE5EDE1);
  static const dangerSoft = Color(0xFFF7DAD6);
  static const danger = Color(0xFFA62D25);
}

ThemeData rumaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: RumaColors.accent,
    primary: RumaColors.accent,
    onPrimary: Colors.white,
    surface: RumaColors.surface,
    onSurface: RumaColors.ink,
    error: RumaColors.danger,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Manrope',
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: RumaColors.line),
  );
  return base.copyWith(
    scaffoldBackgroundColor: RumaColors.background,
    textTheme: base.textTheme
        .copyWith(
          headlineMedium: const TextStyle(
            fontSize: 28,
            height: 36 / 28,
            fontWeight: FontWeight.w700,
            color: RumaColors.ink,
            letterSpacing: -.7,
          ),
          headlineSmall: const TextStyle(
            fontSize: 24,
            height: 32 / 24,
            fontWeight: FontWeight.w700,
            color: RumaColors.ink,
            letterSpacing: -.5,
          ),
          titleLarge: const TextStyle(
            fontSize: 22,
            height: 30 / 22,
            fontWeight: FontWeight.w700,
            color: RumaColors.ink,
          ),
          titleMedium: const TextStyle(
            fontSize: 15,
            height: 22 / 15,
            fontWeight: FontWeight.w700,
            color: RumaColors.ink,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            height: 22 / 14,
            color: RumaColors.ink,
          ),
          bodySmall: const TextStyle(
            fontSize: 12,
            height: 18 / 12,
            fontWeight: FontWeight.w500,
            color: RumaColors.muted,
          ),
        )
        .apply(fontFamily: 'Manrope'),
    appBarTheme: const AppBarTheme(
      backgroundColor: RumaColors.background,
      foregroundColor: RumaColors.accent,
      scrolledUnderElevation: 0,
      titleSpacing: 24,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: RumaColors.ink,
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      horizontalTitleGap: 12,
      minLeadingWidth: 22,
      minVerticalPadding: 12,
      titleTextStyle: base.textTheme.titleMedium?.copyWith(
        fontFamily: 'Manrope',
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w600,
        color: RumaColors.ink,
      ),
      subtitleTextStyle: const TextStyle(
        fontFamily: 'Manrope',
        fontSize: 12,
        height: 1.5,
        color: RumaColors.muted,
      ),
      iconColor: RumaColors.accent,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: Border(),
      collapsedShape: Border(),
      textColor: RumaColors.ink,
      collapsedTextColor: RumaColors.ink,
      iconColor: RumaColors.muted,
      collapsedIconColor: RumaColors.muted,
    ),
    inputDecorationTheme: InputDecorationTheme(
      errorMaxLines: 3,
      helperMaxLines: 3,
      hintStyle: const TextStyle(color: RumaColors.muted, fontSize: 14),
      floatingLabelStyle: const TextStyle(
        color: RumaColors.accentInk,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: RumaColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: RumaColors.accent, width: 2),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: RumaColors.danger),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: RumaColors.accentInk,
      ),
    ),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(48, 48))),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dialogTheme: DialogThemeData(
      backgroundColor: RumaColors.background,
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
