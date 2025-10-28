import 'package:flutter/material.dart';

class FarmScreen extends StatelessWidget {
  const FarmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('圃場管理'),
      ),
      body: const Center(
        child: Text(
          'ここに圃場管理機能を実装します',
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
