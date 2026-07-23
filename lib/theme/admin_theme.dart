import 'package:flutter/material.dart';

class AdminColors {
  static const ink = Color(0xFF132238);
  static const muted = Color(0xFF687386);
  static const canvas = Color(0xFFF4F6F9);
  static const border = Color(0xFFE0E5EC);
  static const primary = Color(0xFF2457D6);
  static const primaryDark = Color(0xFF183B91);
  static const primarySoft = Color(0xFFEAF0FF);
  static const navy = Color(0xFF101D33);
  static const success = Color(0xFF16845B);
  static const warning = Color(0xFFB66A06);
  static const danger = Color(0xFFB42318);
}

ThemeData buildAdminTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AdminColors.canvas,
  fontFamily: 'Arial',
  colorScheme: ColorScheme.fromSeed(
    seedColor: AdminColors.primary,
    primary: AdminColors.primary,
    surface: Colors.white,
    error: AdminColors.danger,
  ),
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      color: AdminColors.ink,
      fontWeight: FontWeight.w900,
      letterSpacing: -.8,
    ),
    headlineMedium: TextStyle(
      color: AdminColors.ink,
      fontWeight: FontWeight.w900,
      letterSpacing: -.5,
    ),
    titleLarge: TextStyle(color: AdminColors.ink, fontWeight: FontWeight.w800),
    bodyLarge: TextStyle(color: AdminColors.ink, height: 1.45),
    bodyMedium: TextStyle(color: AdminColors.muted, height: 1.4),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: AdminColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: AdminColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: AdminColors.primary, width: 1.5),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      side: const BorderSide(color: AdminColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      textStyle: const TextStyle(fontWeight: FontWeight.w700),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
  ),
);

class AdminBrand extends StatelessWidget {
  final bool light;

  const AdminBrand({super.key, this.light = false});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: light ? Colors.white : AdminColors.primary,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          Icons.admin_panel_settings_rounded,
          color: light ? AdminColors.primary : Colors.white,
          size: 25,
        ),
      ),
      const SizedBox(width: 11),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'i-ENTIER',
            style: TextStyle(
              color: light ? Colors.white : AdminColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
          Text(
            'ADMINISTRATION',
            style: TextStyle(
              color: light ? const Color(0xFFBFD0FF) : AdminColors.primary,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.25,
            ),
          ),
        ],
      ),
    ],
  );
}

class AdminPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AdminPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AdminColors.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x09132238),
          blurRadius: 18,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: child,
  );
}
