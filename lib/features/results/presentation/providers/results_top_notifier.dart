import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client_factory.dart';
import '../../data/results_repository.dart';
import '../../domain/farm_result_date.dart';
import '../../domain/latest_results.dart';

class ResultsTopNotifier extends ChangeNotifier {
  final ResultsRepository _repo = ResultsRepository(buildApiClient());

  bool _isLoadingFeed = false;
  String? _feedError;
  List<LatestResultFeedItem> _feed = const [];

  bool _isLoadingFarms = false;
  String? _farmsError;
  List<FarmWithLatestResult> _farms = const [];

  // Farm recent measurement dates cache (latest first; max 4)
  final Map<int, List<DateTime>> _farmRecentDates = {};
  final Set<int> _farmRecentDatesLoading = {};
  final Map<int, String?> _farmRecentDatesError = {};

  bool get isLoadingFeed => _isLoadingFeed;
  String? get feedError => _feedError;
  List<LatestResultFeedItem> get feed => _feed;

  bool get isLoadingFarms => _isLoadingFarms;
  String? get farmsError => _farmsError;
  List<FarmWithLatestResult> get farms => _farms;

  List<DateTime>? recentDatesForFarm(int farmId) => _farmRecentDates[farmId];
  bool isRecentDatesLoading(int farmId) => _farmRecentDatesLoading.contains(farmId);
  String? recentDatesError(int farmId) => _farmRecentDatesError[farmId];

  Future<void> ensureRecentDatesLoaded(int farmId) async {
    if (_farmRecentDates.containsKey(farmId)) return;
    if (_farmRecentDatesLoading.contains(farmId)) return;

    _farmRecentDatesLoading.add(farmId);
    notifyListeners();

    try {
      final items = await _repo.fetchFarmResultDates(farmId);
      final sorted = List<FarmResultDateItem>.from(items)
        ..sort((a, b) => b.measurementDate.compareTo(a.measurementDate));
      _farmRecentDates[farmId] =
          sorted.map((e) => e.measurementDate).take(4).toList(growable: false);
      _farmRecentDatesError.remove(farmId);
    } catch (e) {
      _farmRecentDatesError[farmId] = '取得に失敗しました';
    } finally {
      _farmRecentDatesLoading.remove(farmId);
      notifyListeners();
    }
  }

  Future<void> load() async {
    _feedError = null;
    _farmsError = null;
    _isLoadingFeed = true;
    _isLoadingFarms = true;
    _farmRecentDates.clear();
    _farmRecentDatesLoading.clear();
    _farmRecentDatesError.clear();
    notifyListeners();

    await Future.wait([
      () async {
        try {
          _feed = await _repo.fetchLatestResults();
        } catch (e) {
          _feedError = '取得に失敗しました';
        } finally {
          _isLoadingFeed = false;
          notifyListeners();
        }
      }(),
      () async {
        try {
          _farms = await _repo.fetchFarmsWithLatestResult();
        } catch (e) {
          _farmsError = '取得に失敗しました';
        } finally {
          _isLoadingFarms = false;
          notifyListeners();
        }
      }(),
    ]);
  }

  Future<void> reloadFeed() async {
    _feedError = null;
    _isLoadingFeed = true;
    notifyListeners();
    try {
      _feed = await _repo.fetchLatestResults();
    } catch (e) {
      _feedError = '取得に失敗しました';
    } finally {
      _isLoadingFeed = false;
      notifyListeners();
    }
  }

  Future<void> reloadFarms() async {
    _farmsError = null;
    _isLoadingFarms = true;
    _farmRecentDates.clear();
    _farmRecentDatesLoading.clear();
    _farmRecentDatesError.clear();
    notifyListeners();
    try {
      _farms = await _repo.fetchFarmsWithLatestResult();
    } catch (e) {
      _farmsError = '取得に失敗しました';
    } finally {
      _isLoadingFarms = false;
      notifyListeners();
    }
  }
}

