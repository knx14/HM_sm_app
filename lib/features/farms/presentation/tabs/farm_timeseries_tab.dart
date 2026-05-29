import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../results/domain/result_parameter.dart';
import '../../../results/domain/timeseries_result.dart';
import '../../../results/presentation/providers/timeseries_notifier.dart';

class FarmTimeseriesTab extends StatelessWidget {
  const FarmTimeseriesTab({
    super.key,
    required this.farmId,
  });

  final int farmId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TimeseriesNotifier(farmId: farmId)..loadInitial(),
      child: const _TimeseriesView(),
    );
  }
}

class _TimeseriesView extends StatelessWidget {
  const _TimeseriesView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TimeseriesNotifier>();
    final data = state.data;

    return Column(
      children: [
        _ParameterSelector(
          selected: state.parameter,
          isLoading: state.isLoading,
          onChanged: context.read<TimeseriesNotifier>().setParameter,
        ),
        if (state.isLoading && data == null)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (state.error != null && data == null)
          Expanded(child: _ErrorState(message: state.error!, onRetry: state.reload))
        else if (data == null || data.points.isEmpty)
          const Expanded(child: Center(child: Text('測定データがありません')))
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: state.reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _LatestAverageCard(data: data),
                  const SizedBox(height: 12),
                  SizedBox(height: 280, child: _TimeseriesChart(data: data)),
                  const SizedBox(height: 12),
                  const _LegendRow(),
                  if (state.isLoading) const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ParameterSelector extends StatelessWidget {
  const _ParameterSelector({
    required this.selected,
    required this.isLoading,
    required this.onChanged,
  });

  final ResultParameter selected;
  final bool isLoading;
  final ValueChanged<ResultParameter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<ResultParameter>(
            segments: const [
              ButtonSegment(value: ResultParameter.cec, label: Text('CEC')),
              ButtonSegment(value: ResultParameter.cao, label: Text('CaO')),
              ButtonSegment(value: ResultParameter.k2o, label: Text('K2O')),
              ButtonSegment(value: ResultParameter.mgo, label: Text('MgO')),
            ],
            selected: {selected},
            showSelectedIcon: false,
            onSelectionChanged: isLoading ? null : (values) => onChanged(values.first),
          ),
        ),
      ),
    );
  }
}

class _LatestAverageCard extends StatelessWidget {
  const _LatestAverageCard({required this.data});

  final TimeseriesResult data;

  @override
  Widget build(BuildContext context) {
    final latest = data.points.last;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '圃場平均（${data.parameter}）',
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.62)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    latest.date,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.62)),
                  ),
                ],
              ),
            ),
            Text(
              latest.avg.toStringAsFixed(1),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
            ),
            if (data.unit != null) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(data.unit!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TimeseriesChart extends StatelessWidget {
  const _TimeseriesChart({required this.data});

  final TimeseriesResult data;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 12, 8),
        child: CustomPaint(
          painter: _TimeseriesChartPainter(
            points: data.points,
            workLogs: data.workLogs,
            textColor: Theme.of(context).colorScheme.onSurface,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _TimeseriesChartPainter extends CustomPainter {
  _TimeseriesChartPainter({
    required this.points,
    required this.workLogs,
    required this.textColor,
  });

  final List<TimeseriesPoint> points;
  final List<WorkLogMark> workLogs;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const left = 44.0;
    const right = 10.0;
    const top = 12.0;
    const bottom = 38.0;
    final chart = Rect.fromLTWH(left, top, size.width - left - right, size.height - top - bottom);
    if (chart.width <= 0 || chart.height <= 0) return;

    final minY = points.map((p) => p.min).reduce(math.min);
    final maxY = points.map((p) => p.max).reduce(math.max);
    final yPadding = (maxY - minY).abs() < 0.001 ? 1.0 : (maxY - minY) * 0.12;
    final y0 = minY - yPadding;
    final y1 = maxY + yPadding;

    double xFor(int index) {
      if (points.length == 1) return chart.center.dx;
      return chart.left + chart.width * index / (points.length - 1);
    }

    double yFor(double value) {
      if ((y1 - y0).abs() < 0.001) return chart.center.dy;
      return chart.bottom - chart.height * ((value - y0) / (y1 - y0));
    }

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
      _drawText(
        canvas,
        (y1 - ((y1 - y0) * i / 4)).toStringAsFixed(1),
        Offset(0, y - 7),
        fontSize: 10,
        color: textColor.withValues(alpha: 0.62),
      );
    }

    final workDates = {for (var i = 0; i < points.length; i++) points[i].date: i};
    final workPaint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.75)
      ..strokeWidth = 1.4;
    for (final mark in workLogs) {
      final index = workDates[mark.date];
      if (index == null) continue;
      final x = xFor(index);
      _drawDashedLine(canvas, Offset(x, chart.top), Offset(x, chart.bottom), workPaint);
    }

    final bandPath = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final point = Offset(xFor(i), yFor(p.max));
      if (i == 0) {
        bandPath.moveTo(point.dx, point.dy);
      } else {
        bandPath.lineTo(point.dx, point.dy);
      }
    }
    for (var i = points.length - 1; i >= 0; i--) {
      final p = points[i];
      bandPath.lineTo(xFor(i), yFor(p.min));
    }
    bandPath.close();
    canvas.drawPath(
      bandPath,
      Paint()..color = const Color(0xFF4A8459).withValues(alpha: 0.16),
    );

    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final point = Offset(xFor(i), yFor(p.avg));
      if (i == 0) {
        linePath.moveTo(point.dx, point.dy);
      } else {
        linePath.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = const Color(0xFF2E5C39)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );

    final dotPaint = Paint()..color = const Color(0xFF2E5C39);
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(xFor(i), yFor(points[i].avg)), 4, dotPaint);
    }

    final labelStep = math.max(1, (points.length / 4).ceil());
    for (var i = 0; i < points.length; i += labelStep) {
      _drawText(
        canvas,
        _shortDate(points[i].date),
        Offset(xFor(i) - 16, chart.bottom + 8),
        fontSize: 10,
        color: textColor.withValues(alpha: 0.68),
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashHeight = 6.0;
    const dashSpace = 4.0;
    var currentY = start.dy;
    while (currentY < end.dy) {
      canvas.drawLine(
        Offset(start.dx, currentY),
        Offset(start.dx, math.min(currentY + dashHeight, end.dy)),
        paint,
      );
      currentY += dashHeight + dashSpace;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double fontSize,
    required Color color,
  }) {
    final painter = TextPainter(
      text: TextSpan(style: TextStyle(fontSize: fontSize, color: color), text: text),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  String _shortDate(String date) {
    if (date.length >= 10) return '${date.substring(5, 7)}/${date.substring(8, 10)}';
    return date;
  }

  @override
  bool shouldRepaint(covariant _TimeseriesChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.workLogs != workLogs ||
        oldDelegate.textColor != textColor;
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        _LegendItem(color: Color(0xFF2E5C39), label: '平均'),
        SizedBox(width: 16),
        _LegendItem(color: Color(0x554A8459), label: 'min/max'),
        SizedBox(width: 16),
        _LegendItem(color: Colors.orange, label: '作業'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 18, height: 4, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('再読み込み')),
        ],
      ),
    );
  }
}
