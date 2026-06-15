import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ResultMarkerIconFactory {
  static final Map<String, BitmapDescriptor> _cache = {};

  /// キャッシュをクリアする（色スケール変更時などに使用）
  static void clearCache() {
    _cache.clear();
  }

  static Future<BitmapDescriptor> circleLabel({
    required Color color,
    required String label,
  }) async {
    final key = '${color.toARGB32()}_$label';
    final cached = _cache[key];
    if (cached != null) return cached;

    const size = 40.0;
    const radius = 15.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);

    // 背景（円）
    final paint = Paint()..color = color;
    canvas.drawCircle(center, radius, paint);

    // 測定画面のピンと同じ大きさに揃える。
    final border = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, border);

    // テキスト
    final textStyle = TextStyle(
      color: _bestTextColor(color),
      fontSize: 11,
      fontWeight: FontWeight.w800,
    );
    final tp = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size - 10);
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final bd = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    _cache[key] = bd;
    return bd;
  }

  static Color _bestTextColor(Color bg) {
    final l = bg.computeLuminance();
    return l < 0.4 ? Colors.white : Colors.black;
  }
}
