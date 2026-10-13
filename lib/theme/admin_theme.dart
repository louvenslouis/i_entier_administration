// Flutter 3.44 moved CupertinoPageTransitionsBuilder out of material.dart.
// ignore: unnecessary_import
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Palette partagée par l’expérience I-ENTIER.
abstract final class AdminColors {
  static const primary = Color(0xFF375747);
  static const primaryDark = Color(0xFF263E32);
  static const primarySoft = Color(0xFFE8F0E8);
  static const teal = Color(0xFF477A68);
  static const navy = Color(0xFF1D322A);
  static const ink = Color(0xFF293C34);
  static const muted = Color(0xFF606D64);
  static const border = Color(0xFFDDE2D9);
  static const canvas = Color(0xFFF6F5F0);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFEFEEE8);
  static const tealSoft = Color(0xFFE8EFE5);
  static const disabled = Color(0xFFD9DED5);
  static const error = Color(0xFFB44335);
  static const success = Color(0xFF357351);
  static const accent = Color(0xFFC7D5AC);
  static const danger = error;
  static const warning = Color(0xFF95632B);
}

/// Même finition pour les cartes, qu’elles utilisent Material ou Container.
abstract final class AdminDecorations {
  static const controlRadius = BorderRadius.all(Radius.circular(12));
  static const cardRadius = BorderRadius.all(Radius.circular(16));
  static const card = BoxDecoration(
    color: AdminColors.surface,
    borderRadius: cardRadius,
    border: Border.fromBorderSide(BorderSide(color: AdminColors.border)),
  );
  static const cardShadow = [
    BoxShadow(color: Color(0x061D322A), blurRadius: 12, offset: Offset(0, 3)),
  ];
  static final raisedCard = card.copyWith(boxShadow: cardShadow);
}

/// Fondation Material 3 commune à tous les écrans.
abstract final class AdminTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AdminColors.primary,
          brightness: Brightness.light,
          primary: AdminColors.primary,
          secondary: AdminColors.teal,
          error: AdminColors.error,
          surface: AdminColors.surface,
        ).copyWith(
          onPrimary: AdminColors.surface,
          primaryContainer: AdminColors.primarySoft,
          onPrimaryContainer: AdminColors.primaryDark,
          secondaryContainer: AdminColors.tealSoft,
          onSecondaryContainer: AdminColors.success,
          onSurface: AdminColors.ink,
          onSurfaceVariant: AdminColors.muted,
          outline: AdminColors.border,
          outlineVariant: const Color(0xFFECEEE6),
          surfaceContainerLowest: AdminColors.surface,
          surfaceContainerLow: const Color(0xFFFAFAF6),
          surfaceContainer: AdminColors.surfaceMuted,
          surfaceContainerHigh: const Color(0xFFE8EBE2),
          surfaceContainerHighest: const Color(0xFFE1E5DB),
        );

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AdminColors.canvas,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    return base.copyWith(
      // Conserve les tailles et métriques de la typographie Material.
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall!.copyWith(
          color: AdminColors.navy,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.1,
        ),
        headlineLarge: base.textTheme.headlineLarge!.copyWith(
          color: AdminColors.navy,
          fontWeight: FontWeight.w700,
          letterSpacing: -.8,
        ),
        headlineMedium: base.textTheme.headlineMedium!.copyWith(
          color: AdminColors.navy,
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
        ),
        headlineSmall: base.textTheme.headlineSmall!.copyWith(
          color: AdminColors.navy,
          fontWeight: FontWeight.w700,
          letterSpacing: -.25,
        ),
        titleLarge: base.textTheme.titleLarge!.copyWith(
          color: AdminColors.navy,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium!.copyWith(
          color: AdminColors.navy,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: base.textTheme.titleSmall!.copyWith(
          color: AdminColors.navy,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: base.textTheme.bodyLarge!.copyWith(
          color: AdminColors.ink,
          height: 1.45,
        ),
        bodyMedium: base.textTheme.bodyMedium!.copyWith(
          color: AdminColors.ink,
          height: 1.4,
        ),
        bodySmall: base.textTheme.bodySmall!.copyWith(
          color: AdminColors.muted,
          height: 1.35,
        ),
        labelLarge: base.textTheme.labelLarge!.copyWith(
          fontWeight: FontWeight.w700,
        ),
        labelMedium: base.textTheme.labelMedium!.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AdminColors.canvas,
        foregroundColor: AdminColors.navy,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        toolbarHeight: 64,
        iconTheme: IconThemeData(color: AdminColors.navy),
        actionsIconTheme: IconThemeData(color: AdminColors.navy),
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: AdminColors.navy,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: AdminColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AdminDecorations.cardRadius,
          side: const BorderSide(color: AdminColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: AdminColors.muted,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: AdminColors.muted,
        ),
        prefixIconColor: WidgetStateColor.resolveWith(_inputIconColor),
        suffixIconColor: WidgetStateColor.resolveWith(_inputIconColor),
        floatingLabelStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: AdminColors.primary,
          fontWeight: FontWeight.w700,
        ),
        errorMaxLines: 2,
        disabledBorder: const OutlineInputBorder(
          borderRadius: AdminDecorations.controlRadius,
          borderSide: BorderSide(color: AdminColors.border),
        ),
        border: OutlineInputBorder(
          borderRadius: AdminDecorations.controlRadius,
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AdminDecorations.controlRadius,
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AdminDecorations.controlRadius,
          borderSide: const BorderSide(color: AdminColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AdminDecorations.controlRadius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AdminDecorations.controlRadius,
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AdminColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AdminColors.disabled,
          disabledForegroundColor: AdminColors.muted,
          elevation: 0,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AdminDecorations.controlRadius,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminColors.primary,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          side: const BorderSide(color: AdminColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: AdminDecorations.controlRadius,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AdminColors.primaryDark,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AdminColors.navy,
          minimumSize: const Size.square(48),
          shape: const CircleBorder(),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AdminColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 1,
        hoverElevation: 1,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 72,
        backgroundColor: AdminColors.surface,
        indicatorColor: AdminColors.primarySoft,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: WidgetStatePropertyAll(IconThemeData(size: 24)),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: AdminColors.primarySoft,
        selectedIconTheme: IconThemeData(color: AdminColors.primary, size: 25),
        unselectedIconTheme: IconThemeData(color: AdminColors.muted, size: 24),
        selectedLabelTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: AdminColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: AdminColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AdminColors.primaryDark,
        unselectedLabelColor: AdminColors.muted,
        labelStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        indicatorColor: AdminColors.primary,
        dividerColor: AdminColors.border,
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AdminColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shadowColor: Color(0x24102A56),
        shape: RoundedRectangleBorder(
          borderRadius: AdminDecorations.controlRadius,
          side: BorderSide(color: AdminColors.border),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AdminColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AdminColors.surface,
        modalBarrierColor: Color(0x8F102A56),
        showDragHandle: true,
        dragHandleColor: Color(0xFFB8C3D1),
        dragHandleSize: Size(42, 4),
        elevation: 0,
        modalElevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AdminColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: AdminColors.navy,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: AdminColors.ink,
          fontSize: 15,
          height: 1.45,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AdminColors.navy,
        contentTextStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: const Color(0xFF9FD8FF),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: AdminDecorations.controlRadius,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AdminColors.border,
        thickness: 1,
        space: 1,
      ),
      dataTableTheme: const DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll(AdminColors.surfaceMuted),
        headingTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: AdminColors.muted,
          fontWeight: FontWeight.w600,
        ),
        dataTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: AdminColors.ink,
          fontSize: 14,
        ),
        dividerThickness: 1,
        horizontalMargin: 20,
        columnSpacing: 24,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AdminColors.surfaceMuted,
        selectedColor: AdminColors.primarySoft,
        disabledColor: const Color(0xFFF1F3F6),
        side: const BorderSide(color: AdminColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: AdminColors.navy,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: AdminColors.primaryDark,
          fontWeight: FontWeight.w700,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AdminColors.primary,
        textColor: AdminColors.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minTileHeight: 56,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AdminColors.navy,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        waitDuration: const Duration(milliseconds: 450),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AdminColors.primary,
        linearTrackColor: AdminColors.primarySoft,
        circularTrackColor: AdminColors.primarySoft,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static Color _inputIconColor(Set<WidgetState> states) {
    if (states.contains(WidgetState.disabled)) return AdminColors.muted;
    if (states.contains(WidgetState.error)) return AdminColors.error;
    if (states.contains(WidgetState.focused)) return AdminColors.primary;
    return AdminColors.muted;
  }
}

ThemeData buildAdminTheme() => AdminTheme.light;

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
          borderRadius: BorderRadius.circular(12),
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
              fontFamily: 'Roboto',
              color: light ? Colors.white : AdminColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: .5,
            ),
          ),
          Text(
            'ADMINISTRATION',
            style: TextStyle(
              fontFamily: 'Roboto',
              color: light ? const Color(0xFFD8E5D5) : AdminColors.primary,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
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
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AdminColors.border),
    ),
    child: child,
  );
}
