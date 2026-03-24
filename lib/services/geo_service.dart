import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:maps_toolkit/maps_toolkit.dart' as mt;

enum GeoFenceStatus {
  inside,
  edge,
  outside,
}

class GeoService {
  static const double toleranceMeters = 10;
  static const bool defaultGeodesic = false;

  static GeoFenceStatus classifyLocation({
    required gmaps.LatLng point,
    required List<gmaps.LatLng> polygon,
    bool geodesic = defaultGeodesic,
  }) {
    if (polygon.length < 3) return GeoFenceStatus.outside;

    final p = mt.LatLng(point.latitude, point.longitude);
    final poly = polygon.map((v) => mt.LatLng(v.latitude, v.longitude)).toList();

    // 1. まずポリゴン内外を判定（最優先）
    final isInside = mt.PolygonUtil.containsLocation(p, poly, geodesic);
    if (!isInside) return GeoFenceStatus.outside;

    // 2. 内側にいる場合のみ、辺の近傍かどうかを判定
    final isEdge = mt.PolygonUtil.isLocationOnEdge(
      p,
      poly,
      geodesic,
      tolerance: toleranceMeters,
    );
    return isEdge ? GeoFenceStatus.edge : GeoFenceStatus.inside;
  }
}

