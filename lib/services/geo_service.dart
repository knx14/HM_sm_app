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

    final isEdge = mt.PolygonUtil.isLocationOnEdge(
      p,
      poly,
      geodesic,
      tolerance: toleranceMeters,
    );
    if (isEdge) return GeoFenceStatus.edge;

    final isInside = mt.PolygonUtil.containsLocation(p, poly, geodesic);
    return isInside ? GeoFenceStatus.inside : GeoFenceStatus.outside;
  }
}

