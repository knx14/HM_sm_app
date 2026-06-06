class TimeseriesResult {
  final String parameter;
  final String? unit;
  final List<TimeseriesPoint> points;
  final List<WorkLogMark> workLogs;

  const TimeseriesResult({
    required this.parameter,
    required this.unit,
    required this.points,
    required this.workLogs,
  });

  TimeseriesResult copyWith({
    List<TimeseriesPoint>? points,
    List<WorkLogMark>? workLogs,
  }) {
    return TimeseriesResult(
      parameter: parameter,
      unit: unit,
      points: points ?? this.points,
      workLogs: workLogs ?? this.workLogs,
    );
  }

  factory TimeseriesResult.fromJson(Map<String, dynamic> json) {
    final pointsRaw = (json['points'] as List<dynamic>?) ?? const [];
    final workLogsRaw = (json['work_logs'] as List<dynamic>?) ?? const [];

    return TimeseriesResult(
      parameter: (json['parameter'] as String?) ?? 'CEC',
      unit: json['unit'] as String?,
      points: pointsRaw
          .map((e) => TimeseriesPoint.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      workLogs: workLogsRaw
          .map((e) => WorkLogMark.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class TimeseriesPoint {
  final String date;
  final double avg;
  final double min;
  final double max;
  final int count;

  const TimeseriesPoint({
    required this.date,
    required this.avg,
    required this.min,
    required this.max,
    required this.count,
  });

  factory TimeseriesPoint.fromJson(Map<String, dynamic> json) {
    final avg = (json['avg'] as num?)?.toDouble() ?? 0;
    return TimeseriesPoint(
      date: json['date'] as String,
      avg: avg,
      min: (json['min'] as num?)?.toDouble() ?? avg,
      max: (json['max'] as num?)?.toDouble() ?? avg,
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class WorkLogMark {
  final String date;
  final String workType;
  final String? title;
  final String? detail;
  final double? amountValue;
  final String? amountUnit;

  const WorkLogMark({
    required this.date,
    required this.workType,
    this.title,
    this.detail,
    this.amountValue,
    this.amountUnit,
  });

  factory WorkLogMark.fromJson(Map<String, dynamic> json) {
    return WorkLogMark(
      date: json['date'] as String,
      workType: (json['work_type'] as String?) ?? 'other',
      title: json['title'] as String?,
      detail: json['detail'] as String?,
      amountValue: (json['amount_value'] as num?)?.toDouble(),
      amountUnit: json['amount_unit'] as String?,
    );
  }
}
