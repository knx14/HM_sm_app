import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/api/api_client_factory.dart';
import '../../data/results_repository.dart';
import '../../domain/result_map.dart';
import '../../domain/result_map_diff.dart';
import '../../domain/result_parameter.dart';
import '../../utils/result_color_scale.dart';
import '../../utils/result_formatters.dart' as fmt;
import '../../utils/result_marker_icon_factory.dart';
import '../../utils/result_stats.dart';
import '../../utils/result_value_extractors.dart';

enum ResultMapMode { normal, diff }

class ResultPointMarkerVm {
  final int pointId;
  final LatLng position;
  final BitmapDescriptor icon;
  final bool isMissing;

  const ResultPointMarkerVm({
    required this.pointId,
    required this.position,
    required this.icon,
    required this.isMissing,
  });
}

class ResultMapNotifier extends ChangeNotifier {
  final int farmId;
  final DateTime date;

  final ResultsRepository _repo = ResultsRepository(buildApiClient());

  ResultMapNotifier({
    required this.farmId,
    required this.date,
  });

  ResultParameter _parameter = ResultParameter.cec;
  ResultMapMode _mode = ResultMapMode.normal;

  bool _isLoading = false;
  bool _isTogglingCompare = false;
  String? _error;

  ResultMapResponse? _normal;
  ResultMapDiffResponse? _diff;

  List<ResultPointMarkerVm> _markerVms = const [];
  bool _isUpdatingMarkers = false;

  List<LatLng> _boundaryPolygon = const [];

  ResultParameter get parameter => _parameter;
  ResultMapMode get mode => _mode;
  bool get isCompare => _mode == ResultMapMode.diff;
  bool get isLoading => _isLoading;
  bool get isTogglingCompare => _isTogglingCompare;
  bool get isUpdatingMarkers => _isUpdatingMarkers;
  String? get error => _error;

  ResultMapResponse? get normalData => _normal;
  ResultMapDiffResponse? get diffData => _diff;

  String get farmName {
    if (_mode == ResultMapMode.diff) return _diff?.farm.farmName ?? '';
    return _normal?.farm.farmName ?? '';
  }

  List<LatLng> get boundaryPolygon => _boundaryPolygon;
  List<ResultPointMarkerVm> get markerVms => _markerVms;

  DateTime? get previousMeasurementDate => _diff?.previousMeasurementDate;

  Future<void> loadInitial() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _fetchNormal();
      await _rebuildMarkers();
    } catch (e) {
      _error = '取得に失敗しました';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchNormal() async {
    final dateIso = _toIsoDate(date);
    _normal = await _repo.fetchFarmResultMap(farmId: farmId, dateIso: dateIso);
    _boundaryPolygon = _normal!.farm.boundaryPolygon
        .map((p) => LatLng(p.lat, p.lng))
        .toList(growable: false);
  }

  Future<bool> enableCompare() async {
    _isTogglingCompare = true;
    notifyListeners();
    try {
      final dateIso = _toIsoDate(date);
      _diff = await _repo.fetchFarmResultMapDiff(farmId: farmId, dateIso: dateIso);
      _mode = ResultMapMode.diff;
      await _rebuildMarkers();
      return true;
    } on PreviousNotFoundException {
      return false;
    } finally {
      _isTogglingCompare = false;
      notifyListeners();
    }
  }

  Future<void> disableCompare() async {
    _mode = ResultMapMode.normal;
    if (_normal == null) {
      _isLoading = true;
      notifyListeners();
      try {
        await _fetchNormal();
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
    await _rebuildMarkers();
    notifyListeners();
  }

  Future<void> setParameter(ResultParameter p) async {
    if (_parameter == p) return;
    _parameter = p;
    notifyListeners();
    await _rebuildMarkers();
    notifyListeners();
  }

  NumericStats get currentStats {
    if (_mode == ResultMapMode.normal) {
      final pts = _normal?.points ?? const <ResultPoint>[];
      final values = pts.map((pt) => findValueByParameter(pt.values, _parameter.apiName));
      return computeStats(values);
    }
    final pts = _diff?.points ?? const <ResultDiffPoint>[];
    final diffs = pts.map((pt) => findDiffValueByParameter(pt.diffValues, _parameter.apiName));
    final delta = computeDeltaMax(diffs);
    return NumericStats(avg: delta, min: -delta, max: delta);
  }

  double get deltaMax {
    if (_mode != ResultMapMode.diff) return 0.0;
    final pts = _diff?.points ?? const <ResultDiffPoint>[];
    final diffs = pts.map((pt) => findDiffValueByParameter(pt.diffValues, _parameter.apiName));
    return computeDeltaMax(diffs);
  }

  Iterable<ResultPoint> get normalPoints => _normal?.points ?? const <ResultPoint>[];
  Iterable<ResultDiffPoint> get diffPoints => _diff?.points ?? const <ResultDiffPoint>[];

  ResultPoint? findNormalPoint(int pointId) {
    for (final p in normalPoints) {
      if (p.pointId == pointId) return p;
    }
    return null;
  }

  ResultDiffPoint? findDiffPoint(int pointId) {
    for (final p in diffPoints) {
      if (p.pointId == pointId) return p;
    }
    return null;
  }

  Future<void> _rebuildMarkers() async {
    _isUpdatingMarkers = true;
    notifyListeners();
    try {
      if (_mode == ResultMapMode.normal) {
        final pts = _normal?.points ?? const <ResultPoint>[];
        final values = pts.map((pt) => findValueByParameter(pt.values, _parameter.apiName));
        final stats = computeStats(values);
        final min = stats.min ?? 0.0;
        final max = stats.max ?? 0.0;

        final vms = <ResultPointMarkerVm>[];
        for (final pt in pts) {
          final v = findValueByParameter(pt.values, _parameter.apiName);
          final label = fmt.format1OrDash(v);
          final isMissing = v == null;
          final color = isMissing
              ? ResultColorScale.missing
              : ResultColorScale.normalColor(value: v, min: min, max: max);
          final icon = await ResultMarkerIconFactory.circleLabel(color: color, label: label);
          vms.add(
            ResultPointMarkerVm(
              pointId: pt.pointId,
              position: LatLng(pt.lat, pt.lng),
              icon: icon,
              isMissing: isMissing,
            ),
          );
        }
        _markerVms = vms;
        return;
      }

      final pts = _diff?.points ?? const <ResultDiffPoint>[];
      final diffs = pts.map((pt) => findDiffValueByParameter(pt.diffValues, _parameter.apiName));
      final delta = computeDeltaMax(diffs);

      final vms = <ResultPointMarkerVm>[];
      for (final pt in pts) {
        final dv = findDiffValueByParameter(pt.diffValues, _parameter.apiName);
        final label = fmt.formatDiff1OrDash(dv);
        final isMissing = dv == null;
        final color = isMissing
            ? ResultColorScale.missing
            : ResultColorScale.diffColor(diffValue: dv, deltaMax: delta);
        final icon = await ResultMarkerIconFactory.circleLabel(color: color, label: label);
        vms.add(
          ResultPointMarkerVm(
            pointId: pt.pointId,
            position: LatLng(pt.lat, pt.lng),
            icon: icon,
            isMissing: isMissing,
          ),
        );
      }
      _markerVms = vms;
    } finally {
      _isUpdatingMarkers = false;
      notifyListeners();
    }
  }

  static String _toIsoDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

