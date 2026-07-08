import 'package:flutter/material.dart';

/// ホーム画面・圃場一覧向けのフォントサイズ定義。
class AppTextStyles {
  AppTextStyles._();

  static const double homeFarmName = 18;
  static const double homeValueLarge = 16;
  static const double homeLabel = 13;
  static const double homeDate = 13;
  static const double homeAux = 14;
  static const double homeActionLabel = 19;
  static const double homeActionSubtitle = 15;
  static const double homeAccountName = 18;

  static TextStyle homeFarmNameStyle(TextTheme theme) {
    return theme.titleMedium?.copyWith(
          fontSize: homeFarmName,
          fontWeight: FontWeight.w800,
        ) ??
        const TextStyle(fontSize: homeFarmName, fontWeight: FontWeight.w800);
  }

  static TextStyle homeAuxStyle(ColorScheme colorScheme) {
    return TextStyle(
      fontSize: homeAux,
      color: colorScheme.onSurface.withValues(alpha: 0.68),
    );
  }

  static TextStyle homeDateStyle({Color? color, FontWeight? fontWeight}) {
    return TextStyle(fontSize: homeDate, color: color, fontWeight: fontWeight);
  }

  static TextStyle homeLabelStyle(ColorScheme colorScheme) {
    return TextStyle(
      fontSize: homeLabel,
      color: colorScheme.onSurface.withValues(alpha: 0.62),
      fontWeight: FontWeight.w700,
    );
  }

  static TextStyle homeValueLargeStyle({Color? color}) {
    return TextStyle(
      fontSize: homeValueLarge,
      fontWeight: FontWeight.w800,
      color: color,
    );
  }

  static TextStyle homeActionLabelStyle({Color color = Colors.white}) {
    return TextStyle(
      color: color,
      fontSize: homeActionLabel,
      fontWeight: FontWeight.w800,
    );
  }

  static TextStyle homeActionSubtitleStyle({required Color color}) {
    return TextStyle(
      color: color,
      fontSize: homeActionSubtitle,
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle homeAccountNameStyle({
    Color? color,
    FontWeight fontWeight = FontWeight.w700,
  }) {
    return TextStyle(
      fontSize: homeAccountName,
      fontWeight: fontWeight,
      color: color,
    );
  }
}
