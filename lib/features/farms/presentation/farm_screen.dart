import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/api/api_client_factory.dart';
import '../../../utils/polygon_area.dart';
import '../../../utils/static_maps.dart';
import '../../results/data/results_repository.dart';
import '../../results/domain/latest_results.dart';
import '../../results/utils/result_formatters.dart' as fmt;
import '../data/farm_repository.dart';
import '../domain/farm.dart';
import 'farm_detail_screen.dart';
import 'farm_form_screen.dart';

class FarmScreen extends StatefulWidget {
  const FarmScreen({super.key});

  @override
  State<FarmScreen> createState() => _FarmScreenState();
}

class _FarmScreenState extends State<FarmScreen> {
  late final FarmRepository _farmRepository;
  late final ResultsRepository _resultsRepository;
  final _searchController = TextEditingController();

  List<Farm> _farms = [];
  Map<int, FarmWithLatestResult> _latestByFarmId = const {};
  Map<int, _FarmCardAverages> _averagesByFarmId = const {};
  bool _isLoading = false;
  String? _error;
  String? _googleMapsApiKey;
  String _query = '';

  static const double _cardRadius = 18;
  static const MethodChannel _channel = MethodChannel(
    'com.henrymonitor.testapp/google_maps_api_key',
  );

  @override
  void initState() {
    super.initState();
    final apiClient = buildApiClient();
    _farmRepository = FarmRepository(apiClient);
    _resultsRepository = ResultsRepository(apiClient);
    _initializeData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _loadGoogleMapsApiKey();
    await _loadFarms();
  }

  Future<void> _loadGoogleMapsApiKey() async {
    try {
      final apiKey = await _channel.invokeMethod<String>('getGoogleMapsApiKey');
      if (!mounted) return;
      if (apiKey != null && apiKey.isNotEmpty) {
        setState(() => _googleMapsApiKey = apiKey);
        return;
      }
      if (kDebugMode) {
        await _loadApiKeyFromLocalProperties();
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('Google Maps APIキーの取得に失敗: ${e.message}');
        await _loadApiKeyFromLocalProperties();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Google Maps APIキーの取得に失敗: $e');
        await _loadApiKeyFromLocalProperties();
      }
    }
  }

  Future<void> _loadApiKeyFromLocalProperties() async {
    try {
      final file = File('android/local.properties');
      if (!await file.exists()) return;
      final lines = (await file.readAsString()).split('\n');
      for (final line in lines) {
        if (!line.startsWith('GOOGLE_MAPS_API_KEY=')) continue;
        final apiKey = line.substring('GOOGLE_MAPS_API_KEY='.length).trim();
        if (apiKey.isEmpty || !mounted) return;
        setState(() => _googleMapsApiKey = apiKey);
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('local.propertiesからの読み込みに失敗: $e');
      }
    }
  }

  Future<void> _loadFarms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _farmRepository.getFarms(),
        _resultsRepository.fetchFarmsWithLatestResult(),
      ]);
      final farms = results[0] as List<Farm>;
      final latest = results[1] as List<FarmWithLatestResult>;
      final latestByFarmId = {for (final item in latest) item.farmId: item};
      final sortedFarms = _sortFarmsByLatestResult(farms, latestByFarmId);
      final averagesByFarmId = await _loadLatestAverages(latestByFarmId.values);
      if (!mounted) return;
      setState(() {
        _farms = sortedFarms;
        _latestByFarmId = latestByFarmId;
        _averagesByFarmId = averagesByFarmId;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Farm> _sortFarmsByLatestResult(
    List<Farm> farms,
    Map<int, FarmWithLatestResult> latestByFarmId,
  ) {
    final originalIndexByFarmId = <int, int>{
      for (var i = 0; i < farms.length; i++) farms[i].id: i,
    };
    return List<Farm>.from(farms)..sort((a, b) {
      final aDate = latestByFarmId[a.id]?.latestResult?.latestMeasurementDate;
      final bDate = latestByFarmId[b.id]?.latestResult?.latestMeasurementDate;
      if (aDate == null && bDate == null) {
        return originalIndexByFarmId[a.id]!.compareTo(
          originalIndexByFarmId[b.id]!,
        );
      }
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      final dateOrder = bDate.compareTo(aDate);
      if (dateOrder != 0) return dateOrder;
      return originalIndexByFarmId[a.id]!.compareTo(
        originalIndexByFarmId[b.id]!,
      );
    });
  }

  Future<Map<int, _FarmCardAverages>> _loadLatestAverages(
    Iterable<FarmWithLatestResult> latestItems,
  ) async {
    final entries = await Future.wait(
      latestItems.where((item) => item.latestResult != null).map((item) async {
        try {
          final map = await _resultsRepository.fetchFarmResultMap(
            farmId: item.farmId,
            dateIso: _toIsoDate(item.latestResult!.latestMeasurementDate),
          );
          return MapEntry(
            item.farmId,
            _FarmCardAverages.fromPoints(map.points),
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('最新測定平均値の取得に失敗しました: farmId=${item.farmId}, error=$e');
          }
          return null;
        }
      }),
    );

    return {
      for (final entry in entries.whereType<MapEntry<int, _FarmCardAverages>>())
        entry.key: entry.value,
    };
  }

  static String _toIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  List<Farm> get _filteredFarms {
    final q = _query.trim();
    if (q.isEmpty) return _farms;
    return _farms.where((farm) {
      return farm.farmName.contains(q) ||
          (farm.cropType?.contains(q) ?? false) ||
          (farm.cultivationMethod?.contains(q) ?? false);
    }).toList();
  }

  List<LatLng> _boundaryPolygonToLatLng(
    List<Map<String, double>> boundaryPolygon,
  ) {
    return boundaryPolygon
        .map((point) => LatLng(point['lat']!, point['lng']!))
        .toList();
  }

  Future<void> _openCreateForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FarmFormScreen(farmRepository: _farmRepository),
      ),
    );
    if (result == true) {
      await _loadFarms();
    }
  }

  Future<void> _openEditForm(Farm farm) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FarmFormScreen(farmRepository: _farmRepository, farm: farm),
      ),
    );
    if (result == true) {
      await _loadFarms();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filteredFarms = _filteredFarms;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          '圃場',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '圃場名・作物名で検索',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(child: _buildBody(context, filteredFarms)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: FilledButton.icon(
            onPressed: _openCreateForm,
            icon: const Icon(Icons.add),
            label: const Text('新規圃場を登録'),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<Farm> filteredFarms) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading && _farms.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: colorScheme.primary),
      );
    }

    if (_error != null && _farms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('エラーが発生しました', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _loadFarms, child: const Text('再試行')),
            ],
          ),
        ),
      );
    }

    if (_farms.isEmpty) {
      return const Center(child: Text('登録されている圃場がありません'));
    }

    if (filteredFarms.isEmpty) {
      return const Center(child: Text('検索条件に一致する圃場がありません'));
    }

    return RefreshIndicator(
      onRefresh: _loadFarms,
      color: colorScheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: filteredFarms.length,
        itemBuilder: (context, index) {
          final farm = filteredFarms[index];
          return _FarmCard(
            farm: farm,
            latest: _latestByFarmId[farm.id]?.latestResult,
            averages: _averagesByFarmId[farm.id],
            boundaryPoints: _boundaryPolygonToLatLng(farm.boundaryPolygon),
            googleMapsApiKey: _googleMapsApiKey,
            cardRadius: _cardRadius,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FarmDetailScreen(farm: farm)),
              );
            },
            onEdit: () => _openEditForm(farm),
          );
        },
      ),
    );
  }
}

class _FarmCard extends StatelessWidget {
  const _FarmCard({
    required this.farm,
    required this.latest,
    required this.averages,
    required this.boundaryPoints,
    required this.googleMapsApiKey,
    required this.cardRadius,
    required this.onTap,
    required this.onEdit,
  });

  final Farm farm;
  final FarmLatestResultSummary? latest;
  final _FarmCardAverages? averages;
  final List<LatLng> boundaryPoints;
  final String? googleMapsApiKey;
  final double cardRadius;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final area = boundaryPoints.length >= 3
        ? calculatePolygonArea(boundaryPoints)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cardRadius),
        side: BorderSide(color: colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MapThumbnail(
                farm: farm,
                boundaryPoints: boundaryPoints,
                googleMapsApiKey: googleMapsApiKey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            farm.farmName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: '圃場を編集',
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                      ],
                    ),
                    Text(
                      [
                        farm.cropType ?? farm.cultivationMethod ?? '作物未設定',
                        if (area > 0) formatArea(area),
                      ].join(' / '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _LatestLine(latest: latest),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _ValueChip(
                          label: 'CEC',
                          value: averages?.cec ?? latest?.cecStats.avg,
                        ),
                        const SizedBox(width: 8),
                        _ValueChip(label: 'CaO', value: averages?.cao),
                        const SizedBox(width: 8),
                        _ValueChip(label: 'K2O', value: averages?.k2o),
                        const SizedBox(width: 8),
                        _ValueChip(label: 'MgO', value: averages?.mgo),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _FarmCardAverages {
  const _FarmCardAverages({
    required this.cec,
    required this.cao,
    required this.k2o,
    required this.mgo,
  });

  final double? cec;
  final double? cao;
  final double? k2o;
  final double? mgo;

  factory _FarmCardAverages.fromPoints(Iterable<dynamic> points) {
    return _FarmCardAverages(
      cec: _average(points, 'CEC'),
      cao: _average(points, 'CaO'),
      k2o: _average(points, 'K2O'),
      mgo: _average(points, 'MgO'),
    );
  }

  static double? _average(Iterable<dynamic> points, String parameter) {
    final values = <double>[];
    for (final point in points) {
      for (final value in point.values) {
        if (value.parameter == parameter && value.value != null) {
          values.add(value.value!);
        }
      }
    }
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }
}

class _LatestLine extends StatelessWidget {
  const _LatestLine({required this.latest});

  final FarmLatestResultSummary? latest;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (latest == null) {
      return Text(
        '最終測定なし',
        style: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.62),
          fontSize: 12,
        ),
      );
    }
    return Text(
      '最終測定 ${fmt.formatYyyyMmDdSlash(latest!.latestMeasurementDate)} / ${latest!.cecStats.countPoints}点',
      style: const TextStyle(
        color: Color(0xFF4A8459),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurface.withValues(alpha: 0.62),
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value == null ? '--' : value!.toStringAsFixed(1),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapThumbnail extends StatelessWidget {
  const _MapThumbnail({
    required this.farm,
    required this.boundaryPoints,
    required this.googleMapsApiKey,
  });

  final Farm farm;
  final List<LatLng> boundaryPoints;
  final String? googleMapsApiKey;

  @override
  Widget build(BuildContext context) {
    const width = 92.0;
    const height = 92.0;
    const radius = 14.0;
    final colorScheme = Theme.of(context).colorScheme;

    if (googleMapsApiKey == null ||
        googleMapsApiKey!.isEmpty ||
        boundaryPoints.isEmpty) {
      return _placeholder(colorScheme, width, height, radius);
    }

    final cacheBuster =
        '${farm.id}_${farm.updatedAt?.millisecondsSinceEpoch ?? farm.createdAt?.millisecondsSinceEpoch ?? 0}';
    final mapUrl = buildStaticMapUrl(
      boundaryPoints: boundaryPoints,
      apiKey: googleMapsApiKey!,
      width: (width * 2).toInt(),
      height: (height * 2).toInt(),
      cacheBuster: cacheBuster,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: CachedNetworkImage(
          imageUrl: mapUrl,
          fit: BoxFit.cover,
          memCacheWidth: (width * 2).toInt(),
          memCacheHeight: (height * 2).toInt(),
          placeholder: (_, __) => _skeleton(colorScheme, width, height),
          errorWidget: (_, __, ___) =>
              _placeholder(colorScheme, width, height, radius),
        ),
      ),
    );
  }

  Widget _skeleton(ColorScheme colorScheme, double width, double height) {
    return Container(
      width: width,
      height: height,
      color: colorScheme.surfaceContainerHighest,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _placeholder(
    ColorScheme colorScheme,
    double width,
    double height,
    double radius,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.18)),
      ),
      alignment: Alignment.center,
      child: Text(
        farm.farmName.isEmpty ? 'Map' : farm.farmName.characters.first,
        style: TextStyle(
          color: colorScheme.onSurface.withValues(alpha: 0.48),
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
