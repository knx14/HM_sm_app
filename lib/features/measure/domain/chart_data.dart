import 'dart:math';

/// TypeDから取得した測定データ1点（複素数 + 周波数）
class ChartData {
  /// 実部
  final double real;

  /// 虚部
  final double imag;

  /// 周波数 [Hz]
  final double frequency;

  /// 振幅（複素数の絶対値）
  late final double amplitude;

  /// 位相 [deg]
  late final double phase;

  ChartData({
    required this.real,
    required this.imag,
    required this.frequency,
  }) {
    amplitude = sqrt(real * real + imag * imag);
    phase = atan2(imag, real) * 180 / pi;
  }
}

