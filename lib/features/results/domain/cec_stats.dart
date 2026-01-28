class CecStats {
  final double? avg;
  final double? min;
  final double? max;
  final int countPoints;

  const CecStats({
    required this.avg,
    required this.min,
    required this.max,
    required this.countPoints,
  });

  factory CecStats.fromJson(Map<String, dynamic> json) {
    return CecStats(
      avg: (json['avg'] as num?)?.toDouble(),
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
      countPoints: (json['count_points'] as num).toInt(),
    );
  }
}

