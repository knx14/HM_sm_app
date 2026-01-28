class NumericStats {
  final double? avg;
  final double? min;
  final double? max;

  const NumericStats({
    required this.avg,
    required this.min,
    required this.max,
  });
}

NumericStats computeStats(Iterable<double?> values) {
  double sum = 0;
  int n = 0;
  double? min;
  double? max;
  for (final v in values) {
    if (v == null) continue;
    n += 1;
    sum += v;
    min = (min == null) ? v : (v < min ? v : min);
    max = (max == null) ? v : (v > max ? v : max);
  }
  if (n == 0) {
    return const NumericStats(avg: null, min: null, max: null);
  }
  return NumericStats(avg: sum / n, min: min, max: max);
}

double computeDeltaMax(Iterable<double?> diffs) {
  double delta = 0.0;
  for (final v in diffs) {
    if (v == null) continue;
    final a = v.abs();
    if (a > delta) delta = a;
  }
  return delta;
}

