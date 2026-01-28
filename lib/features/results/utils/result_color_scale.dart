import 'package:flutter/material.dart';

class ResultColorScale {
  static const Color missing = Color(0xFFBDBDBD); // グレー（データなし）

  // 通常: min-max 正規化（欠損は呼び出し側でmissing）
  static Color normalColor({
    required double value,
    required double min,
    required double max,
  }) {
    if (max <= min) {
      return _neutralNormal();
    }
    final t = ((value - min) / (max - min)).clamp(0.0, 1.0);
    // light green -> dark green
    return Color.lerp(const Color(0xFFE8F5E9), const Color(0xFF1B5E20), t)!;
  }

  // 比較: ±Δmax 正規化（欠損は呼び出し側でmissing）
  static Color diffColor({
    required double diffValue,
    required double deltaMax,
  }) {
    if (deltaMax <= 0) {
      return _neutralDiff();
    }
    final n = (diffValue / deltaMax).clamp(-1.0, 1.0);
    if (n == 0) return _neutralDiff();
    if (n < 0) {
      final t = (-n).clamp(0.0, 1.0);
      return Color.lerp(_neutralDiff(), const Color(0xFF1565C0), t)!; // white -> blue
    } else {
      final t = n.clamp(0.0, 1.0);
      return Color.lerp(_neutralDiff(), const Color(0xFFC62828), t)!; // white -> red
    }
  }

  static Color _neutralNormal() => const Color(0xFF66BB6A); // 均一（中立）
  static Color _neutralDiff() => Colors.white;
}

