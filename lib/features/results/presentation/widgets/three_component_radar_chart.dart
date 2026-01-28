import 'dart:math' as math;

import 'package:flutter/material.dart';

class ThreeComponentRadarChart extends StatelessWidget {
  final double k2o; // 0-100
  final double cao; // 0-100
  final double mgo; // 0-100

  const ThreeComponentRadarChart({
    super.key,
    required this.k2o,
    required this.cao,
    required this.mgo,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _RadarPainter(
          k2o: k2o.clamp(0.0, 100.0),
          cao: cao.clamp(0.0, 100.0),
          mgo: mgo.clamp(0.0, 100.0),
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double k2o;
  final double cao;
  final double mgo;
  final Color color;

  _RadarPainter({
    required this.k2o,
    required this.cao,
    required this.mgo,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.38;

    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 5段グリッド
    for (int i = 1; i <= 5; i++) {
      final r = radius * (i / 5);
      final path = Path()
        ..moveTo(center.dx, center.dy - r)
        ..lineTo(center.dx + r * math.cos(math.pi / 6), center.dy + r * math.sin(math.pi / 6))
        ..lineTo(center.dx - r * math.cos(math.pi / 6), center.dy + r * math.sin(math.pi / 6))
        ..close();
      canvas.drawPath(path, gridPaint);
    }

    // 軸
    final axisPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    canvas.drawLine(center, center + Offset(0, -radius), axisPaint); // K2O (上)
    canvas.drawLine(
      center,
      center + Offset(radius * math.cos(math.pi / 6), radius * math.sin(math.pi / 6)),
      axisPaint,
    ); // CaO (右下)
    canvas.drawLine(
      center,
      center + Offset(-radius * math.cos(math.pi / 6), radius * math.sin(math.pi / 6)),
      axisPaint,
    ); // MgO (左下)

    // データポリゴン
    final pK = center + Offset(0, -radius * (k2o / 100));
    final pC = center + Offset(radius * math.cos(math.pi / 6) * (cao / 100), radius * math.sin(math.pi / 6) * (cao / 100));
    final pM = center + Offset(-radius * math.cos(math.pi / 6) * (mgo / 100), radius * math.sin(math.pi / 6) * (mgo / 100));

    final fill = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()..moveTo(pK.dx, pK.dy)..lineTo(pC.dx, pC.dy)..lineTo(pM.dx, pM.dy)..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.k2o != k2o || oldDelegate.cao != cao || oldDelegate.mgo != mgo || oldDelegate.color != color;
  }
}

