/// 圃場 × 測定日の測定番号。ピンのラベルと、ローカル／クラウドの突合キー。
class MeasurementNumber {
  const MeasurementNumber._();

  /// 端末が知っている番号の最大値 + 1。番号が無ければ 1。欠番は詰めない。
  static int next(Iterable<int?> existing) {
    var maxNumber = 0;
    for (final number in existing) {
      if (number != null && number > maxNumber) {
        maxNumber = number;
      }
    }
    return maxNumber + 1;
  }

  /// null は末尾。表示の並び用。
  static int compareNullable(int? a, int? b) {
    if (a != null && b != null) return a.compareTo(b);
    if (a != null) return -1;
    if (b != null) return 1;
    return 0;
  }
}
