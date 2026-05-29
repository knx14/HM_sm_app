import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../results/domain/timeline_item.dart';
import '../../../results/presentation/providers/timeline_notifier.dart';

class FarmTimelineTab extends StatelessWidget {
  const FarmTimelineTab({
    super.key,
    required this.farmId,
  });

  final int farmId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TimelineNotifier(farmId: farmId)..loadInitial(),
      child: const _TimelineView(),
    );
  }
}

class _TimelineView extends StatelessWidget {
  const _TimelineView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TimelineNotifier>();

    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.items.isEmpty) {
      return _ErrorState(message: state.error!, onRetry: state.reload);
    }
    if (state.items.isEmpty) {
      return const Center(child: Text('測定データ・作業ログがありません'));
    }

    return RefreshIndicator(
      onRefresh: state.reload,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: state.items.length + (state.isLoading ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == 0 && state.isLoading) {
            return const LinearProgressIndicator(minHeight: 2);
          }
          final item = state.items[index - (state.isLoading ? 1 : 0)];
          return switch (item) {
            MeasurementTimelineItem() => _MeasurementCard(item: item),
            WorkLogTimelineItem() => _WorkLogCard(item: item),
            UnknownTimelineItem() => const SizedBox.shrink(),
          };
        },
      ),
    );
  }
}

class _MeasurementCard extends StatelessWidget {
  const _MeasurementCard({required this.item});

  final MeasurementTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cec = item.values['CEC'];
    final delta = item.deltaCec;
    final deltaColor = (delta ?? 0) >= 0 ? Colors.green.shade700 : colorScheme.error;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF2E5C39),
                borderRadius: BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics_outlined, size: 18, color: Color(0xFF2E5C39)),
                        const SizedBox(width: 6),
                        const Text('測定結果', style: TextStyle(fontWeight: FontWeight.w800)),
                        const Spacer(),
                        Text(
                          '${_shortDate(item.date)} / ${item.countPoints}点',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CEC平均（圃場）',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurface.withValues(alpha: 0.62),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatStat(cec),
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                        if (delta != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: deltaColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                              style: TextStyle(color: deltaColor, fontWeight: FontWeight.w800),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const ['CaO', 'K2O', 'MgO']
                          .map((key) => _ParameterChip(label: key, stat: item.values[key]))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatStat(ParameterStat? stat) {
    final avg = stat?.avg;
    if (avg == null) return '--';
    final unit = stat?.unit;
    return unit == null ? avg.toStringAsFixed(1) : '${avg.toStringAsFixed(1)} $unit';
  }
}

class _ParameterChip extends StatelessWidget {
  const _ParameterChip({
    required this.label,
    required this.stat,
  });

  final String label;
  final ParameterStat? stat;

  @override
  Widget build(BuildContext context) {
    final avg = stat?.avg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label ${avg == null ? '--' : avg.toStringAsFixed(1)}'),
    );
  }
}

class _WorkLogCard extends StatelessWidget {
  const _WorkLogCard({required this.item});

  final WorkLogTimelineItem item;

  static const _colors = <String, Color>{
    'fertilization': Color(0xFFB85C00),
    'tillage': Color(0xFF7A4525),
    'pesticide': Color(0xFF5A2D82),
    'harvest': Color(0xFFB8860B),
    'other': Color(0xFF6B7E68),
  };

  static const _labels = <String, String>{
    'fertilization': '施肥',
    'tillage': '耕うん',
    'pesticide': '農薬',
    'harvest': '収穫',
    'other': 'その他',
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _colors[item.workType] ?? _colors['other']!;
    final label = _labels[item.workType] ?? item.workType;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title ?? '作業記録',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          if (item.detail != null && item.detail!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.detail!,
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.68),
                              ),
                            ),
                          ],
                          if (item.amountValue != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${item.amountValue!.toStringAsFixed(1)} ${item.amountUnit ?? ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface.withValues(alpha: 0.62),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _shortDate(item.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

String _shortDate(String date) {
  if (date.length >= 10) return '${date.substring(5, 7)}/${date.substring(8, 10)}';
  return date;
}
