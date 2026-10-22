import 'package:flutter/material.dart';

/// Palette Fayma.
///
/// Les teintes « soft » servent de fonds, tandis que les teintes foncées
/// garantissent un contraste suffisant pour le texte et les actions.
class AppColors {
  AppColors._();

  // Fond et surfaces
  static const background = Color(0xFFF5F6F2);
  static const surface = Colors.white;
  static const surfaceMuted = Color(0xFFF0F3EF);
  static const border = Color(0xFFE1E5DF);
  static const cardShadow = Color(0x140F172A);

  // Texte
  static const ink = Color(0xFF101828);
  static const inkSoft = Color(0xFF344054);
  static const textPrimary = ink;
  static const textSecondary = Color(0xFF5D6675);

  // Vert menthe : succès, remboursements, actions principales.
  static const mint = Color(0xFF087A55);
  static const mintDark = Color(0xFF066B4A);
  static const mintBright = Color(0xFF5FE3B4);
  static const mintSoft = Color(0xFFE7F8F1);

  // Corail : dettes, alertes, actions destructives.
  static const coral = Color(0xFFCC2418);
  static const coralDark = Color(0xFFB42318);
  static const coralBright = Color(0xFFFF7A6E);
  static const coralSoft = Color(0xFFFEECEB);

  // Indigo : achats à crédit, sélection, accents secondaires.
  static const indigo = Color(0xFF4F5BD5);
  static const indigoDark = Color(0xFF3D47B8);
  static const indigoBright = Color(0xFF8D96FF);
  static const indigoSoft = Color(0xFFEEF0FF);

  // Fonds sombres des cartes héro.
  static const inkBackground = Color(0xFF0A1F1A);
  static const inkBackgroundEnd = Color(0xFF103D2F);
}

class AppGradients {
  AppGradients._();

  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.inkBackground, AppColors.inkBackgroundEnd],
  );

  static const ink = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF101828), Color(0xFF273247)],
  );

  static const mint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A8F63), Color(0xFF066B4A)],
  );

  static const indigo = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF5B67E8), Color(0xFF3D47B8)],
  );
}

class AppTheme {
  AppTheme._();

  static const double radius = 18;
  static const double cardRadius = 24;
  static const double buttonRadius = 16;
  static const double buttonHeight = 56;
  static const double pagePadding = 20;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.mint,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.mint,
      onPrimary: Colors.white,
      secondary: AppColors.indigo,
      onSecondary: Colors.white,
      tertiary: AppColors.coral,
      onTertiary: Colors.white,
      error: AppColors.coral,
      onError: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      outline: AppColors.border,
      outlineVariant: AppColors.surfaceMuted,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Manrope',
      splashFactory: InkRipple.splashFactory,
    );

    final textTheme = base.textTheme
        .apply(
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        )
        .copyWith(
          displaySmall: const TextStyle(
            fontSize: 34,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.9,
            height: 1.1,
          ),
          headlineMedium: const TextStyle(
            fontSize: 30,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            height: 1.15,
          ),
          headlineSmall: const TextStyle(
            fontSize: 24,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.2,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            height: 1.25,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          titleSmall: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
          bodyLarge: const TextStyle(
            fontSize: 15.5,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w400,
            height: 1.45,
          ),
          bodyMedium: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w400,
            height: 1.45,
          ),
          bodySmall: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
          labelLarge: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
          labelMedium: const TextStyle(
            fontSize: 12,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.25,
          ),
          labelSmall: const TextStyle(
            fontSize: 11,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.35,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        iconTheme: IconThemeData(color: AppColors.ink, size: 22),
        actionsIconTheme: IconThemeData(color: AppColors.ink, size: 22),
        titleTextStyle: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: AppColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.mintDark,
          fontWeight: FontWeight.w700,
        ),
        prefixIconColor: AppColors.textSecondary,
        suffixIconColor: AppColors.textSecondary,
        errorStyle: const TextStyle(
          color: AppColors.coral,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: AppColors.mint, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: AppColors.coral, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: AppColors.coral, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.mint,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textSecondary,
          minimumSize: const Size.fromHeight(buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.surface,
          minimumSize: const Size.fromHeight(buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.mintDark,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          highlightColor: AppColors.mintSoft,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 4,
        hoverElevation: 4,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        extendedTextStyle: textTheme.labelLarge?.copyWith(
          color: Colors.white,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.mintSoft,
        disabledColor: AppColors.surfaceMuted,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.mintDark,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: AppColors.mintBright,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.mint,
        linearTrackColor: AppColors.surfaceMuted,
        circularTrackColor: AppColors.surfaceMuted,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(10),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.mint,
        selectionColor: AppColors.mint.withValues(alpha: 0.25),
        selectionHandleColor: AppColors.mint,
      ),
    );
  }
}
