import 'result_map.dart';

class ResultDiffValue {
  final String parameter;
  final double? diffValue;
  final String? unit;

  const ResultDiffValue({
    required this.parameter,
    required this.diffValue,
    required this.unit,
  });

  factory ResultDiffValue.fromJson(Map<String, dynamic> json) {
    return ResultDiffValue(
      parameter: json['parameter'] as String,
      diffValue: (json['diff_value'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
    );
  }
}

class ResultDiffPoint {
  final int pointId;
  final double lat;
  final double lng;
  final List<ResultValue> currentValues;
  final List<ResultValue>? previousValues;
  final List<ResultDiffValue> diffValues;

  const ResultDiffPoint({
    required this.pointId,
    required this.lat,
    required this.lng,
    required this.currentValues,
    required this.previousValues,
    required this.diffValues,
  });

  factory ResultDiffPoint.fromJson(Map<String, dynamic> json) {
    final current = (json['current_values'] as List<dynamic>)
        .map((e) => ResultValue.fromJson(e as Map<String, dynamic>))
        .toList();
    final previousRaw = json['previous_values'];
    final previous = previousRaw == null
        ? null
        : (previousRaw as List<dynamic>)
            .map((e) => ResultValue.fromJson(e as Map<String, dynamic>))
            .toList();
    final diffs = (json['diff_values'] as List<dynamic>)
        .map((e) => ResultDiffValue.fromJson(e as Map<String, dynamic>))
        .toList();
    return ResultDiffPoint(
      pointId: (json['point_id'] as num).toInt(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      currentValues: current,
      previousValues: previous,
      diffValues: diffs,
    );
  }
}

class ResultMapDiffResponse {
  final ResultFarm farm;
  final DateTime measurementDate;
  final DateTime previousMeasurementDate;
  final List<ResultDiffPoint> points;

  const ResultMapDiffResponse({
    required this.farm,
    required this.measurementDate,
    required this.previousMeasurementDate,
    required this.points,
  });

  factory ResultMapDiffResponse.fromJson(Map<String, dynamic> json) {
    return ResultMapDiffResponse(
      farm: ResultFarm.fromJson(json['farm'] as Map<String, dynamic>),
      measurementDate: DateTime.parse(json['measurement_date'] as String),
      previousMeasurementDate: DateTime.parse(json['previous_measurement_date'] as String),
      points: (json['points'] as List<dynamic>)
          .map((e) => ResultDiffPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

