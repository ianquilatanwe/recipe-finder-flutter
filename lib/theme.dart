import 'package:flutter/material.dart';

// Colours sampled from the Recipely kit. The kit puts white text on the light
// teal (2.2:1, fails WCAG), so teal backgrounds carry the kit's dark ink
// instead (7.1:1), and teal text uses a darker teal (5.8:1 on white).
const teal = Color(0xFF70B9BE);
const tealText = Color(0xFF2F6F74);
const deep = Color(0xFF042628);
const ink = Color(0xFF0A2533);
const muted = Color(0xFF556070);
const tint = Color(0xFFF1F5F5);

/// The system text size, at least 1. Not capped: layouts that size boxes
/// for text (featured strip, chip row, grid rows) must grow with it.
double textScale(BuildContext context) {
  final s = MediaQuery.textScalerOf(context).scale(1);
  return s < 1 ? 1 : s;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: teal,
    primary: tealText,
    onPrimary: Colors.white,
    secondary: deep,
    onSecondary: Colors.white,
    secondaryContainer: teal,
    onSecondaryContainer: deep,
    surface: Colors.white,
    onSurface: ink,
    onSurfaceVariant: muted,
    surfaceContainerHighest: tint,
  );
  final base = ThemeData(colorScheme: scheme, fontFamily: 'SofiaSans');
  return base.copyWith(
    scaffoldBackgroundColor: Colors.white,
    textTheme: base.textTheme
        .copyWith(
          headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        )
        .apply(bodyColor: ink, displayColor: ink),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
    badgeTheme: const BadgeThemeData(backgroundColor: deep),
    chipTheme: ChipThemeData(
      backgroundColor: tint,
      selectedColor: teal,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: base.textTheme.labelLarge?.copyWith(color: ink, fontWeight: FontWeight.w600),
      showCheckmark: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: tealText, width: 2),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: teal),
    navigationRailTheme: const NavigationRailThemeData(backgroundColor: Colors.white, indicatorColor: teal),
  );
}
