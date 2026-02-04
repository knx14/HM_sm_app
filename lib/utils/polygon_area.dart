import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 2D座標点（内部用）
class _Point2D {
  final double x; // East (メートル)
  final double y; // North (メートル)
  
  _Point2D(this.x, this.y);
}

/// ポリゴンの面積を計算（平方メートル）
/// 局所平面近似（ENU座標系 + Shoelace formula）を使用
/// 圃場のような小領域には最適で、誤差は数cm〜数十cm²レベル
double calculatePolygonArea(List<LatLng> points) {
  if (points.length < 3) return 0.0;

  final int n = points.length;
  
  // ポリゴンの中心点を計算（投影の基準点）
  final LatLng center = calculatePolygonCenter(points);
  final double centerLatRad = center.latitude * (math.pi / 180.0);
  
  // 地球の半径（メートル）
  const double earthRadius = 6371000.0;
  
  // 各点をENU座標（East-North-Up、メートル単位）に変換
  final List<_Point2D> enuPoints = points.map((point) {
    final double latRad = point.latitude * (math.pi / 180.0);
    final double lonRad = point.longitude * (math.pi / 180.0);
    final double centerLonRad = center.longitude * (math.pi / 180.0);
    
    // 緯度方向の差（北方向、メートル）
    final double dLat = latRad - centerLatRad;
    final double north = dLat * earthRadius;
    
    // 経度方向の差（東方向、メートル）
    // 緯度による補正を適用
    final double dLon = lonRad - centerLonRad;
    final double east = dLon * earthRadius * math.cos(centerLatRad);
    
    return _Point2D(east, north);
  }).toList();
  
  // Shoelace formula（靴紐公式）で2Dポリゴン面積を計算
  double area = 0.0;
  for (int i = 0; i < n; i++) {
    final int j = (i + 1) % n;
    area += enuPoints[i].x * enuPoints[j].y;
    area -= enuPoints[j].x * enuPoints[i].y;
  }
  
  // 絶対値と1/2を適用
  return (area.abs() / 2.0);
}

/// 面積を読みやすい形式で表示
String formatArea(double areaInSquareMeters) {
  if (areaInSquareMeters < 1) {
    return '${areaInSquareMeters.toStringAsFixed(2)} m²';
  } else if (areaInSquareMeters < 10000) {
    return '${areaInSquareMeters.toStringAsFixed(1)} m²';
  } else {
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

