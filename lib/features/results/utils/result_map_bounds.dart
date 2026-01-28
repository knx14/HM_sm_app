import 'package:google_maps_flutter/google_maps_flutter.dart';

LatLngBounds boundsFromLatLngs(List<LatLng> points) {
  double? minLat, maxLat, minLng, maxLng;
  for (final p in points) {
    minLat = (minLat == null) ? p.latitude : (p.latitude < minLat ? p.latitude : minLat);
    maxLat = (maxLat == null) ? p.latitude : (p.latitude > maxLat ? p.latitude : maxLat);
    minLng = (minLng == null) ? p.longitude : (p.longitude < minLng ? p.longitude : minLng);
    maxLng = (maxLng == null) ? p.longitude : (p.longitude > maxLng ? p.longitude : maxLng);
  }
  return LatLngBounds(
    southwest: LatLng(minLat ?? 35.6812, minLng ?? 139.7671),
    northeast: LatLng(maxLat ?? 35.6812, maxLng ?? 139.7671),
  );
}

