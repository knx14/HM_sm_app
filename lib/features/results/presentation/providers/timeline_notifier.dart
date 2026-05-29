import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client_factory.dart';
import '../../data/results_repository.dart';
import '../../domain/timeline_item.dart';

class TimelineNotifier extends ChangeNotifier {
  TimelineNotifier({required this.farmId});

  final int farmId;
  final ResultsRepository _repo = ResultsRepository(buildApiClient());

  List<TimelineItem> _items = const [];
  bool _isLoading = false;
  String? _error;

  List<TimelineItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadInitial() => _load();
  Future<void> reload() => _load();

  Future<void> _load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _repo.fetchFarmTimeline(farmId);
    } catch (e) {
      _error = '取得に失敗しました';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
