import 'cec_stats.dart';

class FarmResultDateItem {
  final DateTime measurementDate;
  final CecStats cecStats;
  final String summaryText;

  const FarmResultDateItem({
    required this.measurementDate,
    required this.cecStats,
    required this.summaryText,
  });

  factory FarmResultDateItem.fromJson(Map<String, dynamic> json) {
    return FarmResultDateItem(
      measurementDate: DateTime.parse(json['measurement_date'] as String),
      cecStats: CecStats.fromJson(json['cec_stats'] as Map<String, dynamic>),
      summaryText: json['summary_text'] as String,
    );
  }
}

