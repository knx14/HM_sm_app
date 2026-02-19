import 'package:flutter/material.dart';

import '../../domain/result_parameter.dart';
import '../../utils/result_formatters.dart' as fmt;

class ResultLegend extends StatelessWidget {
  final bool isCompare;
  final ResultParameter parameter;
  final double min;
  final double max;
  final double deltaMax;

  const ResultLegend({
    super.key,
    required this.isCompare,
    required this.parameter,
    required this.min,
    required this.max,
    required this.deltaMax,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.surface.withValues(alpha: 0.92);
    final border = cs.outline.withValues(alpha: 0.12);

    final label = isCompare
        ? '-${fmt.format1OrZero(deltaMax)} 〜 +${fmt.format1OrZero(deltaMax)}'
        : '${fmt.format1OrZero(min)} 〜 ${fmt.format1OrZero(max)}';

    final gradient = isCompare
        ? const LinearGradient(colors: [Color(0xFF1565C0), Colors.white, Color(0xFFC62828)])
        : const LinearGradient(colors: [Color(0xFFE3F2FD), Color(0xFFC62828)]);

    final uniform = isCompare ? (deltaMax <= 0) : (max <= min);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCompare ? '${parameter.apiName} 差分' : parameter.apiName,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
          const SizedBox(height: 8),
          Container(
            width: 140,
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: uniform ? (isCompare ? Colors.white : const Color(0xFF66BB6A)) : null,
              gradient: uniform ? null : gradient,
              border: Border.all(color: cs.outline.withValues(alpha: 0.08)),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

