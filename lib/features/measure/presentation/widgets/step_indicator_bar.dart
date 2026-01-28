import 'package:flutter/material.dart';

import '../measurement_session_screen.dart' show SessionStep;

class StepIndicatorBar extends StatelessWidget {
  final SessionStep currentStep;
  final bool isConnected;
  final bool isZeroDone;
  final bool isBgDoneOrSkipped;

  const StepIndicatorBar({
    super.key,
    required this.currentStep,
    required this.isConnected,
    required this.isZeroDone,
    required this.isBgDoneOrSkipped,
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
            done: isConnected,
            active: isActive(SessionStep.connect),
          ),
          item(
            index: 2,
            label: 'Zero',
            done: isZeroDone,
            active: isActive(SessionStep.zero),
          ),
          item(
            index: 3,
            label: 'BG',
            done: isBgDoneOrSkipped,
            active: isActive(SessionStep.bg),
          ),
          item(
            index: 4,
            label: '測定',
            done: false,
            active: isActive(SessionStep.measure),
          ),
        ],
      ),
    );
  }
}

