import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../results/domain/timeline_item.dart';
import '../../../results/presentation/providers/timeline_notifier.dart';
import '../../../results/presentation/widgets/farm_record_add_sheet.dart';
import '../../../work_logs/data/work_log_repository.dart';
import '../../../work_logs/domain/work_log_entry.dart';
import '../../../work_logs/presentation/work_log_edit_screen.dart';

class FarmTimelineTab extends StatelessWidget {
  const FarmTimelineTab({
    super.key,
    required this.farmId,
    required this.isProvisional,
  });

  final int farmId;
  final bool isProvisional;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TimelineNotifier(farmId: farmId)..loadInitial(),
      child: _TimelineView(isProvisional: isProvisional),
    );
  }
}

class _TimelineView extends StatelessWidget {
  const _TimelineView({required this.isProvisional});

  final bool isProvisional;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TimelineNotifier>();

    final Widget body;
    if (state.isLoading && state.items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.error != null && state.items.isEmpty) {
      body = _ErrorState(message: state.error!, onRetry: state.reload);
    } else if (state.items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: state.reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Center(child: Text('測定データ・作業ログがありません')),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: state.reload,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          itemCount: state.items.length + (state.isLoading ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index == 0 && state.isLoading) {
              return const LinearProgressIndicator(minHeight: 2);
            }
            final item = state.items[index - (state.isLoading ? 1 : 0)];
            return switch (item) {
              MeasurementTimelineItem() => _MeasurementCard(item: item),
              WorkLogTimelineItem() => _WorkLogCard(
                item: item,
                onEdit: () => _editWorkLog(context, state, item),
                onDelete: () => _deleteWorkLog(context, state, item),
              ),
              UnknownTimelineItem() => const SizedBox.shrink(),
            };
          },
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: body),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'timeline_add_fab_${state.farmId}',
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

  Future<void> _editWorkLog(
    BuildContext context,
    TimelineNotifier state,
    WorkLogTimelineItem item,
  ) async {
    final workLogId = await _resolveWorkLogId(item, state.farmId);
    if (workLogId == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('作業記録IDを取得できませんでした')));
      return;
    }
    if (!context.mounted) return;
    final saved = await WorkLogEditScreen.showEdit(
      context,
      farmId: state.farmId,
      workLogId: workLogId,
      initial: _entryFromItem(item),
    );
    if (!saved || !context.mounted) return;
    await state.reload();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('作業記録を更新しました')));
  }

  Future<void> _deleteWorkLog(
    BuildContext context,
    TimelineNotifier state,
    WorkLogTimelineItem item,
  ) async {
    final workLogId = await _resolveWorkLogId(item, state.farmId);
    if (workLogId == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('作業記録IDを取得できませんでした')));
      return;
    }
    if (!context.mounted) return;
    final title = item.title?.isNotEmpty == true ? item.title! : '作業記録';
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('作業記録を削除'),
        content: Text('「$title」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await WorkLogRepository().delete(workLogId);
      await state.reload();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('作業記録を削除しました')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('削除に失敗しました')));
    }
  }

  WorkLogEntry _entryFromItem(WorkLogTimelineItem item) {
    return WorkLogEntry(
      workType: item.workType,
      workDate: item.date.length >= 10 ? item.date.substring(0, 10) : item.date,
      title: item.title,
      detail: item.detail,
      amountValue: item.amountValue,
      amountUnit: item.amountUnit,
    );
  }

  Future<int?> _resolveWorkLogId(WorkLogTimelineItem item, int farmId) async {
    if (item.id > 0) return item.id;
    try {
      final logs = await WorkLogRepository().listByFarm(farmId);
      for (final log in logs) {
        final id = (log['id'] as num?)?.toInt();
        if (id == null) continue;
        if (_matchesWorkLog(item, log)) return id;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  bool _matchesWorkLog(WorkLogTimelineItem item, Map<String, dynamic> log) {
    final logDate = log['work_date'] as String? ?? log['date'] as String?;
    final sameDate = _dateKey(logDate) == _dateKey(item.date);
    final sameType = (log['work_type'] as String?) == item.workType;
    final sameTitle = (log['title'] as String?) == item.title;
    final sameDetail = (log['detail'] as String?) == item.detail;
    final logAmount = (log['amount_value'] as num?)?.toDouble();
    final sameAmount = logAmount == item.amountValue;
    return sameDate && sameType && sameTitle && sameDetail && sameAmount;
  }

  String _dateKey(String? date) {
    if (date == null) return '';
    return date.length >= 10 ? date.substring(0, 10) : date;
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
    final deltaColor = (delta ?? 0) >= 0
        ? Colors.green.shade700
        : colorScheme.error;

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
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
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
                        const Icon(
                          Icons.analytics_outlined,
                          size: 18,
                          color: Color(0xFF2E5C39),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '測定結果',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        Text(
                          '${_shortDate(item.date)} / ${item.countPoints}点',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.62,
                            ),
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
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.62,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatStat(cec),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (delta != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: deltaColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                              style: TextStyle(
                                color: deltaColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: const ['CaO', 'K2O', 'MgO']
                          .map(
                            (key) => _ParameterChip(
                              label: key,
                              stat: item.values[key],
                            ),
                          )
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
    return unit == null
        ? avg.toStringAsFixed(1)
        : '${avg.toStringAsFixed(1)} $unit';
  }
}

class _ParameterChip extends StatelessWidget {
  const _ParameterChip({required this.label, required this.stat});

  final String label;
  final ParameterStat? stat;

  @override
  Widget build(BuildContext context) {
    final avg = stat?.avg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text('$label ${avg == null ? '--' : avg.toStringAsFixed(1)}'),
    );
  }
}

class _WorkLogCard extends StatelessWidget {
  const _WorkLogCard({required this.item, this.onEdit, this.onDelete});

  final WorkLogTimelineItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
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
                          if (item.detail != null &&
                              item.detail!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.detail!,
                              style: TextStyle(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.68,
                                ),
                              ),
                            ),
                          ],
                          if (item.amountValue != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${item.amountValue!.toStringAsFixed(1)} ${item.amountUnit ?? ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.62,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _shortDate(item.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.54,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: '作業記録メニュー',
                          onSelected: (value) {
                            if (value == 'edit') onEdit?.call();
                            if (value == 'delete') onDelete?.call();
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              enabled: onEdit != null,
                              child: const ListTile(
                                dense: true,
                                leading: Icon(Icons.edit_outlined),
                                title: Text('編集'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              enabled: onDelete != null,
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: colorScheme.error,
                                ),
                                title: Text(
                                  '削除',
                                  style: TextStyle(color: colorScheme.error),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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

String _shortDate(String date) {
  if (date.length >= 10) {
    return '${date.substring(0, 4)}/${date.substring(5, 7)}/${date.substring(8, 10)}';
  }
  return date;
}
