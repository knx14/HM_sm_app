class Farm {
  final int id;
  final String farmName;
  final String? cultivationMethod;
  final String? cropType;
  final List<Map<String, double>> boundaryPolygon;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Farm({
    required this.id,
    required this.farmName,
    this.cultivationMethod,
    this.cropType,
    required this.boundaryPolygon,
    this.createdAt,
    this.updatedAt,
  });

  factory Farm.fromJson(Map<String, dynamic> json) {
    // boundary_polygonの値をdoubleに変換
    final boundaryPolygonList = (json['boundary_polygon'] as List).map((e) {
      final map = Map<String, dynamic>.from(e);
      return {
        'lat': (map['lat'] as num).toDouble(),
        'lng': (map['lng'] as num).toDouble(),
      };
    }).toList();
    
    return Farm(
      id: json['id'] as int,
      farmName: json['farm_name'] as String,
      cultivationMethod: json['cultivation_method'] as String?,
      cropType: json['crop_type'] as String?,
      boundaryPolygon: boundaryPolygonList,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'farm_name': farmName,
      'cultivation_method': cultivationMethod,
      'crop_type': cropType,
      'boundary_polygon': boundaryPolygon,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

