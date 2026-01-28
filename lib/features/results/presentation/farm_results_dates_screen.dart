import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../utils/result_formatters.dart' as fmt;
import 'providers/farm_results_dates_notifier.dart';
import 'result_map_screen.dart';

class FarmResultsDatesScreen extends StatelessWidget {
  final int farmId;
  const FarmResultsDatesScreen({super.key, required this.farmId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FarmResultsDatesNotifier(farmId: farmId)..load(),
      child: const _FarmResultsDatesView(),
    );
  }
}

class _FarmResultsDatesView extends StatelessWidget {
  const _FarmResultsDatesView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('測定日'),
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
      ),
      body: Consumer<FarmResultsDatesNotifier>(
        builder: (context, state, child) {
          if (state.isLoading && state.items.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null && state.items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('取得に失敗しました'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: state.load,
                      child: const Text('再読み込み'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: state.load,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                final item = state.items[index];
                final stats = item.cecStats;
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
                      final farmId = context.read<FarmResultsDatesNotifier>().farmId;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ResultMapScreen(
                            farmId: farmId,
                            date: item.measurementDate,
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
                              Expanded(child: Text(fmt.formatYyyyMmDdSlash(item.measurementDate))),
                              Text('測定点 ${stats.countPoints}点'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'CEC 平均 ${fmt.format1OrDash(stats.avg)} / ${fmt.format1OrDash(stats.min)}–${fmt.format1OrDash(stats.max)}',
                          ),
                          const SizedBox(height: 8),
                          Text(item.summaryText),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

