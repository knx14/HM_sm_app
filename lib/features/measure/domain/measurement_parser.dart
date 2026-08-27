/// TypeDの受信行をパースする純粋関数群（exec測定想定）
class MeasurementParser {
  static bool isOkLine(String line) {
    final t = line.trim();
    return t == 'ok' || t == 'OK';
  }

  static bool isErrorLine(String line) {
    final t = line.trim().toLowerCase();
    return t == 'error' || t == 'ng';
  }

  /// TypeDのID行（例: HM24D20018, 1.4.2B, 1.51B）
  static String? tryParseAmpId(String line) {
    final t = line.trim();
    final match = RegExp(r'\bHM[A-Za-z0-9_-]+').firstMatch(t);
    if (match == null) return null;
    return t.substring(match.start).trim();
  }
}
