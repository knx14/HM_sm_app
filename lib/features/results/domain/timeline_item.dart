sealed class TimelineItem {
  final String date;
  final String type;

  const TimelineItem({
    required this.date,
    required this.type,
  });

  factory TimelineItem.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'measurement' => MeasurementTimelineItem.fromJson(json),
      'work_log' => WorkLogTimelineItem.fromJson(json),
      _ => UnknownTimelineItem.fromJson(json),
    };
  }
}

final class MeasurementTimelineItem extends TimelineItem {
  final int countPoints;
  final Map<String, ParameterStat> values;
  final double? deltaCec;

  const MeasurementTimelineItem({
    required super.date,
    required this.countPoints,
    required this.values,
    this.deltaCec,
  }) : super(type: 'measurement');

  factory MeasurementTimelineItem.fromJson(Map<String, dynamic> json) {
    final valuesRaw = (json['values'] as Map?) ?? const {};
    final deltaRaw = (json['delta'] as Map?) ?? const {};
    return MeasurementTimelineItem(
      date: json['date'] as String,
      countPoints: (json['count_points'] as num?)?.toInt() ?? 0,
      values: valuesRaw.map(
        (key, value) => MapEntry(
          key.toString(),
          ParameterStat.fromJson(Map<String, dynamic>.from(value as Map)),
        ),
      ),
      deltaCec: (deltaRaw['CEC'] as num?)?.toDouble(),
    );
  }
}

class ParameterStat {
  final double? avg;
  final double? min;
  final double? max;
  final String? unit;

  const ParameterStat({
    required this.avg,
    required this.min,
    required this.max,
    this.unit,
  });

  factory ParameterStat.fromJson(Map<String, dynamic> json) {
    return ParameterStat(
      avg: (json['avg'] as num?)?.toDouble(),
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
    );
  }
}

final class WorkLogTimelineItem extends TimelineItem {
  final String workType;
  final String? title;
  final String? detail;
  final double? amountValue;
  final String? amountUnit;

  const WorkLogTimelineItem({
    required super.date,
    required this.workType,
    this.title,
    this.detail,
    this.amountValue,
    this.amountUnit,
  }) : super(type: 'work_log');

  factory WorkLogTimelineItem.fromJson(Map<String, dynamic> json) {
    return WorkLogTimelineItem(
      date: json['date'] as String,
      workType: (json['work_type'] as String?) ?? 'other',
      title: json['title'] as String?,
      detail: json['detail'] as String?,
      amountValue: (json['amount_value'] as num?)?.toDouble(),
      amountUnit: json['amount_unit'] as String?,
    );
  }
}

final class UnknownTimelineItem extends TimelineItem {
  const UnknownTimelineItem({
    required super.date,
    required super.type,
  });

  factory UnknownTimelineItem.fromJson(Map<String, dynamic> json) {
    return UnknownTimelineItem(
      date: (json['date'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'unknown',
    );
  }
}
