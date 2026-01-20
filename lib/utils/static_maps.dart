import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

/// Google Static Maps APIのURLを生成
/// 
/// 衛星/ハイブリッドの静止画に、赤いポリゴン（塗り+枠線）と赤いマーカーを表示
/// 
/// [boundaryPoints] 境界点のリスト（4〜8点、必須）
/// [apiKey] Google Maps APIキー（必須）
/// [width] 画像の幅（デフォルト: 280、表示サイズの2倍を推奨）
/// [height] 画像の高さ（デフォルト: 200、表示サイズの2倍を推奨）
/// [scale] スケール（デフォルト: 2、高解像度）
/// [cacheBuster] キャッシュバスティング用のパラメータ（オプション）
/// [maptype] 地図タイプ（デフォルト: hybrid、satelliteも可）
/// 
/// boundsからcenter/zoomを自前計算してURLを生成します。
String buildStaticMapUrl({
  required List<LatLng> boundaryPoints,
  required String apiKey,
  int width = 280,
  int height = 200,
  int scale = 2,
  String? cacheBuster,
  String maptype = 'hybrid', // hybrid または satellite
}) {
  // APIキーの検証（最重要）
  if (apiKey.isEmpty) {
    if (kDebugMode) {
      debugPrint('【エラー】APIキーが空です。Google Maps Static APIはkeyが必須です。');
    }
    throw ArgumentError('Google Maps API key is required');
  }

  // sizeをStatic API上限（640x640）以下にclamp
  // scale=2の場合、実サイズは2倍になるが、sizeパラメータ自体は640以下にする
  final clampedWidth = width.clamp(1, 640);
  final clampedHeight = height.clamp(1, 640);

  // bounds -> center/zoom を自前計算（visible依存をやめる）
  final bounds = boundsFromPoints(boundaryPoints);
  final mapCenter = centerOfBounds(bounds);

  // ★ scale分を加味してズーム計算（Static Mapsの実ピクセルに合わせる）
  final mapZoom = zoomForBounds(
    bounds: bounds,
    widthPx: clampedWidth * scale,
    heightPx: clampedHeight * scale,
    paddingPx: 28,
    minZoom: 3,
    maxZoom: 20,
  );

  // URLを手動で構築（二重エンコードを防ぐため、StringBufferで確実に）
  final buffer = StringBuffer();
  buffer.write('https://maps.googleapis.com/maps/api/staticmap?');
  
  // 基本パラメータ（エンコード不要）
  buffer.write('size=${clampedWidth}x${clampedHeight}');
  buffer.write('&scale=$scale');
  buffer.write('&maptype=$maptype'); // hybrid または satellite
  buffer.write('&language=ja');
  buffer.write('&center=${mapCenter.latitude},${mapCenter.longitude}');
  buffer.write('&zoom=$mapZoom');
  
  // ポリゴン（path）とマーカーを追加
  // ポリゴンのパスを生成（最後に先頭点を追加して閉じる）
  final pathPoints = List<LatLng>.from(boundaryPoints);
  if (pathPoints.first != pathPoints.last) {
    pathPoints.add(pathPoints.first);
  }
  
  // パス文字列を生成（座標のみ、エンコード前）
  final pathCoordinates = pathPoints
      .map((point) => '${point.latitude},${point.longitude}')
      .join('|');
  
  // ポリゴン（path）を追加
  // 形式: fillcolor:0x55FF0000|color:0xFF0000|weight:6|lat1,lng1|lat2,lng2|...
  final pathValue = 'fillcolor:0x55FF0000|color:0xFF0000|weight:6|$pathCoordinates';
  buffer.write('&path=${Uri.encodeQueryComponent(pathValue)}');
  
  // マーカー（各頂点に赤いピン）
  final markerCoordinates = boundaryPoints
      .map((point) => '${point.latitude},${point.longitude}')
      .join('|');
  final markerValue = 'size:mid|color:red|$markerCoordinates';
  buffer.write('&markers=${Uri.encodeQueryComponent(markerValue)}');
  
  // キャッシュバスティングパラメータを追加
  if (cacheBuster != null) {
    buffer.write('&v=${Uri.encodeQueryComponent(cacheBuster)}');
  }
  
  // APIキーを最後に追加（エンコード不要、最重要）
  buffer.write('&key=$apiKey');
  
  final url = buffer.toString();
  
  // デバッグ用: エラー検出時のみ詳細ログを出力
  if (kDebugMode) {
    if (!url.contains('&key=') && !url.contains('key=')) {
      debugPrint('【警告】Static Maps URLにkeyパラメータが含まれていません');
    }
  }
  
  return url;
}

/// points から bounds を作成
LatLngBounds boundsFromPoints(List<LatLng> points) {
  double minLat = points.first.latitude;
  double maxLat = points.first.latitude;
  double minLng = points.first.longitude;
  double maxLng = points.first.longitude;

  for (final p in points) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }

  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}

LatLng centerOfBounds(LatLngBounds b) {
  return LatLng(
    (b.southwest.latitude + b.northeast.latitude) / 2,
    (b.southwest.longitude + b.northeast.longitude) / 2,
  );
}

double _latRad(double lat) {
  final sinv = math.sin(lat * math.pi / 180);
  final radX2 = math.log((1 + sinv) / (1 - sinv)) / 2;
  // mercatorのクランプ
  return math.max(math.min(radX2, math.pi), -math.pi) / 2;
}

int zoomForBounds({
  required LatLngBounds bounds,
  required int widthPx,
  required int heightPx,
  int paddingPx = 24,
  int minZoom = 3,
  int maxZoom = 20,
}) {
  final ne = bounds.northeast;
  final sw = bounds.southwest;

  final latFraction = (_latRad(ne.latitude) - _latRad(sw.latitude)) / math.pi;

  var lngDiff = ne.longitude - sw.longitude;
  if (lngDiff < 0) lngDiff += 360; // 日付変更線対策（念のため）
  final lngFraction = lngDiff / 360;

  final usableW = math.max(1, widthPx - 2 * paddingPx);
  final usableH = math.max(1, heightPx - 2 * paddingPx);

  double zoomFromFraction(double fraction, int pixels) {
    if (fraction <= 0) return maxZoom.toDouble();
    // 256px * 2^zoom が世界幅。fractionは世界の何割か。
    return math.log(pixels / 256 / fraction) / math.ln2;
  }

  final latZoom = zoomFromFraction(latFraction, usableH);
  final lngZoom = zoomFromFraction(lngFraction, usableW);

  final zoom = math.min(latZoom, lngZoom).floor();
  return zoom.clamp(minZoom, maxZoom);
}

