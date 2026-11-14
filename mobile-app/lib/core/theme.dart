import 'package:flutter/material.dart';

class FloraPalette {
  static const leaf = Color(0xFF2F7D46);
  static const leafDeep = Color(0xFF164A2A);
  static const mint = Color(0xFFE8F4E6);
  static const mist = Color(0xFFF6FAF3);
  static const water = Color(0xFF2E9BC6);
  static const sun = Color(0xFFF1B84B);
  static const soil = Color(0xFF8B5E3C);
}

ThemeData floraTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: FloraPalette.leaf,
    primary: FloraPalette.leaf,
    secondary: FloraPalette.water,
    tertiary: FloraPalette.sun,
    surface: Colors.white,
    brightness: Brightness.light,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: FloraPalette.mist,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: FloraPalette.leafDeep,
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Color(0xFFE3EBDD)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: FloraPalette.mint,
      selectedColor: FloraPalette.leaf,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: FloraPalette.leafDeep),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: const Color(0xFFEAF4E7),
      selectedIconTheme: const IconThemeData(color: Colors.white),
      selectedLabelTextStyle: const TextStyle(color: FloraPalette.leafDeep, fontWeight: FontWeight.w800),
      unselectedIconTheme: const IconThemeData(color: Color(0xFF6D8170)),
      unselectedLabelTextStyle: const TextStyle(color: Color(0xFF6D8170)),
      indicatorColor: FloraPalette.leaf,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: FloraPalette.leaf,
      textColor: FloraPalette.leafDeep,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FloraPalette.leaf,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: FloraPalette.water,
      thumbColor: FloraPalette.leaf,
      overlayColor: Color(0x222E9BC6),
    ),
  );
}

ThemeData floraDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: FloraPalette.leaf,
    primary: const Color(0xFF8BD79B),
    secondary: FloraPalette.water,
    tertiary: FloraPalette.sun,
    brightness: Brightness.dark,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF0D1710),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Color(0xFFDCEBDD),
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF152419),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Color(0xFF2A3D2D)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF1D3323),
      selectedColor: FloraPalette.leaf,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDCEBDD)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Color(0xFF8BD79B),
      textColor: Color(0xFFDCEBDD),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FloraPalette.leaf,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: FloraPalette.water,
      thumbColor: Color(0xFF8BD79B),
      overlayColor: Color(0x222E9BC6),
    ),
  );
}
