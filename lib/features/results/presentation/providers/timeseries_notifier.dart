import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client_factory.dart';
import '../../data/results_repository.dart';
import '../../domain/result_parameter.dart';
import '../../domain/timeline_item.dart';
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
      final results = await Future.wait([
        _repo.fetchFarmTimeseries(
          farmId: farmId,
          parameter: _parameter.apiName,
        ),
        _repo.fetchFarmTimeline(farmId),
      ]);
      final timeseries = results[0] as TimeseriesResult;
      final timelineItems = results[1] as List<TimelineItem>;
      _data = timeseries.copyWith(
        workLogs: _mergeWorkLogs(
          timeseries.workLogs,
          timelineItems.whereType<WorkLogTimelineItem>(),
        ),
      );
    } catch (e) {
      _error = '取得に失敗しました';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<WorkLogMark> _mergeWorkLogs(
    List<WorkLogMark> apiMarks,
    Iterable<WorkLogTimelineItem> timelineItems,
  ) {
    final byKey = <String, WorkLogMark>{
      for (final mark in apiMarks) _workLogKey(mark): mark,
    };
    for (final item in timelineItems) {
      final mark = WorkLogMark(
        date: item.date,
        workType: item.workType,
        title: item.title,
        detail: item.detail,
        amountValue: item.amountValue,
        amountUnit: item.amountUnit,
      );
      byKey.putIfAbsent(_workLogKey(mark), () => mark);
    }
    final merged = byKey.values.toList(growable: false);
    return List<WorkLogMark>.from(merged)
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  String _workLogKey(WorkLogMark mark) {
    return [
      mark.date.length >= 10 ? mark.date.substring(0, 10) : mark.date,
      mark.workType,
      mark.title ?? '',
      mark.detail ?? '',
      mark.amountValue?.toString() ?? '',
      mark.amountUnit ?? '',
    ].join('|');
  }
}
