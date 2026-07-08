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

  /// 境界未設定の仮登録圃場かどうか（サーバー側 isProvisional() と同じ判定）。
  bool get isProvisional => boundaryPolygon.isEmpty;

  factory Farm.fromJson(Map<String, dynamic> json) {
    // APIは境界未設定時に null ではなく空配列 [] を返す
    final boundaryRaw = json['boundary_polygon'];
    final boundaryPolygonList = boundaryRaw is List
        ? boundaryRaw.map((e) {
            final map = Map<String, dynamic>.from(e as Map);
            return {
              'lat': (map['lat'] as num).toDouble(),
              'lng': (map['lng'] as num).toDouble(),
            };
          }).toList()
        : <Map<String, double>>[];

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
