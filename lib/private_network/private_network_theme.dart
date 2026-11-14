import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

class PrivateNetworkTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static Color cardBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xff1c1c1e) : const Color(0xfff7f7f8);

  static Color inputBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xff2c2c2e) : const Color(0xffefeff1);

  static Color textMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xff8e8e93) : const Color(0xff6e6e73);

  static Color borderLine(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xff2c2c2e) : const Color(0xffe5e5ea);

  static Color primaryButtonBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xff111111);

  static Color primaryButtonFg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xff111111) : Colors.white;

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final ink = dark ? const Color(0xfff4f4f4) : const Color(0xff111111);
    final paper = dark ? const Color(0xff161618) : Colors.white;
    final bg = dark ? const Color(0xff0e0e10) : const Color(0xfff5f5f7);
    final line = dark ? const Color(0xff2c2c2e) : const Color(0xffe5e5ea);
    final subtle = dark ? const Color(0xff8e8e93) : const Color(0xff6e6e73);
    final container = dark ? const Color(0xff1c1c1e) : const Color(0xfff0f0f2);

    final colorScheme = (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
      primary: ink,
      onPrimary: paper,
      primaryContainer: dark ? const Color(0xff2c2c2e) : const Color(0xffeeeeee),
      onPrimaryContainer: ink,
      surface: paper,
      onSurface: ink,
      surfaceContainerLowest: dark ? const Color(0xff0d0d0d) : Colors.white,
      surfaceContainerLow: dark ? const Color(0xff141414) : const Color(0xfffafafc),
      surfaceContainer: container,
      surfaceContainerHigh: dark ? const Color(0xff242426) : const Color(0xffe8e8ec),
      surfaceContainerHighest: dark ? const Color(0xff2c2c2e) : const Color(0xffdedee3),
      onSurfaceVariant: subtle,
      outline: line,
      outlineVariant: dark ? const Color(0xff3a3a3c) : const Color(0xffd1d1d6),
    );

    final baseTextTheme = dark ? Typography.whiteMountainView : Typography.blackMountainView;
    final textTheme = baseTextTheme.apply(bodyColor: ink, displayColor: ink, decorationColor: ink);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      canvasColor: paper,
      cardColor: paper,
      dividerColor: line,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink),
        iconTheme: IconThemeData(color: ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: paper,
        modalBackgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      cardTheme: CardThemeData(
        color: paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: paper,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ink),
        contentTextStyle: TextStyle(fontSize: 14, color: ink),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: TextStyle(color: subtle),
        hintStyle: TextStyle(color: subtle),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ink, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: ink,
          foregroundColor: paper,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          foregroundColor: ink,
          side: BorderSide(color: line),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: paper,
        indicatorColor: dark ? const Color(0xff2c2c2e) : const Color(0xffeeeeee),
      ),
    );
  }
}
