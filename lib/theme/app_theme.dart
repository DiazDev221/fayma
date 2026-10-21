import 'package:flutter/material.dart';

/// Couleurs relevées sur la maquette Figma (valeurs approchées).
/// À ajuster si la maquette utilise des teintes exactes différentes.
class AppColors {
  AppColors._();

  static const background = Color(0xFFF7F7F5);
  static const surface = Colors.white;
  static const border = Color(0xFFE6E6E3);

  static const textPrimary = Color(0xFF1B1B1F);
  static const textSecondary = Color(0xFF8A8A93);

  /// Vert menthe : remboursements, dépôts, boutons de validation.
  static const mint = Color(0xFF66DDB5);
  static const mintDark = Color(0xFF2FBF8E);
  static const mintSoft = Color(0xFFE1F5EA);

  /// Corail : montants dus, retards.
  static const coral = Color(0xFFF2685B);
  static const coralSoft = Color(0xFFFBE4E1);

  /// Indigo : achats à crédit, sélection.
  static const indigo = Color(0xFF5A6BE6);
  static const indigoSoft = Color(0xFFEDEFFD);
}

class AppTheme {
  AppTheme._();

  static const double radius = 14;
  static const double buttonHeight = 56;
  static const double pagePadding = 24;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.mint,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.mint,
      onPrimary: Colors.white,
      secondary: AppColors.indigo,
      onSecondary: Colors.white,
      error: AppColors.coral,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          )
          .copyWith(
            // Titre d'écran (ex : "Nouveau client").
            headlineSmall: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            // Gros montants (ex : "25 000 FCFA").
            headlineMedium: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            bodyMedium: const TextStyle(fontSize: 14),
            bodySmall: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.mint, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.mint,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
