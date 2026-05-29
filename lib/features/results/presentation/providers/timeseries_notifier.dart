import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client_factory.dart';
import '../../data/results_repository.dart';
import '../../domain/result_parameter.dart';
import '../../domain/timeseries_result.dart';

class TimeseriesNotifier extends ChangeNotifier {
  TimeseriesNotifier({required this.farmId});

  final int farmId;
  final ResultsRepository _repo = ResultsRepository(buildApiClient());

  ResultParameter _parameter = ResultParameter.cec;
  TimeseriesResult? _data;
  bool _isLoading = false;
  String? _error;

  ResultParameter get parameter => _parameter;
  TimeseriesResult? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadInitial() => _load();

  Future<void> setParameter(ResultParameter parameter) async {
    if (_parameter == parameter) return;
    _parameter = parameter;
    notifyListeners();
    await _load();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _data = await _repo.fetchFarmTimeseries(
        farmId: farmId,
        parameter: _parameter.apiName,
      );
    } catch (e) {
      _error = '取得に失敗しました';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
