import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../results/domain/result_parameter.dart';
import '../../../results/domain/timeseries_result.dart';
import '../../../results/presentation/providers/timeseries_notifier.dart';
import '../../../work_logs/presentation/work_log_edit_screen.dart';

class FarmTimeseriesTab extends StatelessWidget {
  const FarmTimeseriesTab({super.key, required this.farmId});

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
    final displayData = state.filteredData;

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              _ParameterSelector(
                selected: state.parameter,
                isLoading: state.isLoading,
                onChanged: context.read<TimeseriesNotifier>().setParameter,
              ),
              _RangeSelector(
                selected: state.selectedRange,
                onChanged: context.read<TimeseriesNotifier>().setRange,
              ),
              _PeriodSelector(
                selectedRange: state.selectedRange,
                selectedYear: state.selectedYear,
                selectedMonth: state.selectedMonth,
                availableYears: state.availableYears,
                availableMonths: state.availableMonths,
                onYearChanged: context
                    .read<TimeseriesNotifier>()
                    .setSelectedYear,
                onMonthChanged: context
                    .read<TimeseriesNotifier>()
                    .setSelectedMonth,
              ),
              if (state.isLoading && data == null)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.error != null && data == null)
                Expanded(
                  child: _ErrorState(
                    message: state.error!,
                    onRetry: state.reload,
                  ),
                )
              else if (data == null || data.points.isEmpty)
                const Expanded(child: Center(child: Text('測定データがありません')))
              else if (displayData == null || displayData.points.isEmpty)
                Expanded(
                  child: _RangeEmptyState(
                    periodLabel: state.selectedPeriodLabel,
                    onShowAll: () => state.setRange(TimeseriesRange.all),
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: state.reload,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        _LatestAverageCard(data: displayData),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 280,
                          child: _TimeseriesChart(data: displayData),
                        ),
                        const SizedBox(height: 12),
                        const _LegendRow(),
                        if (state.isLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'timeseries_work_log_fab_${state.farmId}',
            backgroundColor: const Color(0xFF2E5C39),
            foregroundColor: Colors.white,
            onPressed: () => _addWorkLog(context, state),
            icon: const Icon(Icons.add),
            label: const Text('作業記録'),
          ),
        ),
      ],
    );
  }

  Future<void> _addWorkLog(
    BuildContext context,
    TimeseriesNotifier state,
  ) async {
    final saved = await WorkLogEditScreen.show(context, farmId: state.farmId);
    if (!saved || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('作業記録を保存しました')));
    await state.reload();
  }
}

class _RangeEmptyState extends StatelessWidget {
  const _RangeEmptyState({required this.periodLabel, required this.onShowAll});

  final String periodLabel;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$periodLabelのデータがありません',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onShowAll, child: const Text('すべて表示に戻す')),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onChanged});

  final TimeseriesRange selected;
  final ValueChanged<TimeseriesRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<TimeseriesRange>(
            segments: TimeseriesRange.values
                .map(
                  (range) => ButtonSegment<TimeseriesRange>(
                    value: range,
                    label: Text(range.label),
                  ),
                )
                .toList(growable: false),
            selected: {selected},
            showSelectedIcon: false,
            style: ButtonStyle(
              textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
            ),
            onSelectionChanged: (values) => onChanged(values.first),
          ),
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selectedRange,
    required this.selectedYear,
    required this.selectedMonth,
    required this.availableYears,
    required this.availableMonths,
    required this.onYearChanged,
    required this.onMonthChanged,
  });

  final TimeseriesRange selectedRange;
  final int selectedYear;
  final DateTime selectedMonth;
  final List<int> availableYears;
  final List<DateTime> availableMonths;
  final ValueChanged<int> onYearChanged;
  final ValueChanged<DateTime> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    if (selectedRange == TimeseriesRange.all) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: selectedRange == TimeseriesRange.oneYear
            ? DropdownButtonFormField<int>(
                initialValue: selectedYear,
                decoration: const InputDecoration(
                  labelText: '表示する年',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: availableYears
                    .map(
                      (year) => DropdownMenuItem<int>(
                        value: year,
                        child: Text('$year年'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (year) {
                  if (year != null) onYearChanged(year);
                },
              )
            : DropdownButtonFormField<DateTime>(
                initialValue: selectedMonth,
                decoration: const InputDecoration(
                  labelText: '表示する年月',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: availableMonths
                    .map(
                      (month) => DropdownMenuItem<DateTime>(
                        value: month,
                        child: Text('${month.year}年${month.month}月'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (month) {
                  if (month != null) onMonthChanged(month);
                },
              ),
      ),
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
            onSelectionChanged: isLoading
                ? null
                : (values) => onChanged(values.first),
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
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    latest.date,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final index = _pointIndexAt(
                  details.localPosition,
                  constraints.biggest,
                  data,
                );
                if (index == null) return;
                _showMeasurementDetail(context, data, data.points[index]);
              },
              child: CustomPaint(
                painter: _TimeseriesChartPainter(
                  points: data.points,
                  workLogs: data.workLogs,
                  textColor: Theme.of(context).colorScheme.onSurface,
                  baseTextStyle: DefaultTextStyle.of(context).style,
                ),
                child: const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    );
  }

  int? _pointIndexAt(Offset tap, Size size, TimeseriesResult data) {
    final points = data.points;
    if (points.isEmpty) return null;
    final chart = _TimeseriesChartPainter.chartRectFor(size);
    if (!chart.inflate(16).contains(tap)) return null;

    final range = _TimeseriesChartPainter.dateRangeFor(points, data.workLogs);
    if (range == null) return points.length == 1 ? 0 : null;

    int? nearestIndex;
    var nearestDistance = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final x = _TimeseriesChartPainter.xForDateString(
        points[i].date,
        chart,
        range.$1,
        range.$2,
      );
      if (x == null) continue;
      final distance = (tap.dx - x).abs();
      if (distance <= 24 && distance < nearestDistance) {
        nearestIndex = i;
        nearestDistance = distance;
      }
    }
    return nearestIndex;
  }

  void _showMeasurementDetail(
    BuildContext context,
    TimeseriesResult data,
    TimeseriesPoint point,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _MeasurementDetailSheet(
        date: point.date,
        parameter: data.parameter,
        unit: data.unit,
        avg: point.avg,
        minVal: point.min,
        maxVal: point.max,
        count: point.count,
      ),
    );
  }
}

class _MeasurementDetailSheet extends StatelessWidget {
  const _MeasurementDetailSheet({
    required this.date,
    required this.parameter,
    required this.avg,
    required this.minVal,
    required this.maxVal,
    required this.count,
    this.unit,
  });

  final String date;
  final String parameter;
  final String? unit;
  final double avg;
  final double minVal;
  final double maxVal;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              date,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.62),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$parameter 測定値',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _StatBox(label: '圃場平均', value: avg, unit: unit),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(label: '最小', value: minVal, unit: unit),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(label: '最大', value: maxVal, unit: unit),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '$count 測定点の集計値',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.62),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value, this.unit});

  final String label;
  final double value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.62),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          if (unit != null)
            Text(
              unit!,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeseriesChartPainter extends CustomPainter {
  _TimeseriesChartPainter({
    required this.points,
    required this.workLogs,
    required this.textColor,
    required this.baseTextStyle,
  });

  final List<TimeseriesPoint> points;
  final List<WorkLogMark> workLogs;
  final Color textColor;
  final TextStyle baseTextStyle;

  static const left = 44.0;
  static const right = 10.0;
  static const top = 12.0;
  static const bottom = 38.0;

  static Rect chartRectFor(Size size) {
    return Rect.fromLTWH(
      left,
      top,
      size.width - left - right,
      size.height - top - bottom,
    );
  }

  static String _dateKeyStatic(String date) =>
      date.length >= 10 ? date.substring(0, 10) : date;

  static (DateTime, DateTime)? dateRangeFor(
    List<TimeseriesPoint> points,
    List<WorkLogMark> workLogs,
  ) {
    DateTime? minDate;
    DateTime? maxDate;

    void consider(String date) {
      final parsed = DateTime.tryParse(_dateKeyStatic(date));
      if (parsed == null) return;
      minDate = minDate == null || parsed.isBefore(minDate!) ? parsed : minDate;
      maxDate = maxDate == null || parsed.isAfter(maxDate!) ? parsed : maxDate;
    }

    for (final point in points) {
      consider(point.date);
    }
    for (final mark in workLogs) {
      consider(mark.date);
    }

    if (minDate == null || maxDate == null) return null;
    return (minDate!, maxDate!);
  }

  static double? xForDateString(
    String date,
    Rect chart,
    DateTime minDate,
    DateTime maxDate,
  ) {
    final parsed = DateTime.tryParse(_dateKeyStatic(date));
    if (parsed == null) return null;
    if (maxDate.isAtSameMomentAs(minDate)) {
      return parsed.isAtSameMomentAs(minDate) ? chart.center.dx : null;
    }
    final totalDays = maxDate.difference(minDate).inDays;
    if (totalDays <= 0) {
      return parsed.isAtSameMomentAs(minDate) ? chart.center.dx : null;
    }
    final offsetDays = parsed.difference(minDate).inDays;
    return chart.left + chart.width * (offsetDays / totalDays);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final chart = chartRectFor(size);
    if (chart.width <= 0 || chart.height <= 0) return;

    final dateRange = dateRangeFor(points, workLogs);
    if (dateRange == null) return;
    final (minDate, maxDate) = dateRange;

    final minY = points.map((p) => p.min).reduce(math.min);
    final maxY = points.map((p) => p.max).reduce(math.max);
    final yPadding = (maxY - minY).abs() < 0.001 ? 1.0 : (maxY - minY) * 0.12;
    final y0 = minY - yPadding;
    final y1 = maxY + yPadding;

    double? xForDate(String date) =>
        xForDateString(date, chart, minDate, maxDate);

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

    final workPaint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.75)
      ..strokeWidth = 1.4;
    for (final mark in workLogs) {
      final x = xForDate(mark.date);
      if (x == null) continue;
      _drawDashedLine(
        canvas,
        Offset(x, chart.top),
        Offset(x, chart.bottom),
        workPaint,
      );
      _drawText(
        canvas,
        mark.title?.isNotEmpty == true
            ? mark.title!
            : _workTypeLabel(mark.workType),
        Offset(x + 3, chart.top + 2),
        fontSize: 9,
        color: Colors.orange.shade800,
      );
    }

    final bandPath = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = xForDate(p.date);
      if (x == null) continue;
      final point = Offset(x, yFor(p.max));
      if (i == 0) {
        bandPath.moveTo(point.dx, point.dy);
      } else {
        bandPath.lineTo(point.dx, point.dy);
      }
    }
    for (var i = points.length - 1; i >= 0; i--) {
      final p = points[i];
      final x = xForDate(p.date);
      if (x == null) continue;
      bandPath.lineTo(x, yFor(p.min));
    }
    bandPath.close();
    canvas.drawPath(
      bandPath,
      Paint()..color = const Color(0xFF4A8459).withValues(alpha: 0.16),
    );

    final linePath = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = xForDate(p.date);
      if (x == null) continue;
      final point = Offset(x, yFor(p.avg));
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
      final x = xForDate(points[i].date);
      if (x == null) continue;
      canvas.drawCircle(Offset(x, yFor(points[i].avg)), 4, dotPaint);
    }

    final labelStep = math.max(1, (points.length / 4).ceil());
    for (var i = 0; i < points.length; i += labelStep) {
      final x = xForDate(points[i].date);
      if (x == null) continue;
      _drawText(
        canvas,
        _shortDate(points[i].date),
        Offset(x - 16, chart.bottom + 8),
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
      text: TextSpan(
        style: baseTextStyle.copyWith(fontSize: fontSize, color: color),
        text: text,
      ),
      textDirection: TextDirection.ltr,
      locale: const Locale('ja', 'JP'),
    )..layout();
    painter.paint(canvas, offset);
  }

  String _shortDate(String date) {
    if (date.length >= 10) {
      return '${date.substring(5, 7)}/${date.substring(8, 10)}';
    }
    return date;
  }

  @override
  bool shouldRepaint(covariant _TimeseriesChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.workLogs != workLogs ||
        oldDelegate.textColor != textColor ||
        oldDelegate.baseTextStyle != baseTextStyle;
  }
}

String _workTypeLabel(String workType) {
  return switch (workType) {
    'fertilization' => '施肥',
    'tillage' => '耕うん',
    'pesticide' => '農薬',
    'harvest' => '収穫',
    _ => '作業',
  };
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
  const _LegendItem({required this.color, required this.label});

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
  const _ErrorState({required this.message, required this.onRetry});

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
