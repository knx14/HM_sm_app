import 'package:flutter/material.dart';

class FarmTimeseriesTab extends StatelessWidget {
  const FarmTimeseriesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _StubTab(
      icon: Icons.show_chart,
      title: '時系列タブは Phase 5 で実装予定です',
      subtitle: '圃場平均値の推移と作業ログの重ね表示をここに追加します。',
    );
  }
}

class _StubTab extends StatelessWidget {
  const _StubTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 52,
              color: colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
