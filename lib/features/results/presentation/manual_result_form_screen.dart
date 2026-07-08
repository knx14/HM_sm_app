import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/manual_result_parameter.dart';
import 'providers/manual_result_notifier.dart';

class ManualResultFormScreen extends StatelessWidget {
  const ManualResultFormScreen({
    super.key,
    required this.farmId,
    required this.isProvisional,
  });

  final int farmId;
  final bool isProvisional;

  static Future<bool> show(
    BuildContext context, {
    required int farmId,
    required bool isProvisional,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ChangeNotifierProvider(
          create: (_) => ManualResultNotifier(
            farmId: farmId,
            isProvisional: isProvisional,
          ),
          child: ManualResultFormScreen(
            farmId: farmId,
            isProvisional: isProvisional,
          ),
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<ManualResultNotifier>();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.5,
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
                      const Expanded(
                        child: Text(
                          '過去の測定結果を追加',
                          style: TextStyle(
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
                if (isProvisional)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'この圃場は境界が未設定のため、過去実績を登録できません',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    children: [
                      _DateField(
                        date: notifier.measurementDate,
                        enabled: !isProvisional,
                        onPick: () => _pickDate(context, notifier),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '測定値（未入力の項目は送信しません）',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final param in manualResultParameters) ...[
                        _ParameterField(
                          parameter: param,
                          value: notifier.valueTexts[param.name] ?? '',
                          onChanged: notifier.isProvisional
                              ? null
                              : (value) =>
                                    notifier.setValueText(param.name, value),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (notifier.saveError != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          notifier.saveError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: notifier.canSubmit
                            ? () => _submit(context, notifier)
                            : null,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF2E5C39),
                        ),
                        child: notifier.isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('登録する'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickDate(
    BuildContext context,
    ManualResultNotifier notifier,
  ) async {
    final current =
        DateTime.tryParse(notifier.measurementDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('ja', 'JP'),
    );
    if (picked == null) return;
    notifier.setMeasurementDate(
      '${picked.year.toString().padLeft(4, '0')}-'
      '${picked.month.toString().padLeft(2, '0')}-'
      '${picked.day.toString().padLeft(2, '0')}',
    );
  }

  Future<void> _submit(
    BuildContext context,
    ManualResultNotifier notifier,
  ) async {
    final saved = await notifier.submit();
    if (!context.mounted) return;
    if (saved) {
      Navigator.pop(context, true);
      return;
    }
    if (notifier.saveError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(notifier.saveError!)));
    }
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.date,
    required this.enabled,
    required this.onPick,
  });

  final String date;
  final bool enabled;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '測定日',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: enabled ? onPick : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      date,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                    color: colorScheme.onSurface.withValues(alpha: 0.62),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ParameterField extends StatefulWidget {
  const _ParameterField({
    required this.parameter,
    required this.value,
    required this.onChanged,
  });

  final ManualResultParameterDef parameter;
  final String value;
  final ValueChanged<String>? onChanged;

  @override
  State<_ParameterField> createState() => _ParameterFieldState();
}

class _ParameterFieldState extends State<_ParameterField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _ParameterField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onChanged != null;

    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.parameter.label,
        hintText: '未入力可',
        border: const OutlineInputBorder(),
      ),
    );
  }
}
