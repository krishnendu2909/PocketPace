import 'package:material_ui/material_ui.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF16745D);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.light,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F7F6),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFF5F7F6),
      elevation: 0,
      centerTitle: false,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF101715),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF101715),
      elevation: 0,
      centerTitle: false,
    ),
  );
}