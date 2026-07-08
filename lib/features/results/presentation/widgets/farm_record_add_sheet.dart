import 'package:flutter/material.dart';

import '../manual_result_form_screen.dart';
import '../../../work_logs/presentation/work_log_edit_screen.dart';

enum FarmRecordAddChoice { workLog, manualResult }

class FarmRecordAddSheet extends StatelessWidget {
  const FarmRecordAddSheet({super.key});

  static Future<FarmRecordAddChoice?> show(BuildContext context) {
    return showModalBottomSheet<FarmRecordAddChoice>(
      context: context,
      showDragHandle: true,
      builder: (_) => const FarmRecordAddSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Text(
                '記録を追加',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            _AddOptionTile(
              icon: Icons.edit_outlined,
              iconColor: const Color(0xFF2E5C39),
              title: '作業記録を追加',
              onTap: () => Navigator.pop(context, FarmRecordAddChoice.workLog),
            ),
            const SizedBox(height: 8),
            _AddOptionTile(
              icon: Icons.show_chart_outlined,
              iconColor: const Color(0xFF1A4F7A),
              title: '過去の測定結果を追加',
              onTap: () =>
                  Navigator.pop(context, FarmRecordAddChoice.manualResult),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddOptionTile extends StatelessWidget {
  const _AddOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FarmRecordAddActions {
  FarmRecordAddActions._();

  static Future<void> handleFabPressed({
    required BuildContext context,
    required int farmId,
    required bool isProvisional,
    required Future<void> Function() onReload,
  }) async {
    final choice = await FarmRecordAddSheet.show(context);
    if (!context.mounted || choice == null) return;

    switch (choice) {
      case FarmRecordAddChoice.workLog:
        final saved = await WorkLogEditScreen.show(context, farmId: farmId);
        if (!saved || !context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('作業記録を保存しました')));
        await onReload();
      case FarmRecordAddChoice.manualResult:
        final saved = await ManualResultFormScreen.show(
          context,
          farmId: farmId,
          isProvisional: isProvisional,
        );
        if (!saved || !context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('過去の測定結果を登録しました')));
        await onReload();
    }
  }
}
