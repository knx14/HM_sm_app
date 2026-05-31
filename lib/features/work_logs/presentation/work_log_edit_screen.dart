import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/work_log_entry.dart';
import 'work_log_notifier.dart';

class WorkLogEditScreen extends StatelessWidget {
  const WorkLogEditScreen({super.key, required this.farmId});

  final int farmId;

  static Future<bool> show(BuildContext context, {required int farmId}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ChangeNotifierProvider(
          create: (_) => WorkLogNotifier(farmId: farmId),
          child: WorkLogEditScreen(farmId: farmId),
        );
      },
    );
    return result ?? false;
  }

  static Future<bool> showEdit(
    BuildContext context, {
    required int farmId,
    required int workLogId,
    required WorkLogEntry initial,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ChangeNotifierProvider(
          create: (_) => WorkLogNotifier.forEdit(
            farmId: farmId,
            workLogId: workLogId,
            initial: initial,
          ),
          child: WorkLogEditScreen(farmId: farmId),
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<WorkLogNotifier>();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.78,
        minChildSize: 0.48,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          notifier.isEditMode ? '作業記録を編集' : '作業記録を追加',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _StepIndicator(step: notifier.step),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: notifier.isSaving
                      ? const Center(child: CircularProgressIndicator())
                      : switch (notifier.step) {
                          0 => _WorkTypeStep(
                            scrollController: scrollController,
                          ),
                          1 => _DetailStep(scrollController: scrollController),
                          _ => _ConfirmStep(scrollController: scrollController),
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['種別', '詳細', '確認'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          _StepDot(number: i + 1, label: labels[i], active: i <= step),
          if (i < labels.length - 1)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.30),
              ),
            ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.number,
    required this.label,
    required this.active,
  });

  final int number;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final activeColor = const Color(0xFF2E5C39);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: active
              ? activeColor
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Text(
            '$number',
            style: TextStyle(
              color: active
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _WorkTypeStep extends StatelessWidget {
  const _WorkTypeStep({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<WorkLogNotifier>();
    return GridView.count(
      controller: scrollController,
      padding: const EdgeInsets.all(20),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: WorkType.values.map((type) {
        return Material(
          color: type.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => notifier.selectWorkType(type),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(type.icon, color: type.color),
                const SizedBox(width: 8),
                Text(
                  type.label,
                  style: TextStyle(
                    color: type.color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DetailStep extends StatefulWidget {
  const _DetailStep({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_DetailStep> createState() => _DetailStepState();
}

class _DetailStepState extends State<_DetailStep> {
  late final TextEditingController _titleController;
  late final TextEditingController _detailController;
  late final TextEditingController _amountController;
  late String _amountUnit;

  @override
  void initState() {
    super.initState();
    final notifier = context.read<WorkLogNotifier>();
    _titleController = TextEditingController(text: notifier.title);
    _detailController = TextEditingController(text: notifier.detail);
    _amountController = TextEditingController(text: notifier.amountText);
    _amountUnit = notifier.amountUnit;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<WorkLogNotifier>();
    final type = notifier.workType!;
    final presets = titlePresets[type] ?? const <String>[];

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Chip(
          avatar: Icon(type.icon, color: type.color, size: 18),
          label: Text(type.label),
          backgroundColor: type.color.withValues(alpha: 0.12),
          labelStyle: TextStyle(color: type.color, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event_outlined),
          title: const Text('日付'),
          subtitle: Text(notifier.workDate),
          trailing: TextButton(
            onPressed: () async {
              final initialDate =
                  DateTime.tryParse(notifier.workDate) ?? DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null && context.mounted) {
                await notifier.pickDate(picked);
              }
            },
            child: const Text('変更'),
          ),
        ),
        if (presets.isNotEmpty) ...[
          Text(
            'よく使う',
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.62),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((preset) {
              return ActionChip(
                label: Text(preset),
                onPressed: () => setState(() => _titleController.text = preset),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'タイトル',
            hintText: '例: NK化成 20kg',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '量（任意）',
                ),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<String>(
              value: _amountUnit,
              items: unitPresets
                  .map(
                    (unit) => DropdownMenuItem(value: unit, child: Text(unit)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _amountUnit = value);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _detailController,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: '詳細メモ（任意）',
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            OutlinedButton(onPressed: notifier.goBack, child: const Text('戻る')),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () => notifier.updateDetails(
                  nextDate: notifier.workDate,
                  nextTitle: _titleController.text.trim(),
                  nextDetail: _detailController.text.trim(),
                  nextAmountText: _amountController.text.trim(),
                  nextAmountUnit: _amountUnit,
                ),
                child: const Text('確認へ'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<WorkLogNotifier>();
    final type = notifier.workType!;
    final amountLabel = notifier.amountText.isEmpty
        ? null
        : '${notifier.amountText} ${notifier.amountUnit}';

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text(
          notifier.isEditMode ? '以下の内容で更新します' : '以下の内容で登録します',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        _ConfirmRow(label: '種別', value: type.label),
        _ConfirmRow(label: '日付', value: notifier.workDate),
        if (notifier.title.isNotEmpty)
          _ConfirmRow(label: 'タイトル', value: notifier.title),
        if (amountLabel != null) _ConfirmRow(label: '量', value: amountLabel),
        if (notifier.detail.isNotEmpty)
          _ConfirmRow(label: 'メモ', value: notifier.detail),
        if (notifier.saveError != null) ...[
          const SizedBox(height: 12),
          Text(
            notifier.saveError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            OutlinedButton(onPressed: notifier.goBack, child: const Text('修正')),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  await notifier.save();
                  if (!context.mounted || !notifier.isSaveComplete) return;
                  Navigator.pop(context, true);
                },
                icon: const Icon(Icons.save_outlined),
                label: Text(notifier.isEditMode ? '更新' : '保存'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
