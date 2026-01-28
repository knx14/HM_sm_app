import 'cec_stats.dart';

class LatestResultFeedItem {
  final int farmId;
  final String farmName;
  final DateTime latestMeasurementDate;
  final CecStats cecStats;
  final String summaryText;

  const LatestResultFeedItem({
    required this.farmId,
    required this.farmName,
    required this.latestMeasurementDate,
    required this.cecStats,
    required this.summaryText,
  });

  factory LatestResultFeedItem.fromJson(Map<String, dynamic> json) {
    return LatestResultFeedItem(
      farmId: (json['farm_id'] as num).toInt(),
      farmName: json['farm_name'] as String,
      latestMeasurementDate: DateTime.parse(json['latest_measurement_date'] as String),
      cecStats: CecStats.fromJson(json['cec_stats'] as Map<String, dynamic>),
      summaryText: json['summary_text'] as String,
    );
  }
}

class FarmLatestResultSummary {
  final DateTime latestMeasurementDate;
  final CecStats cecStats;
  final String summaryText;

  const FarmLatestResultSummary({
    required this.latestMeasurementDate,
    required this.cecStats,
    required this.summaryText,
  });

  factory FarmLatestResultSummary.fromJson(Map<String, dynamic> json) {
    return FarmLatestResultSummary(
      latestMeasurementDate: DateTime.parse(json['latest_measurement_date'] as String),
      cecStats: CecStats.fromJson(json['cec_stats'] as Map<String, dynamic>),
      summaryText: json['summary_text'] as String,
    );
  }
}

class FarmWithLatestResult {
  final int farmId;
  final String farmName;
  final FarmLatestResultSummary? latestResult;

  const FarmWithLatestResult({
    required this.farmId,
    required this.farmName,
    required this.latestResult,
  });

  factory FarmWithLatestResult.fromJson(Map<String, dynamic> json) {
    final latest = json['latest_result'];
    return FarmWithLatestResult(
      farmId: (json['farm_id'] as num).toInt(),
      farmName: json['farm_name'] as String,
      latestResult: latest == null ? null : FarmLatestResultSummary.fromJson(latest as Map<String, dynamic>),
    );
  }
}

