import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTypography {
  const AppTypography._();

  static const TextTheme textTheme = TextTheme(
    headlineMedium: TextStyle(
      color: AppColors.ink,
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    titleLarge: TextStyle(
      color: AppColors.ink,
      fontSize: 20,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
    titleMedium: TextStyle(
      color: AppColors.ink,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    bodyLarge: TextStyle(
      color: AppColors.ink,
      fontSize: 16,
      height: 1.45,
      letterSpacing: 0,
    ),
    bodyMedium: TextStyle(
      color: AppColors.mutedInk,
      fontSize: 14,
      height: 1.45,
      letterSpacing: 0,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
  );
}
