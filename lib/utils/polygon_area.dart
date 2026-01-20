import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// ポリゴンの面積を計算（概算、平方メートル）
/// 球面三角法を使用した簡易計算
double calculatePolygonArea(List<LatLng> points) {
  if (points.length < 3) return 0.0;

  double area = 0.0;
  final int n = points.length;

  for (int i = 0; i < n; i++) {
    final LatLng p1 = points[i];
    final LatLng p2 = points[(i + 1) % n];

    area += (p1.longitude * p2.latitude - p2.longitude * p1.latitude);
  }

  // 地球の半径（メートル）
  const double earthRadius = 6371000.0;

  // 度をラジアンに変換
  final double latRad = points[0].latitude * (math.pi / 180.0);

  // 面積を計算（平方メートル）
  area = (area.abs() / 2.0) * (earthRadius * earthRadius) * 
         (math.cos(latRad) * math.cos(latRad));

  return area;
}

/// 面積を読みやすい形式で表示
String formatArea(double areaInSquareMeters) {
  if (areaInSquareMeters < 10000) {
    // 平方メートル
    return '${areaInSquareMeters.toStringAsFixed(1)} m²';
  } else {
    // ヘクタール
    final hectares = areaInSquareMeters / 10000;
    return '${hectares.toStringAsFixed(2)} ha';
  }
}

/// ポリゴンの中心座標を計算
LatLng calculatePolygonCenter(List<LatLng> points) {
  if (points.isEmpty) {
    return const LatLng(35.6812, 139.7671); // デフォルト（東京）
  }

  double sumLat = 0.0;
  double sumLng = 0.0;

  for (final point in points) {
    sumLat += point.latitude;
    sumLng += point.longitude;
  }

  return LatLng(
    sumLat / points.length,
    sumLng / points.length,
  );
}

