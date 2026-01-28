import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client_factory.dart';
import '../../data/results_repository.dart';
import '../../domain/latest_results.dart';

class ResultsTopNotifier extends ChangeNotifier {
  final ResultsRepository _repo = ResultsRepository(buildApiClient());

  bool _isLoadingFeed = false;
  String? _feedError;
  List<LatestResultFeedItem> _feed = const [];

  bool _isLoadingFarms = false;
  String? _farmsError;
  List<FarmWithLatestResult> _farms = const [];

  bool get isLoadingFeed => _isLoadingFeed;
  String? get feedError => _feedError;
  List<LatestResultFeedItem> get feed => _feed;

  bool get isLoadingFarms => _isLoadingFarms;
  String? get farmsError => _farmsError;
  List<FarmWithLatestResult> get farms => _farms;

  Future<void> load() async {
    _feedError = null;
    _farmsError = null;
    _isLoadingFeed = true;
    _isLoadingFarms = true;
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

