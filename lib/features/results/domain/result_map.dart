class FarmBoundaryPoint {
  final double lat;
  final double lng;

  const FarmBoundaryPoint({required this.lat, required this.lng});

  factory FarmBoundaryPoint.fromJson(Map<String, dynamic> json) {
    return FarmBoundaryPoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }
}

class ResultFarm {
  final int farmId;
  final String farmName;
  final List<FarmBoundaryPoint> boundaryPolygon;

  const ResultFarm({
    required this.farmId,
    required this.farmName,
    required this.boundaryPolygon,
  });

  factory ResultFarm.fromJson(Map<String, dynamic> json) {
    final poly = (json['boundary_polygon'] as List<dynamic>)
        .map((e) => FarmBoundaryPoint.fromJson(e as Map<String, dynamic>))
        .toList();
    return ResultFarm(
      farmId: (json['farm_id'] as num).toInt(),
      farmName: json['farm_name'] as String,
      boundaryPolygon: poly,
    );
  }
}

class ResultValue {
  final String parameter;
  final double? value;
  final String? unit;

  const ResultValue({
    required this.parameter,
    required this.value,
    required this.unit,
  });

  factory ResultValue.fromJson(Map<String, dynamic> json) {
    return ResultValue(
      parameter: json['parameter'] as String,
      value: (json['value'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
    );
  }
}

class ResultPoint {
  final int pointId;
  final double lat;
  final double lng;
  final List<ResultValue> values;

  const ResultPoint({
    required this.pointId,
    required this.lat,
    required this.lng,
    required this.values,
  });

  factory ResultPoint.fromJson(Map<String, dynamic> json) {
    final valuesJson = (json['values'] as List<dynamic>);
    return ResultPoint(
      pointId: (json['point_id'] as num).toInt(),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      values: valuesJson.map((e) => ResultValue.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class ResultMapResponse {
  final ResultFarm farm;
  final DateTime measurementDate;
  final List<ResultPoint> points;

  const ResultMapResponse({
    required this.farm,
    required this.measurementDate,
    required this.points,
  });

  factory ResultMapResponse.fromJson(Map<String, dynamic> json) {
    return ResultMapResponse(
      farm: ResultFarm.fromJson(json['farm'] as Map<String, dynamic>),
      measurementDate: DateTime.parse(json['measurement_date'] as String),
      points: (json['points'] as List<dynamic>)
          .map((e) => ResultPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

