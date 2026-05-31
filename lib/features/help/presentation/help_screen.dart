import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'faq_screen.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ヘルプ'),
        backgroundColor: const Color(0xFF4A6A80),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HelpCard(
            icon: Icons.menu_book,
            title: '使い方ガイド',
            subtitle: 'アプリの基本フロー（5ステップ）',
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const _GuideSheet(),
              );
            },
          ),
          const SizedBox(height: 12),
          _HelpCard(
            icon: Icons.help_outline,
            title: 'よくある質問（FAQ）',
            subtitle: '測定失敗・同期エラーなど',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FaqScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _HelpCard(
            icon: Icons.mail_outline,
            title: 'お問い合わせ',
            subtitle: 'サポートに連絡する',
            onTap: () => _showPreparing(context),
          ),
          const SizedBox(height: 12),
          _HelpCard(
            icon: Icons.info_outline,
            title: 'アプリ情報',
            subtitle: '利用規約・ライセンス',
            onTap: () async {
              final info = await PackageInfo.fromPlatform();
              if (!context.mounted) return;
              showAboutDialog(
                context: context,
                applicationName: 'HenryMonitor',
                applicationVersion: 'v${info.version} (${info.buildNumber})',
                children: const [
                  SizedBox(height: 8),
                  Text('磁界式センサーと機械学習による土壌成分分析アプリ'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPreparing(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('この項目は準備中です')));
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF2E5C39)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _GuideSheet extends StatelessWidget {
  const _GuideSheet();

  static const _steps = [
    ('圃場を登録', '地図上で多角形を描いて圃場を登録します'),
    ('機器を接続', 'センサとスマートフォンを接続し、接続ボタンを押します'),
    ('BGを取得', '基準（バックグラウンド）を測定すると測定準備が完了します'),
    ('測定・推定する', '「測定開始」を押して測定します。ネットワーク接続時は推定完了後に結果が表示されます'),
    ('同期する', '電波のない場所では、後で同期画面からアップロードします'),
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      expand: false,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            const Text(
              'はじめての測定までの流れ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            for (final (index, step) in _steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF4A6A80),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.$1,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step.$2,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.68),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
