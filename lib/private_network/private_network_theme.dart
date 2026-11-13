import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

class PrivateNetworkTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final ink = dark ? const Color(0xfff4f4f4) : const Color(0xff111111);
    final paper = dark ? const Color(0xff171717) : Colors.white;
    final line = dark ? const Color(0xff383838) : const Color(0xffdddddd);
    final scheme = ColorScheme.fromSeed(seedColor: Colors.grey, brightness: brightness).copyWith(
      primary: ink,
      onPrimary: paper,
      surface: paper,
      onSurface: ink,
      primaryContainer: dark ? const Color(0xff303030) : const Color(0xffeeeeee),
      onPrimaryContainer: ink,
      outline: line,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
      scaffoldBackgroundColor: dark ? const Color(0xff101010) : const Color(0xffefefef),
      appBarTheme: AppBarTheme(backgroundColor: paper, foregroundColor: ink, elevation: 0, scrolledUnderElevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: ink, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          backgroundColor: ink,
          foregroundColor: paper,
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          foregroundColor: ink,
          side: BorderSide(color: line),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: paper,
        indicatorColor: dark ? const Color(0xff383838) : const Color(0xffeeeeee),
      ),
      dividerColor: line,
    );
  }
}
