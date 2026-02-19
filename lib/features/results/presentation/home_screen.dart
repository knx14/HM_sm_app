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

  static const double _cardRadius = 18;
  static const EdgeInsets _pagePadding = EdgeInsets.fromLTRB(16, 12, 16, 24);

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
              padding: _pagePadding,
              children: [
                _sectionTitle(context, title: '最新結果', icon: Icons.insights_rounded),
                const SizedBox(height: 12),
                _buildLatestFeedSection(context, state),
                const SizedBox(height: 24),
                _sectionTitle(context, title: '圃場', icon: Icons.map_outlined),
                const SizedBox(height: 12),
                _buildFarmShortcutsSection(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(
    BuildContext context, {
    required String title,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.75)),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
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
        final spread = (stats.max != null && stats.min != null) ? (stats.max! - stats.min!) : null;
        final spreadText = fmt.format1OrDash(spread);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: cs.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_cardRadius),
            side: BorderSide(color: cs.outline.withValues(alpha: 0.12)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(_cardRadius),
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
                      _Tag(
                        icon: Icons.event_outlined,
                        text: dateText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // チップは2段になりやすく高さ固定カードだと溢れるため、横スクロールで1段に固定
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: [
                        _MetricChip(label: 'ばらつき', value: spreadText),
                        const SizedBox(width: 8),
                        _MetricChip(label: '点数', value: '${stats.countPoints}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.summaryText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.85)),
                  ),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final crossAxisCount = w >= 900
            ? 3
            : w >= 560
                ? 2
                : 1;
        // 高さが端末幅に引っ張られるとオーバーフローしやすいので、カード高さを固定する。
        final mainAxisExtent = crossAxisCount == 1 ? 156.0 : 176.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.farms.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: mainAxisExtent,
          ),
          itemBuilder: (context, index) {
            final farm = state.farms[index];
            final latest = farm.latestResult;

            // 結果あり圃場は「最新の測定日（最大4件）」を表示するため、必要時に遅延ロードする。
            final hasDates = state.recentDatesForFarm(farm.farmId) != null;
            final isDatesLoading = state.isRecentDatesLoading(farm.farmId);
            final datesError = state.recentDatesError(farm.farmId);
            if (latest != null &&
                !hasDates &&
                !isDatesLoading &&
                datesError == null) {
              Future.microtask(() => state.ensureRecentDatesLoaded(farm.farmId));
            }

            return Card(
              elevation: 0,
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(_cardRadius),
                side: BorderSide(color: cs.outline.withValues(alpha: 0.12)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(_cardRadius),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => FarmResultsDatesScreen(farmId: farm.farmId)),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              farm.farmName,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (latest == null) ...[
                        Text(
                          '結果なし',
                          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75)),
                        ),
                        const Spacer(),
                        _Tag(icon: Icons.insights_outlined, text: '結果を見る'),
                      ] else ...[
                        const SizedBox(height: 2),
                        _RecentDatesGrid(
                          dates: state.recentDatesForFarm(farm.farmId),
                          isLoading: isDatesLoading,
                          error: datesError,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _RecentDatesGrid extends StatelessWidget {
  final List<DateTime>? dates; // latest first
  final bool isLoading;
  final String? error;

  const _RecentDatesGrid({
    required this.dates,
    required this.isLoading,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (error != null && (dates == null || dates!.isEmpty)) {
      return Text(
        '測定日を取得できません',
        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75)),
      );
    }

    final effective = (dates ?? const <DateTime>[]);
    if (effective.isEmpty && isLoading) {
      return _DatesSkeleton();
    }
    if (effective.isEmpty) {
      return Text(
        '測定日なし',
        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.75)),
      );
    }

    final labels = effective.take(4).map((d) => formatYyyyMmDdSlash(d)).toList(growable: true);
    while (labels.length < 4) {
      labels.add('—');
    }

    Widget cell(String text, {bool primary = false}) {
      return _DateChip(
        text: text,
        primary: primary,
        muted: text == '—',
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cell(labels[0], primary: true)),
            const SizedBox(width: 8),
            Expanded(child: cell(labels[1])),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: cell(labels[2])),
            const SizedBox(width: 8),
            Expanded(child: cell(labels[3])),
          ],
        ),
      ],
    );
  }
}

class _DatesSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget box() {
      return Container(
        height: 28,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: box()),
            const SizedBox(width: 8),
            Expanded(child: box()),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: box()),
            const SizedBox(width: 8),
            Expanded(child: box()),
          ],
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  final String text;
  final bool primary;
  final bool muted;

  const _DateChip({
    required this.text,
    this.primary = false,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bg = primary ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.55);
    final fg = primary ? cs.onPrimaryContainer : cs.onSurface.withValues(alpha: muted ? 0.55 : 0.85);

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withValues(alpha: 0.10)),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetricChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withValues(alpha: 0.10)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          '$label $value',
          maxLines: 1,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outline.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.onSurface.withValues(alpha: 0.75)),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
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