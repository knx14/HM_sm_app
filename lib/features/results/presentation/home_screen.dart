import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/results_top_notifier.dart';
import 'farm_results_dates_screen.dart';
import 'result_map_screen.dart';
import '../utils/result_formatters.dart';
import '../utils/result_formatters.dart' as fmt;
import '../../../features/auth/data/amplify_auth_service.dart';
import '../../../features/auth/domain/auth_repository.dart';
import '../../../providers/user_provider.dart';
import '../../../app/routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ResultsTopNotifier()..load(),
      child: const _ResultsTopView(),
    );
  }
}

class _ResultsTopView extends StatelessWidget {
  const _ResultsTopView();

  Future<void> _showLogoutDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('ログアウト'),
          content: const Text('ログイン画面に遷移します'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ログアウト'),
            ),
          ],
        );
      },
    );

    if (result == true && context.mounted) {
      await _handleLogout(context);
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      final authRepo = AuthRepository(AmplifyAuthService());
      await authRepo.signOut();
      
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.clearUserId();
      
      if (!context.mounted) return;
      
      // ログインと新規登録画面に遷移（SplashScreen経由でWelcomeViewを表示）
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.splash,
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ログアウトに失敗しました: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          '結果',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
            tooltip: 'ログアウト',
          ),
        ],
      ),
      body: Consumer<ResultsTopNotifier>(
        builder: (context, state, child) {
          return RefreshIndicator(
            onRefresh: () async {
              await Future.wait([state.reloadFeed(), state.reloadFarms()]);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _sectionTitle('最新結果'),
                const SizedBox(height: 12),
                _buildLatestFeedSection(context, state),
                const SizedBox(height: 24),
                _sectionTitle('圃場'),
                const SizedBox(height: 12),
                _buildFarmShortcutsSection(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildLatestFeedSection(BuildContext context, ResultsTopNotifier state) {
    final cs = Theme.of(context).colorScheme;

    if (state.isLoadingFeed) {
      return Column(
        children: const [
          _SkeletonCard(height: 120),
          SizedBox(height: 12),
          _SkeletonCard(height: 120),
          SizedBox(height: 12),
          _SkeletonCard(height: 120),
        ],
      );
    }

    if (state.feedError != null) {
      return _ErrorRetry(
        message: '取得に失敗しました',
        onRetry: state.reloadFeed,
      );
    }

    if (state.feed.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('結果がまだありません'),
      );
    }

    return Column(
      children: state.feed.map((item) {
        final dateText = formatYyyyMmDdSlash(item.latestMeasurementDate);
        final stats = item.cecStats;
        final avg = fmt.format1OrDash(stats.avg);
        final min = fmt.format1OrDash(stats.min);
        final max = fmt.format1OrDash(stats.max);
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ResultMapScreen(
                    farmId: item.farmId,
                    date: item.latestMeasurementDate,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.farmName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(dateText, style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('CEC 平均 $avg / $min–$max'),
                  const SizedBox(height: 8),
                  Text(item.summaryText),
                  const SizedBox(height: 8),
                  Text('測定点 ${stats.countPoints}点'),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFarmShortcutsSection(BuildContext context, ResultsTopNotifier state) {
    final cs = Theme.of(context).colorScheme;

    if (state.isLoadingFarms) {
      return Column(
        children: const [
          _SkeletonCard(height: 88),
          SizedBox(height: 12),
          _SkeletonCard(height: 88),
          SizedBox(height: 12),
          _SkeletonCard(height: 88),
        ],
      );
    }

    if (state.farmsError != null) {
      return _ErrorRetry(
        message: '取得に失敗しました',
        onRetry: state.reloadFarms,
      );
    }

    return Column(
      children: state.farms.map((farm) {
        final latest = farm.latestResult;
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FarmResultsDatesScreen(farmId: farm.farmId)),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    farm.farmName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (latest == null) ...[
                    const Text('結果なし'),
                  ] else ...[
                    Text(formatYyyyMmDdSlash(latest.latestMeasurementDate)),
                    const SizedBox(height: 6),
                    Text(
                      'CEC 平均 ${fmt.format1OrDash(latest.cecStats.avg)} / ${fmt.format1OrDash(latest.cecStats.min)}–${fmt.format1OrDash(latest.cecStats.max)}',
                    ),
                    const SizedBox(height: 6),
                    Text(latest.summaryText),
                    const SizedBox(height: 6),
                    Text('測定点 ${latest.cecStats.countPoints}点'),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => onRetry(),
            child: const Text('再読み込み'),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double height;
  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}