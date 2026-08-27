import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../results/domain/result_parameter.dart';
import '../../../results/domain/timeseries_result.dart';
import '../../../results/presentation/providers/timeseries_notifier.dart';
import '../../../results/presentation/widgets/farm_record_add_sheet.dart';

class FarmTimeseriesTab extends StatelessWidget {
  const FarmTimeseriesTab({
    super.key,
    required this.farmId,
    required this.isProvisional,
  });

  final int farmId;
  final bool isProvisional;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TimeseriesNotifier(farmId: farmId)..loadInitial(),
      child: _TimeseriesView(isProvisional: isProvisional),
    );
  }
}

class _TimeseriesView extends StatelessWidget {
  const _TimeseriesView({required this.isProvisional});

  final bool isProvisional;

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
                        _LatestAverageCard(
                          parameter: displayData.parameter,
                          unit: displayData.unit,
                          farmAverage: data.farmAverage,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 280,
                          child: _TimeseriesChart(
                            data: displayData,
                            farmAverage: data.farmAverage,
                          ),
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
          child: FloatingActionButton(
            heroTag: 'timeseries_add_fab_${state.farmId}',
            backgroundColor: const Color(0xFF2E5C39),
            foregroundColor: Colors.white,
            onPressed: () => FarmRecordAddActions.handleFabPressed(
              context: context,
              farmId: state.farmId,
              isProvisional: isProvisional,
              onReload: state.reload,
            ),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
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

class _LatestAverageCard extends StatelessWidget {
  const _LatestAverageCard({
    required this.parameter,
    required this.unit,
    required this.farmAverage,
  });

  final String parameter;
  final String? unit;
  final double? farmAverage;

  @override
  Widget build(BuildContext context) {
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
                    '圃場平均（全期間・$parameter）',
                    style: TextStyle(
                      color: colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    farmAverage == null ? 'データなし' : '全測定日の平均',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.62),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              farmAverage == null ? '--' : farmAverage!.toStringAsFixed(1),
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
            ),
            if (unit != null && farmAverage != null) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(unit!),
              ),
            ],
          ],
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

class _TimeseriesChart extends StatefulWidget {
  const _TimeseriesChart({required this.data, required this.farmAverage});

  final TimeseriesResult data;
  final double? farmAverage;

  @override
  State<_TimeseriesChart> createState() => _TimeseriesChartState();
}

class _TimeseriesChartState extends State<_TimeseriesChart> {
  final Map<int, Offset> _pointerPositions = {};
  double _zoom = 1;
  double _viewportStart = 0;
  bool _isPinching = false;
  double _pinchStartDistance = 1;
  double _pinchStartZoom = 1;
  double _pinchAnchorDateFraction = 0.5;
  ScrollHoldController? _scrollHold;

  @override
  void didUpdateWidget(covariant _TimeseriesChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _zoom = 1;
      _viewportStart = 0;
      _pointerPositions.clear();
    }
  }

  @override
  void dispose() {
    _scrollHold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 12, 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = constraints.biggest;
            final viewportEnd = _viewportStart + 1 / _zoom;
            return Stack(
              children: [
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) =>
                      _handlePointerDown(event, size, context),
                  onPointerMove: (event) => _handlePointerMove(event, size),
                  onPointerUp: _handlePointerEnd,
                  onPointerCancel: _handlePointerEnd,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) {
                        if (_isPinching || _pointerPositions.length > 1) return;
                        final chart = _TimeseriesChartPainter.chartRectFor(
                          size,
                        );
                        final maxStart = 1 - 1 / _zoom;
                        setState(() {
                          _viewportStart =
                              (_viewportStart -
                                      details.delta.dx / chart.width / _zoom)
                                  .clamp(0, maxStart);
                        });
                      },
                      onTapUp: (details) {
                        final logs = _workLogsAt(
                          details.localPosition,
                          size,
                          data,
                          viewportStart: _viewportStart,
                          viewportEnd: viewportEnd,
                        );
                        if (logs.isNotEmpty) {
                          _showWorkLogDetail(context, logs);
                          return;
                        }
                        final index = _pointIndexAt(
                          details.localPosition,
                          size,
                          data,
                          viewportStart: _viewportStart,
                          viewportEnd: viewportEnd,
                        );
                        if (index == null) return;
                        _showMeasurementDetail(
                          context,
                          data,
                          data.points[index],
                        );
                      },
                      child: CustomPaint(
                        painter: _TimeseriesChartPainter(
                          points: data.points,
                          workLogs: data.workLogs,
                          farmAverage: widget.farmAverage,
                          textColor: Theme.of(context).colorScheme.onSurface,
                          baseTextStyle: DefaultTextStyle.of(context).style,
                          viewportStart: _viewportStart,
                          viewportEnd: viewportEnd,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.88),
                    shape: const CircleBorder(),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: '表示をリセット',
                      onPressed: _resetViewport,
                      icon: const Icon(Icons.center_focus_strong, size: 20),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _handlePointerDown(
    PointerDownEvent event,
    Size size,
    BuildContext context,
  ) {
    _pointerPositions[event.pointer] = event.localPosition;
    if (_pointerPositions.length != 2) return;
    _isPinching = true;
    _scrollHold?.cancel();
    _scrollHold = Scrollable.maybeOf(context)?.position.hold(() {});
    final positions = _pointerPositions.values.take(2).toList(growable: false);
    _pinchStartDistance = math.max(1, (positions[0] - positions[1]).distance);
    _pinchStartZoom = _zoom;
    final focalPoint = Offset(
      (positions[0].dx + positions[1].dx) / 2,
      (positions[0].dy + positions[1].dy) / 2,
    );
    final normalizedX = _normalizedChartX(focalPoint.dx, size);
    _pinchAnchorDateFraction = _viewportStart + normalizedX / _zoom;
  }

  void _handlePointerMove(PointerMoveEvent event, Size size) {
    if (!_pointerPositions.containsKey(event.pointer)) return;
    _pointerPositions[event.pointer] = event.localPosition;
    if (!_isPinching || _pointerPositions.length < 2) return;

    final positions = _pointerPositions.values.take(2).toList(growable: false);
    final distance = math.max(1, (positions[0] - positions[1]).distance);
    final focalPoint = Offset(
      (positions[0].dx + positions[1].dx) / 2,
      (positions[0].dy + positions[1].dy) / 2,
    );
    final maxZoom = _maxZoomFor(widget.data);
    final nextZoom = (_pinchStartZoom * distance / _pinchStartDistance).clamp(
      1.0,
      maxZoom,
    );
    final normalizedX = _normalizedChartX(focalPoint.dx, size);
    final maxStart = 1 - 1 / nextZoom;
    final nextStart = (_pinchAnchorDateFraction - normalizedX / nextZoom).clamp(
      0.0,
      maxStart,
    );
    setState(() {
      _zoom = nextZoom;
      _viewportStart = nextStart;
    });
  }

  void _handlePointerEnd(PointerEvent event) {
    _pointerPositions.remove(event.pointer);
    if (_pointerPositions.length >= 2) return;
    _isPinching = false;
    _scrollHold?.cancel();
    _scrollHold = null;
  }

  double _normalizedChartX(double x, Size size) {
    final chart = _TimeseriesChartPainter.chartRectFor(size);
    return ((x - chart.left) / chart.width).clamp(0.0, 1.0);
  }

  double _maxZoomFor(TimeseriesResult data) {
    final range = _TimeseriesChartPainter.dateRangeFor(
      data.points,
      data.workLogs,
    );
    if (range == null) return 6;
    final days = math.max(1, range.$2.difference(range.$1).inDays);
    return (days / 7).clamp(1.0, 200.0);
  }

  void _resetViewport() {
    if (!mounted) return;
    setState(() {
      _zoom = 1;
      _viewportStart = 0;
    });
  }

  int? _pointIndexAt(
    Offset tap,
    Size size,
    TimeseriesResult data, {
    required double viewportStart,
    required double viewportEnd,
  }) {
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
        viewportStart: viewportStart,
        viewportEnd: viewportEnd,
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

  List<WorkLogMark> _workLogsAt(
    Offset tap,
    Size size,
    TimeseriesResult data, {
    required double viewportStart,
    required double viewportEnd,
  }) {
    if (data.workLogs.isEmpty) return const [];
    final chart = _TimeseriesChartPainter.chartRectFor(size);
    if (!chart.inflate(12).contains(tap)) return const [];
    final range = _TimeseriesChartPainter.dateRangeFor(
      data.points,
      data.workLogs,
    );
    if (range == null) return const [];

    WorkLogMark? nearest;
    var nearestDistance = double.infinity;
    for (final log in data.workLogs) {
      final x = _TimeseriesChartPainter.xForDateString(
        log.date,
        chart,
        range.$1,
        range.$2,
        viewportStart: viewportStart,
        viewportEnd: viewportEnd,
      );
      if (x == null) continue;
      final distance = (tap.dx - x).abs();
      if (distance <= 12 && distance < nearestDistance) {
        nearest = log;
        nearestDistance = distance;
      }
    }
    if (nearest == null) return const [];
    final dateKey = _TimeseriesChartPainter._dateKeyStatic(nearest.date);
    return data.workLogs
        .where(
          (log) => _TimeseriesChartPainter._dateKeyStatic(log.date) == dateKey,
        )
        .toList(growable: false);
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

  void _showWorkLogDetail(BuildContext context, List<WorkLogMark> logs) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _WorkLogDetailSheet(logs: logs),
    );
  }
}

class _WorkLogDetailSheet extends StatelessWidget {
  const _WorkLogDetailSheet({required this.logs});

  final List<WorkLogMark> logs;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _TimeseriesChartPainter._dateKeyStatic(logs.first.date),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.62),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                logs.length == 1 ? '作業内容' : '作業内容（${logs.length}件）',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    final title = log.title?.trim();
                    final details = <String>[
                      if (title?.isNotEmpty == true)
                        _workTypeLabel(log.workType),
                      if (log.detail?.trim().isNotEmpty == true)
                        log.detail!.trim(),
                      if (log.amountValue != null)
                        '${_formatWorkAmount(log.amountValue!)}'
                            '${log.amountUnit?.trim().isNotEmpty == true ? ' ${log.amountUnit!.trim()}' : ''}',
                    ];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.agriculture_outlined,
                        color: Colors.orange.shade800,
                      ),
                      title: Text(
                        title?.isNotEmpty == true
                            ? title!
                            : _workTypeLabel(log.workType),
                      ),
                      subtitle: details.isEmpty
                          ? null
                          : Text(details.join('\n')),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatWorkAmount(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
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
    required this.farmAverage,
    required this.textColor,
    required this.baseTextStyle,
    required this.viewportStart,
    required this.viewportEnd,
  });

  final List<TimeseriesPoint> points;
  final List<WorkLogMark> workLogs;
  final double? farmAverage;
  final Color textColor;
  final TextStyle baseTextStyle;
  final double viewportStart;
  final double viewportEnd;

  static const left = 44.0;
  static const right = 10.0;
  static const top = 12.0;
  static const bottom = 40.0;
  static const _labelGap = 6.0;

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
    DateTime maxDate, {
    double viewportStart = 0,
    double viewportEnd = 1,
  }) {
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
    final dateFraction = offsetDays / totalDays;
    final visibleFraction = viewportEnd - viewportStart;
    if (visibleFraction <= 0) return null;
    return chart.left +
        chart.width * ((dateFraction - viewportStart) / visibleFraction);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final chart = chartRectFor(size);
    if (chart.width <= 0 || chart.height <= 0) return;

    final dateRange = dateRangeFor(points, workLogs);
    if (dateRange == null) return;
    final (minDate, maxDate) = dateRange;

    final minY = [
      ...points.map((p) => p.avg),
      if (farmAverage != null) farmAverage!,
    ].reduce(math.min);
    final maxY = [
      ...points.map((p) => p.avg),
      if (farmAverage != null) farmAverage!,
    ].reduce(math.max);
    final yPadding = (maxY - minY).abs() < 0.001 ? 1.0 : (maxY - minY) * 0.12;
    final y0 = minY - yPadding;
    final y1 = maxY + yPadding;

    double? xForDate(String date) => xForDateString(
      date,
      chart,
      minDate,
      maxDate,
      viewportStart: viewportStart,
      viewportEnd: viewportEnd,
    );

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

    canvas.save();
    canvas.clipRect(chart);

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
      canvas.drawCircle(
        Offset(x, chart.top),
        4,
        Paint()..color = Colors.orange.shade800,
      );
    }

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

    if (farmAverage != null) {
      final avgY = yFor(farmAverage!);
      final farmAvgPaint = Paint()
        ..color = Colors.grey.withValues(alpha: 0.85)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      _drawDashedLine(
        canvas,
        Offset(chart.left, avgY),
        Offset(chart.right, avgY),
        farmAvgPaint,
        dashLength: 8,
        dashSpace: 4,
        horizontal: true,
      );
    }
    canvas.restore();

    final visibleDays =
        maxDate.difference(minDate).inDays * (viewportEnd - viewportStart);
    final showYear = visibleDays >= 365;
    final axisDates = _axisDatesForViewport(minDate, maxDate);
    final candidates =
        <({double x, double left, double right, TextPainter painter})>[];
    for (final date in axisDates) {
      final x = xForDate(date);
      if (x == null || x < chart.left || x > chart.right) continue;
      final painter = _textPainter(
        _axisDate(date, showYear: showYear),
        fontSize: 10,
        color: textColor.withValues(alpha: 0.68),
      );
      final labelLeft = (x - painter.width / 2).clamp(
        chart.left,
        chart.right - painter.width,
      );
      candidates.add((
        x: x,
        left: labelLeft,
        right: labelLeft + painter.width,
        painter: painter,
      ));
    }
    if (candidates.isNotEmpty) {
      final visibleLabels =
          <({double x, double left, double right, TextPainter painter})>[
            candidates.first,
          ];
      for (var i = 1; i < candidates.length - 1; i++) {
        final candidate = candidates[i];
        if (candidate.left >= visibleLabels.last.right + _labelGap) {
          visibleLabels.add(candidate);
        }
      }
      if (candidates.length > 1) {
        final last = candidates.last;
        while (visibleLabels.length > 1 &&
            last.left < visibleLabels.last.right + _labelGap) {
          visibleLabels.removeLast();
        }
        if (last.left >= visibleLabels.last.right + _labelGap) {
          visibleLabels.add(last);
        }
      }
      for (final label in visibleLabels) {
        canvas.drawLine(
          Offset(label.x, chart.bottom),
          Offset(label.x, chart.bottom + 4),
          Paint()
            ..color = textColor.withValues(alpha: 0.35)
            ..strokeWidth = 1,
        );
        label.painter.paint(canvas, Offset(label.left, chart.bottom + 8));
      }
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint, {
    double dashLength = 6.0,
    double dashSpace = 4.0,
    bool horizontal = false,
  }) {
    if (horizontal) {
      var currentX = start.dx;
      while (currentX < end.dx) {
        canvas.drawLine(
          Offset(currentX, start.dy),
          Offset(math.min(currentX + dashLength, end.dx), start.dy),
          paint,
        );
        currentX += dashLength + dashSpace;
      }
      return;
    }

    var currentY = start.dy;
    while (currentY < end.dy) {
      canvas.drawLine(
        Offset(start.dx, currentY),
        Offset(start.dx, math.min(currentY + dashLength, end.dy)),
        paint,
      );
      currentY += dashLength + dashSpace;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required double fontSize,
    required Color color,
  }) {
    _textPainter(text, fontSize: fontSize, color: color).paint(canvas, offset);
  }

  TextPainter _textPainter(
    String text, {
    required double fontSize,
    required Color color,
    double? maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        style: baseTextStyle.copyWith(fontSize: fontSize, color: color),
        text: text,
      ),
      textDirection: TextDirection.ltr,
      locale: const Locale('ja', 'JP'),
      maxLines: 1,
      ellipsis: maxWidth == null ? null : '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    return painter;
  }

  List<String> _axisDatesForViewport(DateTime minDate, DateTime maxDate) {
    final totalDuration = maxDate.difference(minDate);
    if (totalDuration.inMilliseconds <= 0) {
      return [_dateKeyStatic(minDate.toIso8601String())];
    }

    final visibleStart = minDate.add(
      Duration(
        milliseconds: (totalDuration.inMilliseconds * viewportStart).round(),
      ),
    );
    final visibleEnd = minDate.add(
      Duration(
        milliseconds: (totalDuration.inMilliseconds * viewportEnd).round(),
      ),
    );
    final visibleDays = math.max(
      1,
      visibleEnd.difference(visibleStart).inHours / 24,
    );
    final stepDays = switch (visibleDays) {
      <= 10 => 1,
      <= 35 => 5,
      <= 90 => 14,
      <= 240 => 30,
      <= 730 => 90,
      _ => 365,
    };

    var tick = DateTime(
      visibleStart.year,
      visibleStart.month,
      visibleStart.day,
    );
    if (tick.isBefore(visibleStart)) {
      tick = tick.add(const Duration(days: 1));
    }
    final dates = <String>[];
    while (!tick.isAfter(visibleEnd) && dates.length < 50) {
      dates.add(_dateKeyStatic(tick.toIso8601String()));
      tick = tick.add(Duration(days: stepDays));
    }
    return dates;
  }

  String _axisDate(String date, {required bool showYear}) {
    final parsed = DateTime.tryParse(_dateKeyStatic(date));
    if (parsed == null) return date;
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    if (showYear) {
      final year = (parsed.year % 100).toString().padLeft(2, '0');
      return '$year/$month/$day';
    }
    return '$month/$day';
  }

  @override
  bool shouldRepaint(covariant _TimeseriesChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.workLogs != workLogs ||
        oldDelegate.farmAverage != farmAverage ||
        oldDelegate.textColor != textColor ||
        oldDelegate.baseTextStyle != baseTextStyle ||
        oldDelegate.viewportStart != viewportStart ||
        oldDelegate.viewportEnd != viewportEnd;
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
    return const Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _LegendItem(color: Color(0xFF2E5C39), label: '日別平均'),
        _LegendItem(color: Colors.grey, label: '圃場平均（全期間）', isDashed: true),
        _LegendItem(color: Colors.orange, label: '作業'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.isDashed = false,
  });

  final Color color;
  final String label;
  final bool isDashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDashed)
          SizedBox(
            width: 18,
            height: 4,
            child: CustomPaint(painter: _DashedLineLegendPainter(color: color)),
          )
        else
          Container(width: 18, height: 4, color: color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _DashedLineLegendPainter extends CustomPainter {
  const _DashedLineLegendPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dashLength = 4.0;
    const dashSpace = 2.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset(math.min(x + dashLength, size.width), y),
        paint,
      );
      x += dashLength + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLineLegendPainter oldDelegate) {
    return oldDelegate.color != color;
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
