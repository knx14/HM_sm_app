import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client_factory.dart';
import '../../data/results_repository.dart';
import '../../domain/result_parameter.dart';
import '../../domain/timeline_item.dart';
import '../../domain/timeseries_result.dart';

enum TimeseriesRange { all, oneYear, oneMonth }

extension TimeseriesRangeLabel on TimeseriesRange {
  String get label => switch (this) {
    TimeseriesRange.all => 'すべて',
    TimeseriesRange.oneYear => '1年間',
    TimeseriesRange.oneMonth => '1ヶ月',
  };
}

class TimeseriesNotifier extends ChangeNotifier {
  TimeseriesNotifier({required this.farmId});

  static const int firstSelectableYear = 2025;

  final int farmId;
  final ResultsRepository _repo = ResultsRepository(buildApiClient());

  ResultParameter _parameter = ResultParameter.cec;
  TimeseriesRange _selectedRange = TimeseriesRange.all;
  int _selectedYear = _currentSelectableYear();
  DateTime _selectedMonth = _currentSelectableMonth();
  TimeseriesResult? _data;
  bool _isLoading = false;
  String? _error;

  ResultParameter get parameter => _parameter;
  TimeseriesRange get selectedRange => _selectedRange;
  int get selectedYear => _selectedYear;
  DateTime get selectedMonth => _selectedMonth;
  List<int> get availableYears {
    final latestYear = _currentSelectableYear();
    return [
      for (var year = firstSelectableYear; year <= latestYear; year++) year,
    ];
  }

  List<DateTime> get availableMonths {
    final latest = _currentSelectableMonth();
    final months = <DateTime>[];
    var cursor = DateTime(firstSelectableYear);
    while (!cursor.isAfter(latest)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return months;
  }

  String get selectedPeriodLabel => switch (_selectedRange) {
    TimeseriesRange.all => 'すべて',
    TimeseriesRange.oneYear => '$_selectedYear年',
    TimeseriesRange.oneMonth =>
      '${_selectedMonth.year}年${_selectedMonth.month}月',
  };

  TimeseriesResult? get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<TimeseriesPoint> get filteredPoints =>
      _filterBySelectedRange(_data?.points ?? const <TimeseriesPoint>[]);
  List<WorkLogMark> get filteredWorkLogs =>
      _filterBySelectedRange(_data?.workLogs ?? const <WorkLogMark>[]);
  TimeseriesResult? get filteredData =>
      _data?.copyWith(points: filteredPoints, workLogs: filteredWorkLogs);

  Future<void> loadInitial() => _load();

  Future<void> setParameter(ResultParameter parameter) async {
    if (_parameter == parameter) return;
    _parameter = parameter;
    notifyListeners();
    await _load();
  }

  void setRange(TimeseriesRange range) {
    if (_selectedRange == range) return;
    _selectedRange = range;
    notifyListeners();
  }

  void setSelectedYear(int year) {
    if (_selectedYear == year || !availableYears.contains(year)) return;
    _selectedYear = year;
    notifyListeners();
  }

  void setSelectedMonth(DateTime month) {
    final normalized = DateTime(month.year, month.month);
    if (_isSameMonth(_selectedMonth, normalized) ||
        !availableMonths.any(
          (available) => _isSameMonth(available, normalized),
        )) {
      return;
    }
    _selectedMonth = normalized;
    notifyListeners();
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

  List<T> _filterBySelectedRange<T>(List<T> items) {
    if (_selectedRange == TimeseriesRange.all) return items;

    return items
        .where((item) {
          final date = switch (item) {
            TimeseriesPoint point => point.date,
            WorkLogMark mark => mark.date,
            _ => null,
          };
          if (date == null) return false;
          final parsed = DateTime.tryParse(
            date.length >= 10 ? date.substring(0, 10) : date,
          );
          if (parsed == null) return false;
          return switch (_selectedRange) {
            TimeseriesRange.all => true,
            TimeseriesRange.oneYear => parsed.year == _selectedYear,
            TimeseriesRange.oneMonth =>
              parsed.year == _selectedMonth.year &&
                  parsed.month == _selectedMonth.month,
          };
        })
        .toList(growable: false);
  }

  static int _currentSelectableYear() {
    final currentYear = DateTime.now().year;
    return currentYear < firstSelectableYear
        ? firstSelectableYear
        : currentYear;
  }

  static DateTime _currentSelectableMonth() {
    final now = DateTime.now();
    if (now.year < firstSelectableYear) {
      return DateTime(firstSelectableYear);
    }
    return DateTime(now.year, now.month);
  }

  static bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }
}
