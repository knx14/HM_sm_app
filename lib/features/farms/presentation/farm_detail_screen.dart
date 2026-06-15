import 'package:flutter/material.dart';

import '../../../core/api/api_client_factory.dart';
import '../../results/data/results_repository.dart';
import '../../results/domain/farm_result_date.dart';
import '../domain/farm.dart';
import 'tabs/farm_map_tab.dart';
import 'tabs/farm_timeline_tab.dart';
import 'tabs/farm_timeseries_tab.dart';

class FarmDetailScreen extends StatefulWidget {
  const FarmDetailScreen({super.key, required this.farm});

  final Farm farm;

  @override
  State<FarmDetailScreen> createState() => _FarmDetailScreenState();
}

class _FarmDetailScreenState extends State<FarmDetailScreen> {
  late final ResultsRepository _resultsRepository;
  List<FarmResultDateItem> _dates = const [];
  DateTime? _selectedDate;
  bool _isLoadingDates = true;
  String? _datesError;

  @override
  void initState() {
    super.initState();
    _resultsRepository = ResultsRepository(buildApiClient());
    _loadDates();
  }

  Future<void> _loadDates() async {
    setState(() {
      _isLoadingDates = true;
      _datesError = null;
    });
    try {
      final dates = await _resultsRepository.fetchFarmResultDates(
        widget.farm.id,
      );
      if (!mounted) return;
      setState(() {
        _dates = dates;
        _selectedDate = dates.isEmpty ? null : dates.first.measurementDate;
        _isLoadingDates = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _datesError = e.toString();
        _isLoadingDates = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.farm.farmName),
          backgroundColor: const Color(0xFF2E5C39),
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'マップ'),
              Tab(text: '時系列'),
              Tab(text: 'タイムライン'),
            ],
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _FarmHeader(farm: widget.farm),
              if (_datesError != null)
                Material(
                  color: colorScheme.errorContainer,
                  child: ListTile(
                    dense: true,
                    title: Text(
                      '測定日一覧を取得できませんでした',
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                    trailing: TextButton(
                      onPressed: _loadDates,
                      child: const Text('再試行'),
                    ),
                  ),
                ),
              Expanded(
                child: TabBarView(
                  children: [
                    FarmMapTab(
                      key: ValueKey(
                        '${widget.farm.id}_${_selectedDate?.toIso8601String() ?? 'none'}',
                      ),
                      farm: widget.farm,
                      dates: _dates,
                      selectedDate: _selectedDate,
                      isLoadingDates: _isLoadingDates,
                      onRefreshDates: _loadDates,
                      onDateSelected: (date) =>
                          setState(() => _selectedDate = date),
                    ),
                    FarmTimeseriesTab(farmId: widget.farm.id),
                    FarmTimelineTab(farmId: widget.farm.id),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FarmHeader extends StatelessWidget {
  const _FarmHeader({required this.farm});

  final Farm farm;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.10),
          ),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _InfoChip(icon: Icons.grass, label: farm.cropType ?? '作物未設定'),
          _InfoChip(
            icon: Icons.eco_outlined,
            label: farm.cultivationMethod ?? '栽培方法未設定',
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: colorScheme.onSurface.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
