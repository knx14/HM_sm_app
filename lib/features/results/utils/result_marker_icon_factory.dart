import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ResultMarkerIconFactory {
  static final Map<String, BitmapDescriptor> _cache = {};

  static Future<BitmapDescriptor> circleLabel({
    required Color color,
    required String label,
  }) async {
    final key = '${color.toARGB32()}_$label';
    final cached = _cache[key];
    if (cached != null) return cached;

    const size = 64.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 背景（円）
    final paint = Paint()..color = color;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2, paint);

    // 枠線（薄く）
    final border = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 1, border);

    // テキスト
    final textStyle = TextStyle(
      color: _bestTextColor(color),
      fontSize: 15,
      fontWeight: FontWeight.w700,
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

