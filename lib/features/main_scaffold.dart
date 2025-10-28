import 'package:flutter/material.dart';
import 'results/presentation/home_screen.dart';
import 'measure/presentation/measure_screen.dart';
import 'farms/presentation/farm_screen.dart';
import 'common_widgets/bottom_nav_bar.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final _pages = const [
    HomeScreen(), //左タブ：結果表示（＝ホーム）
    MeasureScreen(), //中央タブ：測定画面
    FarmScreen(), //右タブ：圃場管理画面
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}