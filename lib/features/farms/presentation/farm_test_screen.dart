import 'package:flutter/material.dart';
import '../data/farm_repository.dart';

class FarmTestScreen extends StatefulWidget {
  final FarmRepository farmRepository;
  const FarmTestScreen({required this.farmRepository, super.key});

  @override
  State<FarmTestScreen> createState() => _FarmTestScreenState();
}

class _FarmTestScreenState extends State<FarmTestScreen> {
  bool _isLoading = false;
  String _result = '';

  /// 疎通確認: /api/v1/me
  Future<void> _testMe() async {
    setState(() {
      _isLoading = true;
      _result = 'テスト中...';
    });
    try {
      final userInfo = await widget.farmRepository.getMe();
      setState(() {
        _result = '成功!\n${userInfo.toString()}';
      });
    } catch (e) {
      setState(() {
        _result = 'エラー: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 疎通確認: 圃場登録
  Future<void> _testCreateFarm() async {
    setState(() {
      _isLoading = true;
      _result = 'テスト中...';
    });
    try {
      final farm = await widget.farmRepository.createFarm(
        farmName: 'テスト圃場',
        cultivationMethod: '有機栽培',
        cropType: 'トマト',
        boundaryPolygon: [
          {'lat': 35.0, 'lng': 139.0},
          {'lat': 35.0, 'lng': 139.1},
          {'lat': 35.1, 'lng': 139.1},
          {'lat': 35.1, 'lng': 139.0}, // 4点目を追加（閉じたポリゴン）
        ],
      );
      setState(() {
        _result = '登録成功!\nID: ${farm.id}\n名前: ${farm.farmName}';
      });
    } catch (e) {
      setState(() {
        _result = 'エラー: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 疎通確認: 圃場一覧取得
  Future<void> _testGetFarms() async {
    setState(() {
      _isLoading = true;
      _result = 'テスト中...';
    });
    try {
      final farms = await widget.farmRepository.getFarms();
      setState(() {
        _result = '取得成功!\n件数: ${farms.length}';
        for (var farm in farms) {
          _result += '\n- ${farm.farmName} (ID: ${farm.id})';
        }
      });
    } catch (e) {
      setState(() {
        _result = 'エラー: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('API疎通確認')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _testMe,
              child: const Text('1. /api/v1/me テスト'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testCreateFarm,
              child: const Text('2. 圃場登録テスト'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _testGetFarms,
              child: const Text('3. 圃場一覧取得テスト'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(_result),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

