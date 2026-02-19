import 'package:flutter/material.dart';

import '../measurement_session_screen.dart' show SessionStep;

class StepIndicatorBar extends StatelessWidget {
  final SessionStep currentStep;
  /// Step1(接続)が完了したか。仕様上は「接続 + Recall完了」を指す。
  final bool isStep1Done;
  /// BGが完了したか（必須）。
  final bool isBgDone;

  const StepIndicatorBar({
    super.key,
    required this.currentStep,
    required this.isStep1Done,
    required this.isBgDone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget item({
      required int index,
      required String label,
      required bool done,
      required bool active,
    }) {
      final base = theme.textTheme.bodySmall!;
      final color = active
          ? theme.colorScheme.primary
          : done
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant;

      final textStyle = active ? base.copyWith(fontWeight: FontWeight.w700, color: color) : base.copyWith(color: color);

      return Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color),
                  ),
                  child: done
                      ? Icon(Icons.check, size: 14, color: color)
                      : Text('$index', style: textStyle),
                ),
                const SizedBox(width: 6),
                Text(label, style: textStyle),
              ],
            ),
          ],
        ),
      );
    }

    bool isActive(SessionStep s) => currentStep == s;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          item(
            index: 1,
            label: '接続',
            done: isStep1Done,
            active: isActive(SessionStep.connect),
          ),
          item(
            index: 2,
            label: 'BG測定',
            done: isBgDone,
            active: isActive(SessionStep.bg),
          ),
          item(
            index: 3,
            label: '本測定',
            done: false,
            active: isActive(SessionStep.measure),
          ),
        ],
      ),
    );
  }
}

