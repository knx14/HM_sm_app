import 'package:flutter/material.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _faqs = [
    (
      q: 'センサーが接続できません',
      a:
          'USBケーブルが正しく接続されているか確認してください。\n'
          '接続後、測定画面の「接続 センサ」チップをタップしてください。\n'
          '改善しない場合はアプリを再起動して再度お試しください。',
    ),
    (
      q: 'BG測定が終わらない / 失敗する',
      a:
          'センサーが安定した場所に置かれているか確認してください。\n'
          'BG測定は圃場から離れた場所（金属や強い磁場のない場所）で行ってください。',
    ),
    (
      q: '測定開始ボタンが押せません',
      a:
          '「接続 センサ」「BG 基準」「圃場を選択」の3チップがすべて緑になると\n'
          '測定開始ボタンが有効化されます。いずれかが未完了の場合は再度設定してください。',
    ),
    (
      q: '圃場の外で測定しようとするとエラーになります',
      a:
          '登録した圃場の境界内でのみ測定できます。\n'
          'GPS位置がずれる場合は地図をタップして位置を手動補正してください。',
    ),
    (
      q: 'アップロードが失敗しました',
      a:
          '測定データはローカルに保存されています。\n'
          'ネットワークに接続した後、同期画面からアップロードしてください。',
    ),
    (
      q: '作業記録を誤って登録しました',
      a:
          '現在のバージョンでは作業記録の削除・編集機能は準備中です。\n'
          'お問い合わせから連絡いただければ管理側で対応します。',
    ),
    (
      q: 'CEC 以外の値（CaO、K2O、MgO）が表示されません',
      a:
          'Ca・K・Mg の推定モデルは現在開発中です。\n'
          '完成次第アプリのアップデートで反映されます。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('よくある質問'),
        backgroundColor: const Color(0xFF4A6A80),
        foregroundColor: Colors.white,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _faqs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final faq = _faqs[index];
          return ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: Colors.grey[300]!),
            ),
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.white,
            leading: const Icon(Icons.help_outline, color: Color(0xFF4A6A80)),
            title: Text(
              faq.q,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  faq.a,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
