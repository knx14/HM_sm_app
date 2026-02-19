String formatYyyyMmDdSlash(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y/$m/$d';
}

String format1OrDash(double? v) {
  if (v == null) return '--';
  return v.toStringAsFixed(1);
}

String format1OrZero(double v) => v.toStringAsFixed(1);

String formatDiff1OrDash(double? v) {
  if (v == null) return '--';
  final fixed = v.toStringAsFixed(1);
  return v > 0 ? '+$fixed' : fixed;
}

