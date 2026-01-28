import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'results/presentation/home_screen.dart';
import 'measure/presentation/measurement_session_screen.dart';
import 'farms/presentation/farm_screen.dart';
import 'common_widgets/bottom_nav_bar.dart';
import '../../providers/user_provider.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final _pages = const [
    HomeScreen(), //左タブ：結果表示（＝ホーム）
    MeasurementSessionScreen(), //中央タブ：測定セッション
    FarmScreen(), //右タブ：圃場管理画面
  ];
  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // エラーがある場合はエラー表示
        if (userProvider.error != null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'エラーが発生しました',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userProvider.error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      userProvider.clearError();
                      // 再試行のロジックをここに追加
                    },
                    child: const Text('再試行'),
                  ),
                ],
              ),
            ),
          );
        }

        // ユーザIDが設定されていない場合はローディング表示
        if (userProvider.userId == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // ユーザIDが設定されている場合は通常の画面表示
        return Scaffold(
          body: _pages[_currentIndex],
          bottomNavigationBar: BottomNavBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
          ),
        );
      },
    );
  }
}