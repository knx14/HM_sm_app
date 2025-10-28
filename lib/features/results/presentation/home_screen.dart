import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('最近の分析結果'),
      ),
      body: const Center(
        child: Text('ここに測定結果のヒートマップや分析結果一覧を表示する',
        style: TextStyle(fontSize: 16),
        textAlign: TextAlign.center,
      ),
    ),
  );
  }
}