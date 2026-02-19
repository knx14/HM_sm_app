import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client_factory.dart';
import '../../data/results_repository.dart';
import '../../domain/farm_result_date.dart';

class FarmResultsDatesNotifier extends ChangeNotifier {
  final int farmId;
  final ResultsRepository _repo = ResultsRepository(buildApiClient());

  FarmResultsDatesNotifier({required this.farmId});

  bool _isLoading = false;
  String? _error;
  List<FarmResultDateItem> _items = const [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<FarmResultDateItem> get items => _items;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _repo.fetchFarmResultDates(farmId);
    } catch (e) {
      _error = '取得に失敗しました';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

