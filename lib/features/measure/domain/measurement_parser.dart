import 'chart_data.dart';

/// TypeDの受信行をパースする純粋関数群（exec測定想定）
class MeasurementParser {
  /// `* idx real imag` 形式の行から ChartData を生成する（exec測定）。
  ///
  /// - `frequency` は呼び出し側で計算して渡す（例: fstart + fdelta * index）
  static ChartData? tryParseExecDataLine(String line, {required double frequency}) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('*')) return null;
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 4) return null;

    final real = double.tryParse(parts[2]);
    final imag = double.tryParse(parts[3]);
    if (real == null || imag == null) return null;

    return ChartData(real: real, imag: imag, frequency: frequency);
  }

  /// BG（null測定）: `* index freq real imag` 形式の行から ChartData を生成する。
  static ChartData? tryParseBgDataLine(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('*')) return null;
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 5) return null;

    // parts[1] に周波数が入る（添付bg_screen.dartの実装に合わせる）
    final frequency = double.tryParse(parts[1]);
    final real = double.tryParse(parts[3]);
    final imag = double.tryParse(parts[4]);
    if (frequency == null || real == null || imag == null) return null;

    return ChartData(real: real, imag: imag, frequency: frequency);
  }

  static bool isOkLine(String line) {
    final t = line.trim();
    return t == 'ok' || t == 'OK';
  }

  static bool isErrorLine(String line) {
    final t = line.trim().toLowerCase();
    return t == 'error' || t == 'ng';
  }

  /// TypeDのID行っぽいもの（例: HM24D1234）
  static String? tryParseAmpId(String line) {
    final t = line.trim();
    if (!t.startsWith('HM')) return null;
    return t.split(RegExp(r'\s+')).first;
  }
}

