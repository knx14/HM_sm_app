import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client_factory.dart';
import '../../../providers/user_provider.dart';
import '../../../services/geo_service.dart';
import '../../../utils/polygon_area.dart';
import '../../farms/data/farm_repository.dart';
import '../../farms/domain/farm.dart';
import '../../results/data/results_repository.dart';
import '../../results/domain/result_map.dart';
import '../../sync/domain/sync_settings_store.dart';
import '../constants/app_constants.dart';
import '../data/measurement_local_paths.dart';
import '../data/local_save_service.dart';
import '../data/measurement_sound_service.dart';
import '../data/measurement_upload_service.dart';
import '../data/local_measurement_pin_store.dart';
import '../data/pending_upload_store.dart';
import '../data/result_map_cache_store.dart';
import '../data/deleted_measurement_store.dart';
import '../data/serial_comm_android.dart';
import '../domain/app_settings.dart';
import '../domain/chart_data.dart';
import '../domain/measure_settings.dart';
import '../domain/measure_settings_store.dart';
import '../domain/measurement_parser.dart';
import '../domain/measurement_service.dart';
import '../domain/measurement_number.dart';
import '../domain/result_map_apply.dart';
import 'farm_select_screen.dart';
import 'measurement_settings_sheet.dart';

enum SessionStep { connect, bg, measure }

class _SpotProgress {
  _SpotProgress({
    required this.id,
    required this.position,
    required this.createdAt,
    this.isResultPoint = false,
    this.resultPointId,
    this.measurementNumber,
    this.uploadId,
    this.fileBase,
  });

  final String id;
  LatLng position;
  DateTime createdAt;
  final bool isResultPoint;
  int? resultPointId;
  final int? measurementNumber;
  int? uploadId;
  String? fileBase;
  int percent = 0;
  bool saveDone = false;
  bool uploadDone = false;
  bool failed = false;
  int iconVersion = 0;
  BitmapDescriptor? icon;
}

Color measurementSpotColor(_SpotProgress spot) {
  if (spot.isResultPoint || spot.uploadDone) {
    return const Color(0xFF27AE60);
  }
  if (spot.saveDone) {
    return const Color(0xFFE67E22);
  }
  return const Color(0xFFC0392B);
}

class MeasurementStateProvider extends ChangeNotifier {
  final Map<String, List<_SpotProgress>> _pinsByFarmDate =
      <String, List<_SpotProgress>>{};

  /// この画面で消した測定番号。結果マップやローカル復元で戻さない。
  final Map<String, Set<int>> _deletedMeasurementNumbersByFarmDate =
      <String, Set<int>>{};

  Farm? selectedFarm;
  LatLng? confirmedLocation;
  String? activeSpotId;
  String? correctingSpotId;
  bool isConnected = false;
  bool recallDone = false;
  bool bgDone = false;
  String? sensorSerialNo;

  String _jstDateString() {
    final utc = DateTime.now().toUtc();
    final jst = utc.add(const Duration(hours: 9));
    final month = jst.month.toString().padLeft(2, '0');
    final day = jst.day.toString().padLeft(2, '0');
    return '${jst.year}-$month-$day';
  }

  String _keyForFarm(int farmId) => '${farmId}_${_jstDateString()}';

  void _purgeOldSessions() {
    final today = _jstDateString();
    _pinsByFarmDate.removeWhere((key, _) => !key.endsWith('_$today'));
    _deletedMeasurementNumbersByFarmDate.removeWhere(
      (key, _) => !key.endsWith('_$today'),
    );
  }

  Set<int> _deletedMeasurementNumbersForFarm(int farmId) {
    _purgeOldSessions();
    return _deletedMeasurementNumbersByFarmDate.putIfAbsent(
      _keyForFarm(farmId),
      () => <int>{},
    );
  }

  void markMeasurementNumbersDeleted(int farmId, Iterable<int> numbers) {
    final deleted = _deletedMeasurementNumbersForFarm(farmId);
    deleted.addAll(numbers);
  }

  void startSession(int farmId) {
    _purgeOldSessions();
    _pinsByFarmDate.putIfAbsent(_keyForFarm(farmId), () => <_SpotProgress>[]);
    notifyListeners();
  }

  List<_SpotProgress> _pinsForFarm(int farmId) {
    _purgeOldSessions();
    return List.unmodifiable(_pinsByFarmDate[_keyForFarm(farmId)] ?? const []);
  }

  void _addPin(int farmId, _SpotProgress pin) {
    _addPins(farmId, [pin]);
  }

  void _addPins(int farmId, List<_SpotProgress> newPins) {
    if (newPins.isEmpty) return;
    _purgeOldSessions();
    final pins = _pinsByFarmDate.putIfAbsent(
      _keyForFarm(farmId),
      () => <_SpotProgress>[],
    );
    final existingIds = {for (final spot in pins) spot.id};
    var added = false;
    for (final pin in newPins) {
      if (existingIds.contains(pin.id)) continue;
      pins.add(pin);
      existingIds.add(pin.id);
      added = true;
    }
    if (added) notifyListeners();
  }

  void _removePins(int farmId, Set<String> ids) {
    final key = _keyForFarm(farmId);
    final pins = _pinsByFarmDate[key];
    if (pins == null) return;
    pins.removeWhere((spot) => ids.contains(spot.id));
    notifyListeners();
  }

  void markSyncedLocalPinUploaded({
    required int farmId,
    String? localPinId,
    double? latitude,
    double? longitude,
    int? uploadId,
    int? measurementNumber,
  }) {
    final key = _keyForFarm(farmId);
    final pins = _pinsByFarmDate[key];
    if (pins == null) return;

    _SpotProgress? target;
    if (localPinId != null && localPinId.isNotEmpty) {
      for (final spot in pins) {
        if (spot.id == localPinId) {
          target = spot;
          break;
        }
      }
    }
    if (target == null && measurementNumber != null) {
      for (final spot in pins) {
        if (spot.measurementNumber == measurementNumber) {
          target = spot;
          break;
        }
      }
    }

    if (target == null) return;
    target
      ..saveDone = true
      ..failed = false
      ..uploadDone = true
      ..uploadId = uploadId ?? target.uploadId
      ..icon = null;
    target.iconVersion++;
    notifyListeners();
  }

  void update({
    Farm? selectedFarm,
    LatLng? confirmedLocation,
    String? activeSpotId,
    String? correctingSpotId,
    required bool isConnected,
    required bool recallDone,
    required bool bgDone,
    String? sensorSerialNo,
  }) {
    this.selectedFarm = selectedFarm;
    this.confirmedLocation = confirmedLocation;
    this.activeSpotId = activeSpotId;
    this.correctingSpotId = correctingSpotId;
    this.isConnected = isConnected;
    this.recallDone = recallDone;
    this.bgDone = bgDone;
    this.sensorSerialNo = isConnected ? sensorSerialNo : null;
    notifyListeners();
  }
}

class MeasurementSessionScreen extends StatefulWidget {
  const MeasurementSessionScreen({super.key});

  @override
  State<MeasurementSessionScreen> createState() =>
      _MeasurementSessionScreenState();
}

class _MeasurementSessionScreenState extends State<MeasurementSessionScreen> {
  final _logController = TextEditingController();
  final _logScrollController = ScrollController();
  final _uploadLogController = TextEditingController();
  final _uploadLogScrollController = ScrollController();

  final _fstart = TextEditingController(
    text: MeasureSettings.defaults.fstart.toString(),
  );
  final _fdelta = TextEditingController(
    text: MeasureSettings.defaults.fdelta.toString(),
  );
  final _points = TextEditingController(
    text: MeasureSettings.defaults.points.toString(),
  );
  final _excite = TextEditingController(
    text: MeasureSettings.defaults.excite.toString(),
  );
  final _range = TextEditingController(
    text: MeasureSettings.defaults.range.toString(),
  );
  final _integrate = TextEditingController(
    text: MeasureSettings.defaults.integrate.toString(),
  );
  final _average = TextEditingController(
    text: MeasureSettings.defaults.average.toString(),
  );
  final _note1 = TextEditingController();
  final _note2 = TextEditingController();
  final AppSettings _settings = AppSettings();
  final MeasureSettingsStore _measureSettingsStore = MeasureSettingsStore();
  final PendingUploadStore _pendingUploadStore = PendingUploadStore();
  final SyncSettingsStore _syncSettingsStore = SyncSettingsStore();
  final ResultMapCacheStore _resultMapCacheStore = ResultMapCacheStore();
  final LocalMeasurementPinStore _localMeasurementPinStore =
      LocalMeasurementPinStore();
  final DeletedMeasurementStore _deletedMeasurementStore =
      DeletedMeasurementStore();
  final MeasurementSoundService _soundService = MeasurementSoundService();
  late final ResultsRepository _resultsRepository;
  SyncMode _syncMode = SyncMode.auto;

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isMeasuring = false;
  bool _isFetchingCurrentLocation = false;
  int _receivedPoints = 0;
  int _totalPoints = AppConstants.defaultPointCount;
  String _selectedSensor = '0';
  String? _ampId;

  Farm? _selectedFarm;
  LatLng? _confirmedLocation;
  LatLng? _currentGpsLocation;
  LatLng? _manualCorrectedLocation;
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _manualLocationHoldTimer;

  UploadPhase _uploadPhase = UploadPhase.idle;
  bool _isDrainingUploadQueue = false;
  SessionStep _currentStep = SessionStep.connect;

  bool _isRecalling = false;
  bool _recallDone = false;
  Timer? _recallTimeoutTimer;
  bool _bgIsMeasuring = false;
  bool _bgDone = false;
  int _bgReceivedPoints = 0;
  int _bgTotalPoints = AppConstants.defaultPointCount;
  double _bgProgress = 0.0;
  bool _isSelectingFarm = false;
  bool _showMapHint = true;
  int _fetchVersion = 0;
  final Map<int, DateTime> _deletedPointIds = <int, DateTime>{};
  static const Duration _manualLocationHoldDuration = Duration(seconds: 5);

  _SpotProgress? _activeSpot;
  String? _correctingSpotId;
  final Map<String, BitmapDescriptor> _markerIconCache =
      <String, BitmapDescriptor>{};
  Completer<bool>? _execCompleter;
  late MeasurementStateProvider _sessionState;
  bool _didBindSessionState = false;

  List<_SpotProgress> get _spots {
    final farm = _selectedFarm;
    if (farm == null) return const <_SpotProgress>[];
    return _sessionState._pinsForFarm(farm.id);
  }

  /// 選択圃場・当日の表示点。存在の正は端末の系列であり、クラウド点とマージしない。
  /// ピンとリストの数字は並び順ではなく、保存した測定番号を使う。
  List<_SpotProgress> get _mapSpots {
    final spots = [..._spots];
    spots.sort((a, b) {
      final numberCompare = MeasurementNumber.compareNullable(
        a.measurementNumber,
        b.measurementNumber,
      );
      if (numberCompare != 0) return numberCompare;
      final timeCompare = a.createdAt.compareTo(b.createdAt);
      if (timeCompare != 0) return timeCompare;
      return a.id.compareTo(b.id);
    });
    return spots;
  }

  int _nextMeasurementNumber() {
    return MeasurementNumber.next([
      for (final spot in _mapSpots) spot.measurementNumber,
    ]);
  }

  void _notifyMapSpotsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _loadSyncMode() async {
    final mode = await _syncSettingsStore.loadSyncMode();
    if (!mounted) return;
    setState(() => _syncMode = mode);
  }

  Future<void> _startGpsPositionUpdates() async {
    if (_positionSubscription != null) return;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 1,
            ),
          ).listen(
            _handleGpsPosition,
            onError: (Object e) {
              if (kDebugMode) {
                debugPrint('GPS位置更新エラー: $e');
              }
            },
          );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('GPS位置更新の開始に失敗しました: $e');
      }
    }
  }

  void _handleGpsPosition(Position position) {
    if (!mounted) return;
    final here = LatLng(position.latitude, position.longitude);

    if (_correctingSpotId != null || _manualCorrectedLocation != null) {
      setState(() => _currentGpsLocation = here);
      return;
    }

    setState(() {
      _currentGpsLocation = here;
      _confirmedLocation = here;
    });
    _persistSessionState();
  }

  void _setManualMeasurementLocation(
    LatLng location, {
    bool holdBeforeGpsResume = true,
  }) {
    _manualCorrectedLocation = location;
    _confirmedLocation = location;
    _manualLocationHoldTimer?.cancel();
    if (!holdBeforeGpsResume) return;
    _manualLocationHoldTimer = Timer(_manualLocationHoldDuration, () {
      if (!mounted || _correctingSpotId != null) return;
      final gpsLocation = _currentGpsLocation;
      setState(() {
        _manualCorrectedLocation = null;
        if (gpsLocation != null) {
          _confirmedLocation = gpsLocation;
        }
      });
      _persistSessionState();
    });
  }

  bool get _isUploading =>
      _uploadPhase == UploadPhase.saving ||
      _uploadPhase == UploadPhase.initCalling ||
      _uploadPhase == UploadPhase.uploading ||
      _uploadPhase == UploadPhase.completing;

  bool get _isSerialBusy =>
      _isConnecting || _isRecalling || _bgIsMeasuring || _isMeasuring;

  bool get _isShowingMeasurementProgress => _bgIsMeasuring || _isMeasuring;

  double get _currentMeasurementProgress {
    if (_bgIsMeasuring) return _bgProgress.clamp(0.0, 1.0);
    if (!_isMeasuring || _totalPoints <= 0) return 0.0;
    return (_receivedPoints / _totalPoints).clamp(0.0, 1.0);
  }

  List<LatLng> get _farmPolygon => (_selectedFarm?.boundaryPolygon ?? const [])
      .map((e) => LatLng(e['lat'] ?? 0, e['lng'] ?? 0))
      .toList();

  LatLng? get _effectiveMeasurementLocation =>
      _manualCorrectedLocation ?? _currentGpsLocation ?? _confirmedLocation;

  /// 赤マーカーが圃場ポリゴン内にあるかを毎回計算で判定する。
  /// キャッシュせず常に最新の測定位置と _farmPolygon から算出するため
  /// 同期ずれが原理的に発生しない。通信環境には一切依存しない純粋な数学演算。
  GeoFenceStatus? get _markerGeoStatus {
    final farm = _selectedFarm;
    if (farm != null && farm.isProvisional) return null;

    final point = _effectiveMeasurementLocation;
    final polygon = _farmPolygon;
    if (point == null || polygon.length < 3) return null;
    return GeoService.classifyLocation(point: point, polygon: polygon);
  }

  bool get _isProvisionalFarm => _selectedFarm?.isProvisional ?? false;

  @override
  void initState() {
    super.initState();
    _resultsRepository = ResultsRepository(buildApiClient());
    SerialComm.init(_onReceive);
    SerialComm.addDisconnectListener(_onUsbDisconnected);
    _loadSavedMeasureSettings();
    _loadSyncMode();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didBindSessionState) return;
    _sessionState = context.read<MeasurementStateProvider>();
    _isConnected = SerialComm.isConnected();
    _recallDone = _isConnected && _sessionState.recallDone;
    _bgDone = _isConnected && _sessionState.bgDone;
    _ampId = _isConnected ? _sessionState.sensorSerialNo : null;
    _selectedFarm = _sessionState.selectedFarm;
    final selectedFarm = _selectedFarm;
    if (selectedFarm != null) {
      _sessionState.startSession(selectedFarm.id);
    }
    _confirmedLocation = _sessionState.confirmedLocation;
    _correctingSpotId = _sessionState.correctingSpotId;
    _activeSpot = _spotById(_sessionState.activeSpotId);
    _currentStep = !_isConnected
        ? SessionStep.connect
        : _bgDone
        ? SessionStep.measure
        : SessionStep.bg;
    _didBindSessionState = true;
    _setupSerialComm();
    unawaited(_reloadPinsAndIcons());
    if (_selectedFarm != null) {
      _startGpsPositionUpdates();
    }
    if (_selectedFarm == null) {
      _autoSelectNearestFarm();
    }
  }

  Future<void> _loadSavedMeasureSettings() async {
    final stored = await _measureSettingsStore.load();
    if (!mounted) return;
    final settings = stored.settings;
    setState(() {
      _fstart.text = settings.fstart.toString();
      _fdelta.text = settings.fdelta.toString();
      _points.text = settings.points.toString();
      _excite.text = settings.excite.toString();
      _range.text = settings.range.toString();
      _integrate.text = settings.integrate.toString();
      _average.text = settings.average.toString();
      _selectedSensor = stored.selectedSensor;
    });
    _updateSettings();
  }

  @override
  void dispose() {
    _recallTimeoutTimer?.cancel();
    _manualLocationHoldTimer?.cancel();
    _positionSubscription?.cancel();
    SerialComm.removeDisconnectListener(_onUsbDisconnected);
    SerialComm.removeListener(_onReceive);
    _logController.dispose();
    _logScrollController.dispose();
    _uploadLogController.dispose();
    _uploadLogScrollController.dispose();
    _fstart.dispose();
    _fdelta.dispose();
    _points.dispose();
    _excite.dispose();
    _range.dispose();
    _integrate.dispose();
    _average.dispose();
    _note1.dispose();
    _note2.dispose();
    _soundService.dispose();
    super.dispose();
  }

  int _pointsValue() =>
      int.tryParse(_points.text.trim()) ?? MeasureSettings.defaults.points;
  double _fstartValue() =>
      double.tryParse(_fstart.text.trim()) ?? MeasureSettings.defaults.fstart;
  double _fdeltaValue() =>
      double.tryParse(_fdelta.text.trim()) ?? MeasureSettings.defaults.fdelta;
  double _exciteValue() =>
      double.tryParse(_excite.text.trim()) ?? MeasureSettings.defaults.excite;
  double _rangeValue() =>
      double.tryParse(_range.text.trim()) ?? MeasureSettings.defaults.range;
  double _integrateValue() =>
      double.tryParse(_integrate.text.trim()) ??
      MeasureSettings.defaults.integrate;
  int _averageValue() =>
      int.tryParse(_average.text.trim()) ?? MeasureSettings.defaults.average;

  void _persistSessionState() {
    if (!_didBindSessionState) return;
    _sessionState.update(
      selectedFarm: _selectedFarm,
      confirmedLocation: _confirmedLocation,
      activeSpotId: _activeSpot?.id,
      correctingSpotId: _correctingSpotId,
      isConnected: _isConnected,
      recallDone: _recallDone,
      bgDone: _bgDone,
      sensorSerialNo: _ampId,
    );
  }

  String _todayJstIsoDate() => _sessionState._jstDateString();

  Future<void> _reloadPinsAndIcons() async {
    await _refreshDisplayedSpotIcons();
    await _loadTodayResultPinsForSelectedFarm();
    if (!mounted) return;
    await _refreshDisplayedSpotIcons();
  }

  Future<void> _refreshDisplayedSpotIcons() async {
    final spots = [..._spots];
    for (final spot in spots) {
      await _refreshSpotIcon(spot);
    }
  }

  Future<List<_SpotProgress>> _loadTodayResultPinsForSelectedFarm() async {
    final farm = _selectedFarm;
    if (farm == null) return const <_SpotProgress>[];
    final myVersion = ++_fetchVersion;
    final dateIso = _todayJstIsoDate();
    await _restoreLocalPinsFromDisk(farm.id, dateIso);
    if (myVersion != _fetchVersion ||
        !mounted ||
        _selectedFarm?.id != farm.id) {
      return const <_SpotProgress>[];
    }
    try {
      final result = await _resultsRepository.fetchFarmResultMap(
        farmId: farm.id,
        dateIso: dateIso,
      );
      if (myVersion != _fetchVersion ||
          !mounted ||
          _selectedFarm?.id != farm.id) {
        return const <_SpotProgress>[];
      }
      if (result.points.isEmpty) {
        if (kDebugMode) {
          debugPrint('当日測定結果が空のため、表示中またはローカルのピンを維持します');
        }
        await _fallbackToCachedResultPins(farm.id, dateIso);
        return _mapSpots;
      }
      await _saveResultMapCache(farm.id, dateIso, result);
      if (myVersion != _fetchVersion ||
          !mounted ||
          _selectedFarm?.id != farm.id) {
        return const <_SpotProgress>[];
      }
      await _applyResultMap(farm.id, result);
      return _mapSpots;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('当日測定結果ピンの取得に失敗しました: $e');
      }
      if (myVersion != _fetchVersion) return const <_SpotProgress>[];
      await _fallbackToCachedResultPins(farm.id, dateIso);
      return _mapSpots;
    }
  }

  Future<void> _saveResultMapCache(
    int farmId,
    String dateIso,
    ResultMapResponse response,
  ) async {
    try {
      await _resultMapCacheStore.save(
        farmId: farmId,
        dateIso: dateIso,
        response: response,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('測定結果マップのキャッシュ保存に失敗しました: $e');
      }
    }
  }

  Future<List<_SpotProgress>> _applyResultMap(
    int farmId,
    ResultMapResponse result,
  ) async {
    final localSpots = _sessionState._pinsForFarm(farmId);
    final localNumbers = [
      for (final spot in localSpots) spot.measurementNumber,
    ];
    final localResultPointIds = [
      for (final spot in localSpots) spot.resultPointId,
    ];
    final deletedNumbers = _sessionState._deletedMeasurementNumbersForFarm(
      farmId,
    );
    final deletedResultPointIds = _deletedPointIds.keys.toSet();
    final toRefresh = <_SpotProgress>[];

    for (final point in result.points) {
      final decision = ResultMapPointDecision.decide(
        measurementNumber: point.measurementNumber,
        resultPointId: point.pointId,
        localNumbers: localNumbers,
        localResultPointIds: localResultPointIds,
        deletedMeasurementNumbers: deletedNumbers,
        deletedResultPointIds: deletedResultPointIds,
      );
      switch (decision.action) {
        case ResultMapPointAction.skipDeleted:
          continue;
        case ResultMapPointAction.update:
          final index = decision.matchingIndex;
          if (index == null || index < 0 || index >= localSpots.length) {
            continue;
          }
          final spot = localSpots[index];
          final wasEstimated = spot.uploadDone;
          final previousIcon = spot.icon;
          spot
            ..saveDone = true
            ..failed = false
            ..uploadDone = true
            ..resultPointId = point.pointId
            ..uploadId = point.uploadId ?? spot.uploadId;
          if (_correctingSpotId != spot.id) {
            spot.position = LatLng(point.lat, point.lng);
          }
          if (!wasEstimated || previousIcon == null) {
            toRefresh.add(spot);
          }
          break;
        case ResultMapPointAction.add:
          final spot = _spotFromResultPoint(
            point,
            measurementDate: result.measurementDate,
          );
          _sessionState._addPin(farmId, spot);
          localNumbers.add(spot.measurementNumber);
          localResultPointIds.add(spot.resultPointId);
          toRefresh.add(spot);
      }
    }

    for (final spot in toRefresh) {
      await _refreshSpotIcon(spot);
    }
    _notifyMapSpotsChanged();
    return _mapSpots;
  }

  _SpotProgress _spotFromResultPoint(
    ResultPoint point, {
    required DateTime measurementDate,
  }) {
    return _SpotProgress(
        id: 'result_${point.pointId}',
        position: LatLng(point.lat, point.lng),
        createdAt: point.createdAt ?? measurementDate,
        isResultPoint: true,
        resultPointId: point.pointId,
        measurementNumber: point.measurementNumber,
        uploadId: point.uploadId,
      )
      ..saveDone = true
      ..uploadDone = true;
  }

  /// 取得失敗時は表示中の点を消さない。キャッシュは未知の測定番号を足すためだけに使う。
  Future<List<_SpotProgress>> _fallbackToCachedResultPins(
    int farmId,
    String dateIso,
  ) async {
    if (!mounted || _selectedFarm?.id != farmId) {
      return const <_SpotProgress>[];
    }
    ResultMapResponse? cached;
    try {
      cached = await _resultMapCacheStore.load(
        farmId: farmId,
        dateIso: dateIso,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('測定結果マップのキャッシュ読み込みに失敗しました: $e');
      }
    }
    if (cached == null ||
        cached.points.isEmpty ||
        !mounted ||
        _selectedFarm?.id != farmId) {
      return const <_SpotProgress>[];
    }
    return await _applyResultMap(farmId, cached);
  }

  /// 端末に残っている当日の測定データから、まだ系列に無いローカルピンを復元する。
  /// 同じ測定番号が既にある点は重ねない。削除した番号も戻さない。
  Future<void> _restoreLocalPinsFromDisk(int farmId, String dateIso) async {
    if (!mounted || _selectedFarm?.id != farmId) return;
    try {
      final persistedDeleted = await _deletedMeasurementStore.load(
        farmId: farmId,
        dateIso: dateIso,
      );
      _sessionState.markMeasurementNumbersDeleted(farmId, persistedDeleted);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('削除記録の読み込みに失敗しました: $e');
      }
    }
    if (!mounted || _selectedFarm?.id != farmId) return;
    List<LocalMeasurementRecord> records;
    try {
      final pending = await _pendingUploadStore.listItems();
      records = await _localMeasurementPinStore.loadForFarmOnDate(
        farmId: farmId,
        dateIso: dateIso,
        pendingItems: pending,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ローカル測定ピンの復元に失敗しました: $e');
      }
      return;
    }
    if (!mounted || _selectedFarm?.id != farmId) return;

    final existingIds = {for (final spot in _spots) spot.id};
    final existingNumbers = {
      for (final spot in _spots)
        if (spot.measurementNumber != null) spot.measurementNumber!,
    };
    final deletedNumbers = _sessionState._deletedMeasurementNumbersForFarm(
      farmId,
    );
    final restored = <_SpotProgress>[];
    for (final record in records) {
      if (existingIds.contains(record.id)) continue;
      final number = record.measurementNumber;
      if (number != null && deletedNumbers.contains(number)) continue;
      if (number != null && existingNumbers.contains(number)) continue;
      restored.add(
        _SpotProgress(
            id: record.id,
            position: LatLng(record.latitude, record.longitude),
            createdAt: record.createdAt,
            measurementNumber: record.measurementNumber,
            fileBase: record.fileBase,
          )
          ..saveDone = true
          ..uploadDone = !record.isPending,
      );
      existingIds.add(record.id);
      if (number != null) existingNumbers.add(number);
    }
    if (restored.isEmpty) return;
    _sessionState._addPins(farmId, restored);
    for (final spot in restored) {
      await _refreshSpotIcon(spot);
    }
    _notifyMapSpotsChanged();
  }

  String _resultMutationErrorMessage(Object error) {
    if (error is DioException && error.response?.statusCode == 404) {
      return '測定データ更新APIが見つかりません。サーバー側の反映状況を確認してください。';
    }
    return '測定データの更新に失敗しました。通信状態を確認してください。';
  }

  MeasureSettings _currentSettings() {
    return MeasureSettings(
      fstart: _fstartValue(),
      fdelta: _fdeltaValue(),
      points: _pointsValue(),
      excite: _exciteValue(),
      range: _rangeValue(),
      integrate: _integrateValue(),
      average: _averageValue(),
    );
  }

  void _appendLog(String text) {
    setState(() {
      _logController.text += text;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_logScrollController.hasClients) {
        _logScrollController.jumpTo(
          _logScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  void _appendUploadLog(String text) {
    final line = text.endsWith('\n') ? text.trimRight() : text;
    setState(() {
      _uploadLogController.text += '$line\n';
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_uploadLogScrollController.hasClients) {
        _uploadLogScrollController.jumpTo(
          _uploadLogScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  void _onUsbDisconnected() {
    if (!mounted) return;
    _recallTimeoutTimer?.cancel();
    setState(() {
      _isConnected = false;
      _currentStep = SessionStep.connect;
      _isConnecting = false;
      _isRecalling = false;
      _recallDone = false;
      _bgIsMeasuring = false;
      _bgDone = false;
      _isMeasuring = false;
      _bgProgress = 0.0;
      _ampId = null;
    });
    _persistSessionState();
    _appendLog('USBが切断されました。接続からやり直してください。\n');
  }

  void _setupSerialComm() => SerialComm.init(_onReceive);

  Future<void> _connect() async {
    if (_isSerialBusy) return;
    setState(() => _isConnecting = true);
    var success = false;
    try {
      success = await SerialComm.connect();
      if (success) {
        _setupSerialComm();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _isConnected = success;
          _currentStep = SessionStep.connect;
          if (success) {
            _ampId = null;
          }
        });
      }
    }
    if (!mounted) return;
    _persistSessionState();
    _appendLog(
      success
          ? '${AppConstants.messageConnectionSuccess}\n'
          : '${AppConstants.errorConnectionFailed}\n',
    );
    if (success) {
      _startAutoRecall();
    }
  }

  void _disconnect() {
    if (_isConnecting || _isRecalling || _bgIsMeasuring || _isMeasuring) return;
    _recallTimeoutTimer?.cancel();
    SerialComm.disconnect();
    setState(() {
      _isConnected = false;
      _isConnecting = false;
      _isRecalling = false;
      _recallDone = false;
      _bgIsMeasuring = false;
      _bgDone = false;
      _bgProgress = 0.0;
      _currentStep = SessionStep.connect;
      _ampId = null;
    });
    _persistSessionState();
    SerialComm.init(_onReceive);
    SerialComm.addDisconnectListener(_onUsbDisconnected);
    _appendLog('センサー接続を解除しました\n');
  }

  void _startAutoRecall() {
    if (!_isConnected) return;
    const sensorNumber = '0';
    _selectedSensor = sensorNumber;
    _recallTimeoutTimer?.cancel();
    setState(() {
      _isRecalling = true;
      _recallDone = false;
    });
    _persistSessionState();
    _appendLog('送信: condition recall $sensorNumber\n');
    MeasurementService.sendRecallCommand(sensorNumber);
    _recallTimeoutTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted || !_isRecalling) return;
      setState(() {
        _isRecalling = false;
        _recallDone = false;
        _currentStep = SessionStep.connect;
      });
      _persistSessionState();
      _appendLog('Recallタイムアウト（20秒）\n');
    });
  }

  void _sendIDCommand() {
    if (!_isConnected || _isSerialBusy) return;
    _appendLog('送信: ID\n');
    MeasurementService.sendIdCommand();
  }

  void _sendListCommand() {
    if (!_isConnected || _isSerialBusy) return;
    MeasurementService.sendListCommand();
  }

  void _sendStoreCommand() {
    if (!_isConnected || _isSerialBusy) return;
    MeasurementService.sendStoreCommand(_selectedSensor);
  }

  void _updateSettings() {
    _settings.update(
      fstart: double.tryParse(_fstart.text),
      fdelta: double.tryParse(_fdelta.text),
      points: int.tryParse(_points.text),
      excite: double.tryParse(_excite.text),
      range: double.tryParse(_range.text),
      integrate: double.tryParse(_integrate.text),
      average: int.tryParse(_average.text),
    );
  }

  void _startBg() {
    if (!_isConnected) {
      _appendLog('${AppConstants.errorConnectFirst}\n');
      return;
    }
    if (_isSerialBusy) return;
    _updateSettings();
    setState(() {
      _logController.clear();
      _bgProgress = 0.0;
      _bgReceivedPoints = 0;
      _bgTotalPoints = _settings.points;
      _bgIsMeasuring = true;
      _bgDone = false;
      _currentStep = SessionStep.bg;
    });
    _persistSessionState();
    _appendLog(
      '送信: null ${_settings.excite} ${_settings.range} ${_settings.integrate} ${_settings.average}\n',
    );
    MeasurementService.sendBgMeasurementCommand(_settings);
  }

  Future<void> _openFarmSelection() async {
    if (_isSelectingFarm || _isSerialBusy) return;
    _isSelectingFarm = true;
    final result = await Navigator.push<FarmSelectResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const FarmSelectScreen(mode: FarmSelectMode.farmOnly),
      ),
    );
    if (!mounted) return;
    final farm = result?.farm;
    if (farm == null) {
      // 圃場を選ばずに戻った場合は、それまでの選択圃場・測定位置・GPS更新を
      // そのまま維持する。
      _isSelectingFarm = false;
      return;
    }
    if (result?.isFromCache ?? false) {
      final shouldContinue = await _confirmUsingCachedFarms();
      if (!mounted) return;
      if (!shouldContinue) {
        _isSelectingFarm = false;
        return;
      }
    }
    final polygon = farm.boundaryPolygon
        .map((p) => LatLng(p['lat']!, p['lng']!))
        .toList();
    final center = calculatePolygonCenter(polygon);
    // まずポリゴン中心をフォールバックとして設定
    // ステータスは _markerGeoStatus getter で自動計算されるため手動設定不要
    _manualLocationHoldTimer?.cancel();
    setState(() {
      _selectedFarm = farm;
      _confirmedLocation = center;
      _currentGpsLocation = null;
      _manualCorrectedLocation = null;
      _activeSpot = null;
      _correctingSpotId = null;
      _currentStep = SessionStep.measure;
      _showMapHint = true;
    });
    _sessionState.startSession(farm.id);
    _persistSessionState();
    await _startGpsPositionUpdates();
    await _reloadPinsAndIcons();
    _isSelectingFarm = false;
    await _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: center, zoom: 18)),
    );
    // GPS現在位置を取得して赤マーカーの初期位置を現在地に設定する。
    // GPS取得に失敗した場合はポリゴン中心のまま残る。
    await _fetchCurrentLocation(moveCamera: true);
  }

  Future<bool> _confirmUsingCachedFarms() async {
    final shouldContinue = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('オフラインで続行しますか？'),
        content: const Text('オフラインでは、地図が表示されない場合がありますが測定は可能です。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('続行する'),
          ),
        ],
      ),
    );
    return shouldContinue ?? false;
  }

  Future<void> _autoSelectNearestFarm() async {
    if (_selectedFarm != null || _isSelectingFarm) return;
    setState(() => _isSelectingFarm = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }

      final farmRepository = FarmRepository(buildApiClient());
      final results = await Future.wait([
        Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        ),
        farmRepository.getFarms(),
      ]);
      if (!mounted || _selectedFarm != null) return;
      if (farmRepository.wasLastResultFromCache) return;
      final pos = results[0] as Position;
      final farms = results[1] as List<Farm>;
      Farm? nearestFarm;
      LatLng? nearestCenter;
      var minDistance = double.infinity;

      for (final farm in farms) {
        final polygon = farm.boundaryPolygon
            .map((p) => LatLng(p['lat']!, p['lng']!))
            .toList();
        if (polygon.isEmpty) continue;
        final center = calculatePolygonCenter(polygon);
        final distance = Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          center.latitude,
          center.longitude,
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestFarm = farm;
          nearestCenter = center;
        }
      }

      if (nearestFarm == null || nearestCenter == null) return;
      final here = LatLng(pos.latitude, pos.longitude);
      _manualLocationHoldTimer?.cancel();
      setState(() {
        _selectedFarm = nearestFarm;
        _currentGpsLocation = here;
        _manualCorrectedLocation = null;
        _confirmedLocation = here;
        _currentStep = _bgDone ? SessionStep.measure : _currentStep;
        _showMapHint = true;
      });
      _sessionState.startSession(nearestFarm.id);
      _persistSessionState();
      await _startGpsPositionUpdates();
      await _loadTodayResultPinsForSelectedFarm();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('最近傍圃場の自動選択に失敗しました: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSelectingFarm = false);
      }
    }
  }

  Future<void> _fetchCurrentLocation({bool moveCamera = true}) async {
    if (_isSerialBusy) return;
    setState(() => _isFetchingCurrentLocation = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _appendLog('位置情報サービスが無効です\n');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _appendLog('位置情報の権限がありません\n');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final here = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      // 赤マーカー位置を現在地に更新。
      // ステータスは _markerGeoStatus getter で自動計算される。
      _manualLocationHoldTimer?.cancel();
      setState(() {
        _currentGpsLocation = here;
        _manualCorrectedLocation = null;
        _confirmedLocation = here;
      });
      _persistSessionState();
      await _startGpsPositionUpdates();
      if (moveCamera) {
        await _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: here, zoom: 18),
          ),
        );
      }
    } catch (e) {
      _appendLog('現在地取得エラー: $e\n');
    } finally {
      if (mounted) {
        setState(() => _isFetchingCurrentLocation = false);
      }
    }
  }

  Future<bool> _startExecAndWait() async {
    if (!_isConnected) {
      _appendLog('${AppConstants.errorConnectFirst}\n');
      return false;
    }
    _updateSettings();
    final settings = _settings;
    if (settings.points <= 0) {
      _appendLog('${AppConstants.errorPointsInvalid}\n');
      return false;
    }
    _execCompleter = Completer<bool>();
    setState(() {
      _logController.clear();
      _receivedPoints = 0;
      _totalPoints =
          int.tryParse(_points.text.trim()) ?? AppConstants.defaultPointCount;
      _isMeasuring = true;
      _uploadPhase = UploadPhase.idle;
    });
    MeasurementService.sendMeasurementCommand(settings);
    return _execCompleter!.future;
  }

  Future<void> _startMeasureSequence() async {
    final farm = _selectedFarm;
    if (_isSerialBusy || farm == null) return;

    var point = _effectiveMeasurementLocation;
    final polygon = _farmPolygon;
    if (point == null && polygon.isNotEmpty) {
      point = calculatePolygonCenter(polygon);
      setState(() => _confirmedLocation = point);
    }
    if (point == null) return;

    // _markerGeoStatus getter で赤マーカーの圃場内外を判定（安全弁）。
    // maps_toolkit による純粋な数学演算のため通信環境に一切依存しない。
    final status = _markerGeoStatus;
    if (status == GeoFenceStatus.outside) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('圃場外のため測定できません。地点を圃場内に調整してください。')),
      );
      return;
    }
    final localPinId = DateTime.now().millisecondsSinceEpoch.toString();
    final spot = _SpotProgress(
      id: localPinId,
      position: point,
      createdAt: DateTime.now(),
      measurementNumber: _nextMeasurementNumber(),
    );
    _sessionState._addPin(farm.id, spot);
    setState(() {
      _activeSpot = spot;
      _uploadLogController.clear();
    });
    _persistSessionState();
    await _refreshSpotIcon(spot);
    final execOk = await _startExecAndWait();
    if (!mounted) return;
    if (!execOk) {
      _appendUploadLog('error: exec failed');
      await _markSpotFailed(spot);
      return;
    }
    unawaited(_soundService.playMeasurementComplete());
    await _saveAndQueueThenUpload(spot, localPinPosition: point);
  }

  Future<String?> _save(
    int farmId, {
    required LatLng measurementLocation,
    int? measurementNumber,
  }) async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null || userId.trim().isEmpty) {
      _appendLog('ユーザIDが未設定のため保存できません\n');
      return null;
    }
    final note1 = _note1.text.trim();
    final note2 = _note2.text.trim();
    if (!LocalSaveService.isValidMemo(note1) ||
        !LocalSaveService.isValidMemo(note2)) {
      _appendLog('${AppConstants.errorInvalidMemoFormat}\n');
      return null;
    }
    try {
      final settings = _currentSettings();
      final chartDataForCsv = _buildExecChartDataForCsvFromResponseLog(
        settings,
      );
      final fileBase = await LocalSaveService.saveMeasurement(
        chartData: chartDataForCsv,
        userId: userId,
        farmId: farmId,
        note1: note1,
        note2: note2,
        settings: settings,
        ampId: _ampId,
        latitude: measurementLocation.latitude,
        longitude: measurementLocation.longitude,
        measurementNumber: measurementNumber,
      );
      _appendLog('保存完了: $fileBase\n');
      return fileBase;
    } catch (e) {
      _appendLog('保存エラー: $e\n');
      return null;
    }
  }

  Future<void> _saveAndQueueThenUpload(
    _SpotProgress spot, {
    required LatLng localPinPosition,
  }) async {
    final farm = _selectedFarm;
    if (farm == null) return;
    if (!_isDrainingUploadQueue) {
      setState(() {
        _uploadPhase = UploadPhase.saving;
      });
    }
    String? fileBase;

    try {
      _appendUploadLog('save: start');
      fileBase = await _save(
        farm.id,
        measurementLocation: localPinPosition,
        measurementNumber: spot.measurementNumber,
      );
      if (fileBase == null) {
        if (!mounted) return;
        if (!_isDrainingUploadQueue) {
          setState(() => _uploadPhase = UploadPhase.error);
        }
        _appendUploadLog('save: error');
        await _markSpotFailed(spot);
        return;
      }
      spot.fileBase = fileBase;
      _appendUploadLog('save: ok $fileBase');
      await _markSpotSaved(spot);

      final jsonFile = await MeasurementLocalPaths.jsonFile(fileBase);
      if (!await jsonFile.exists()) {
        throw StateError('保存済みファイルが見つかりません: $fileBase');
      }
      final measurementParameters =
          jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
      final measurementDate =
          (measurementParameters['timestamp'] as String?) ??
          DateTime.now().toIso8601String();

      final syncMode = await _syncSettingsStore.loadSyncMode();
      if (mounted && syncMode != _syncMode) {
        setState(() => _syncMode = syncMode);
      }
      final queued = await _queuePendingUpload(
        PendingUploadItem(
          fileBase: fileBase,
          farmId: farm.id,
          farmName: farm.farmName,
          pointNumber: spot.measurementNumber,
          localPinId: spot.id,
          latitude: localPinPosition.latitude,
          longitude: localPinPosition.longitude,
          note1: _note1.text.trim().isEmpty ? null : _note1.text.trim(),
          note2: _note2.text.trim().isEmpty ? null : _note2.text.trim(),
          measurementDate: measurementDate,
          failedPhase: syncMode == SyncMode.manual ? 'manual' : 'queued',
          lastError: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (!queued) {
        _appendUploadLog('pending: queue failed $fileBase');
      }
      if (syncMode == SyncMode.manual) {
        if (!mounted) return;
        if (!_isDrainingUploadQueue) {
          setState(() => _uploadPhase = UploadPhase.done);
        }
        _appendUploadLog(
          queued
              ? 'manual: 保存完了（同期画面から送信できます） $fileBase'
              : 'manual: 同期キュー登録に失敗 $fileBase',
        );
        return;
      }
      unawaited(_drainAutoUploadQueue());
    } catch (e) {
      if (fileBase != null) {
        await _queuePendingUpload(
          PendingUploadItem(
            fileBase: fileBase,
            farmId: farm.id,
            farmName: farm.farmName,
            pointNumber: spot.measurementNumber,
            localPinId: spot.id,
            latitude: localPinPosition.latitude,
            longitude: localPinPosition.longitude,
            note1: _note1.text.trim().isEmpty ? null : _note1.text.trim(),
            note2: _note2.text.trim().isEmpty ? null : _note2.text.trim(),
            measurementDate: DateTime.now().toIso8601String(),
            failedPhase: 'queued',
            lastError: e.toString(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }
      if (!mounted) return;
      await _markSpotFailed(spot);
      if (!_isDrainingUploadQueue) {
        setState(() => _uploadPhase = UploadPhase.error);
      }
      _appendUploadLog('error: $e');
    } finally {
      if (mounted &&
          !_isDrainingUploadQueue &&
          _uploadPhase != UploadPhase.done &&
          _uploadPhase != UploadPhase.error) {
        setState(() => _uploadPhase = UploadPhase.idle);
      }
    }
  }

  Future<void> _drainAutoUploadQueue() async {
    if (_isDrainingUploadQueue) return;
    _isDrainingUploadQueue = true;
    try {
      while (mounted) {
        final items = await _pendingUploadStore.listItemsInMeasurementOrder();
        PendingUploadItem? next;
        for (final item in items) {
          if (item.failedPhase == 'queued') {
            next = item;
            break;
          }
        }
        if (next == null) break;
        await _uploadQueuedItem(next);
      }
    } finally {
      _isDrainingUploadQueue = false;
    }
  }

  Future<void> _uploadQueuedItem(PendingUploadItem item) async {
    try {
      final csvFile = await MeasurementLocalPaths.csvFile(item.fileBase);
      final jsonFile = await MeasurementLocalPaths.jsonFile(item.fileBase);
      if (!await csvFile.exists() || !await jsonFile.exists()) {
        throw StateError('保存済みファイルが見つかりません: ${item.fileBase}');
      }
      final measurementParameters =
          jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
      final result = await MeasurementUploadService().uploadCsvWithInitComplete(
        farmId: item.farmId,
        csvFile: csvFile,
        measurementParameters: measurementParameters,
        measurementDate: item.measurementDate,
        note1: item.note1,
        note2: item.note2,
        cultivationType: null,
        measurementNumber: item.pointNumber,
        onPhase: (phase) {
          if (!mounted) return;
          setState(() => _uploadPhase = phase);
        },
        onLog: (message) {
          if (!mounted) return;
          _appendUploadLog(message);
        },
      );
      if (!mounted) return;
      final spot = _spotById(item.localPinId);
      if (spot != null) {
        spot.uploadId = result.uploadId;
        await _markSpotUploaded(spot);
      }
      setState(() => _uploadPhase = UploadPhase.done);
      _appendUploadLog(
        'done: upload_id=${result.uploadId} (受付完了: 処理中)',
      );
      try {
        await _pendingUploadStore.removeByFileBase(item.fileBase);
      } catch (e) {
        _appendUploadLog('pending: remove failed $e');
      }
    } on MeasurementUploadException catch (e) {
      await _queuePendingUpload(
        item.copyWith(
          failedPhase: e.phase.name,
          lastError: e.toString(),
          updatedAt: DateTime.now(),
        ),
      );
      final spot = _spotById(item.localPinId);
      if (spot != null) {
        await _markSpotFailed(spot);
      }
      if (!mounted) return;
      setState(() => _uploadPhase = UploadPhase.error);
      _appendUploadLog('error: $e');
      _appendUploadLog('pending: queued ${item.fileBase}');
    } catch (e) {
      await _queuePendingUpload(
        item.copyWith(
          failedPhase: UploadPhase.error.name,
          lastError: e.toString(),
          updatedAt: DateTime.now(),
        ),
      );
      final spot = _spotById(item.localPinId);
      if (spot != null) {
        await _markSpotFailed(spot);
      }
      if (!mounted) return;
      setState(() => _uploadPhase = UploadPhase.error);
      _appendUploadLog('error: $e');
      _appendUploadLog('pending: queued ${item.fileBase}');
    }
  }

  Future<bool> _queuePendingUpload(PendingUploadItem item) async {
    try {
      await _pendingUploadStore.addOrUpdate(item);
      return true;
    } catch (e) {
      _appendUploadLog('pending: save failed $e');
      return false;
    }
  }

  List<ChartData> _buildExecChartDataForCsvFromResponseLog(
    MeasureSettings settings,
  ) {
    final expectedFreqs = <int>[];
    final expectedSet = <int>{};
    for (var i = 0; i < settings.points; i++) {
      final f = (settings.fstart + settings.fdelta * i).round();
      expectedFreqs.add(f);
      expectedSet.add(f);
    }
    final byFreq = <int, ChartData>{};
    for (final rawLine in _logController.text.split(RegExp(r'\r?\n'))) {
      var line = rawLine.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('*') || line.startsWith('＊')) {
        line = line.substring(1).trim();
      } else {
        continue;
      }
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 4) continue;
      final freqD = double.tryParse(parts[0]);
      final real = double.tryParse(parts[1]);
      final imag = double.tryParse(parts[2]);
      if (freqD == null || real == null || imag == null) continue;
      final freq = freqD.round();
      if (!expectedSet.contains(freq)) continue;
      byFreq[freq] = ChartData(
        real: real,
        imag: imag,
        frequency: freq.toDouble(),
      );
    }
    final missing = <int>[];
    final ordered = <ChartData>[];
    for (final f in expectedFreqs) {
      final v = byFreq[f];
      if (v == null) {
        missing.add(f);
      } else {
        ordered.add(v);
      }
    }
    if (missing.isNotEmpty) {
      throw StateError(
        'CSV用データ欠損: ${ordered.length}/${settings.points}点（missing freq=${missing.take(30).toList()}${missing.length > 30 ? '...' : ''}）',
      );
    }
    return ordered;
  }

  void _onReceive(String data) {
    if (!mounted) return;
    var shouldPersist = false;
    var shouldRequestSensorId = false;
    setState(() {
      _logController.text += data;
      final newLines = data.split('\n');
      for (var line in newLines) {
        line = line.trim();
        if (line.isEmpty) continue;

        final amp = MeasurementParser.tryParseAmpId(line);
        if (amp != null && amp != _ampId) {
          _ampId = amp;
          _logController.text += 'AMP ID: $_ampId\n';
          shouldPersist = true;
        }

        if (MeasurementParser.isOkLine(line)) {
          if (_isRecalling) {
            _recallTimeoutTimer?.cancel();
            _isRecalling = false;
            _recallDone = true;
            _currentStep = SessionStep.bg;
            shouldPersist = true;
            shouldRequestSensorId = true;
            continue;
          }
          if (_currentStep == SessionStep.bg && _bgIsMeasuring) {
            _bgIsMeasuring = false;
            _bgDone = true;
            shouldPersist = true;
            continue;
          }
          if (_isMeasuring) {
            _isMeasuring = false;
            _receivedPoints = _totalPoints;
            _setActiveSpotProgress(100);
            _execCompleter?.complete(true);
            continue;
          }
        } else if (MeasurementParser.isErrorLine(line)) {
          if (_isRecalling) {
            _recallTimeoutTimer?.cancel();
            _isRecalling = false;
            _recallDone = false;
            _currentStep = SessionStep.connect;
            _logController.text += 'Recallに失敗しました\n';
            shouldPersist = true;
            continue;
          }
          if (_currentStep == SessionStep.bg && _bgIsMeasuring) {
            _bgIsMeasuring = false;
            _logController.text += 'BG測定中にエラーが発生しました\n';
            shouldPersist = true;
            continue;
          }
          if (_isMeasuring) {
            _isMeasuring = false;
            _logController.text += '測定中にエラーが発生しました\n';
            _execCompleter?.complete(false);
            continue;
          }
        }

        if (_currentStep == SessionStep.bg &&
            _bgIsMeasuring &&
            line.startsWith('*')) {
          _bgReceivedPoints++;
          _bgProgress = (_bgReceivedPoints / _bgTotalPoints).clamp(0.0, 1.0);
          continue;
        }

        if (_isMeasuring && line.startsWith('*')) {
          _receivedPoints++;
          final p = ((_receivedPoints / _totalPoints) * 100)
              .clamp(0, 100)
              .toInt();
          _setActiveSpotProgress(p);
        }
      }
    });
    if (shouldPersist) {
      _persistSessionState();
    }
    if (shouldRequestSensorId) {
      _sendIDCommand();
    }
  }

  Future<void> _refreshSpotIcon(_SpotProgress spot) async {
    final requestVersion = ++spot.iconVersion;
    final Color color = measurementSpotColor(spot);
    final label = spot.measurementNumber?.toString() ?? '?';
    final key = 'small-v2-$label-${color.toARGB32()}';
    final cached = _markerIconCache[key];
    if (cached != null) {
      if (requestVersion != spot.iconVersion) return;
      setState(() => spot.icon = cached);
      return;
    }
    final icon = await _buildMarkerIcon(label: label, color: color);
    _markerIconCache[key] = icon;
    if (!mounted) return;
    if (requestVersion != spot.iconVersion) return;
    setState(() => spot.icon = icon);
  }

  Future<BitmapDescriptor> _buildMarkerIcon({
    required String label,
    required Color color,
  }) async {
    const size = 40.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = const Offset(size / 2, size / 2);
    final paint = Paint()..color = color;
    canvas.drawCircle(center, 15, paint);
    canvas.drawCircle(
      center,
      15,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final tp = TextPainter(textDirection: TextDirection.ltr);
    tp.text = TextSpan(
      text: label,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 15,
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(Uint8List.view(bytes!.buffer));
  }

  void _setActiveSpotProgress(int percent) {
    final spot = _activeSpot;
    if (spot == null) return;
    spot.percent = percent.clamp(0, 100);
    _refreshSpotIcon(spot);
  }

  _SpotProgress? _spotById(String? id) {
    if (id == null) return null;
    for (final spot in _mapSpots) {
      if (spot.id == id) return spot;
    }
    return null;
  }

  void _nudgeCorrectingSpot({double latMeters = 0, double lngMeters = 0}) {
    if (_isSerialBusy) return;
    final spot = _spotById(_correctingSpotId);
    if (spot == null) return;
    const metersPerLatitudeDegree = 111000.0;
    final latDelta = latMeters / metersPerLatitudeDegree;
    final lngScale = math.cos(spot.position.latitude * math.pi / 180);
    if (lngScale.abs() < 0.000001) return;
    final lngDelta = lngMeters / (metersPerLatitudeDegree * lngScale);
    final next = LatLng(
      spot.position.latitude + latDelta,
      spot.position.longitude + lngDelta,
    );
    setState(() {
      spot.position = next;
      _setManualMeasurementLocation(next, holdBeforeGpsResume: false);
    });
    _persistSessionState();
    _mapController?.animateCamera(CameraUpdate.newLatLng(next));
  }

  void _startPinCorrection(_SpotProgress spot) {
    setState(() {
      _correctingSpotId = spot.id;
      _setManualMeasurementLocation(spot.position, holdBeforeGpsResume: false);
      _showMapHint = true;
    });
    _persistSessionState();
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: spot.position, zoom: 21),
      ),
    );
  }

  Future<void> _markSpotSaved(_SpotProgress spot) async {
    spot.saveDone = true;
    await _refreshSpotIcon(spot);
  }

  Future<void> _markSpotUploaded(_SpotProgress spot) async {
    spot.saveDone = true;
    spot.failed = false;
    spot.uploadDone = true;
    await _refreshSpotIcon(spot);
  }

  Future<void> _markSpotFailed(_SpotProgress spot) async {
    if (!spot.saveDone) {
      spot.failed = true;
    }
    await _refreshSpotIcon(spot);
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    for (final spot in _mapSpots) {
      final icon = spot.icon;
      if (icon == null) continue;
      markers.add(
        Marker(
          markerId: MarkerId('spot_${spot.id}'),
          position: spot.position,
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          consumeTapEvents: false,
        ),
      );
    }
    return markers;
  }

  Set<Circle> _buildLocationCircles() {
    final location = _effectiveMeasurementLocation;
    if (location == null) return const <Circle>{};
    return {
      Circle(
        circleId: const CircleId('confirmed_location'),
        center: location,
        radius: 0.45,
        strokeWidth: 3,
        strokeColor: const Color(0xFFB02020),
        fillColor: const Color(0xFFB02020).withValues(alpha: 0.45),
        consumeTapEvents: false,
      ),
    };
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: MeasurementSettingsSheet(
            isConnected: _isConnected,
            isMeasuring: _isSerialBusy,
            isUploading: _isUploading,
            onSendId: _sendIDCommand,
            onSendList: _sendListCommand,
            onSendStore: _sendStoreCommand,
            logController: _logController,
            logScrollController: _logScrollController,
            uploadLogController: _uploadLogController,
            uploadLogScrollController: _uploadLogScrollController,
            uploadPhase: _uploadPhase,
          ),
        );
      },
    );
  }

  Widget _buildMeasureBody() {
    if (_selectedFarm == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 56,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 12),
              const Text(
                '圃場を選択すると地図が表示されます',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSerialBusy ? null : _openFarmSelection,
                icon: const Icon(Icons.agriculture),
                label: const Text('圃場を選択'),
              ),
            ],
          ),
        ),
      );
    }
    final polygon = _farmPolygon;
    final initialTarget =
        _effectiveMeasurementLocation ?? calculatePolygonCenter(polygon);
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: 17,
          ),
          onMapCreated: (c) => _mapController = c,
          mapType: MapType.satellite,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          polygons: {
            if (polygon.length >= 3)
              Polygon(
                polygonId: const PolygonId('farm_polygon'),
                points: polygon,
                strokeColor: Colors.red,
                strokeWidth: 3,
                fillColor: Colors.transparent,
              ),
          },
          markers: _buildMarkers(),
          circles: _buildLocationCircles(),
          onTap: (p) {
            if (_isSerialBusy) return;
            // 赤マーカー位置を更新。ステータスは _markerGeoStatus getter で
            // rebuild 時に自動計算されるため、同期ずれが原理的に起きない。
            setState(() {
              final correctingSpot = _spotById(_correctingSpotId);
              _setManualMeasurementLocation(
                p,
                holdBeforeGpsResume: correctingSpot == null,
              );
              if (correctingSpot != null) {
                correctingSpot.position = p;
              }
            });
            _persistSessionState();
          },
        ),
        Positioned(
          top: 12,
          left: 12,
          child: FloatingActionButton.small(
            heroTag: 'measurement_list_button',
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            onPressed: _isSerialBusy
                ? null
                : () {
                    _openMeasurementList();
                  },
            child: const Icon(Icons.list),
          ),
        ),
        if (_showMapHint)
          Positioned(
            top: 16,
            left: 72,
            right: 12,
            child: Container(
              padding: const EdgeInsets.only(
                left: 10,
                top: 6,
                bottom: 6,
                right: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '地図をタップして測定地点を補正できます',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  GestureDetector(
                    onTap: _isSerialBusy
                        ? null
                        : () => setState(() => _showMapHint = false),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_correctingSpotId != null)
          Positioned(
            right: 12,
            bottom: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NudgeButton(
                  icon: Icons.arrow_upward,
                  onTap: () => _nudgeCorrectingSpot(latMeters: 0.5),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NudgeButton(
                      icon: Icons.arrow_back,
                      onTap: () => _nudgeCorrectingSpot(lngMeters: -0.5),
                    ),
                    const SizedBox(width: 48),
                    _NudgeButton(
                      icon: Icons.arrow_forward,
                      onTap: () => _nudgeCorrectingSpot(lngMeters: 0.5),
                    ),
                  ],
                ),
                _NudgeButton(
                  icon: Icons.arrow_downward,
                  onTap: () => _nudgeCorrectingSpot(latMeters: -0.5),
                ),
              ],
            ),
          ),
        Positioned(
          right: 12,
          bottom: 18,
          child: FloatingActionButton.small(
            heroTag: 'current_location_button',
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            onPressed: (_isFetchingCurrentLocation || _isSerialBusy)
                ? null
                : () => _fetchCurrentLocation(moveCamera: true),
            child: _isFetchingCurrentLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ),
        // 圃場内外ステータスの視覚フィードバック
        // _markerGeoStatus は毎回その時点の測定位置から計算されるため常に正確
        if (_markerGeoStatus != null && _correctingSpotId == null)
          Positioned(
            left: 12,
            right: 72,
            bottom: 72,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _markerGeoStatus == GeoFenceStatus.outside
                    ? Colors.red.withValues(alpha: 0.85)
                    : _markerGeoStatus == GeoFenceStatus.edge
                    ? Colors.orange.withValues(alpha: 0.85)
                    : Colors.green.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _markerGeoStatus == GeoFenceStatus.outside
                    ? '圃場外です。地点を圃場内に調整してください。'
                    : _markerGeoStatus == GeoFenceStatus.edge
                    ? '境界付近です。測定は可能です。'
                    : '圃場内',
                style: const TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (_isProvisionalFarm)
          Positioned(
            left: 12,
            right: 12,
            bottom: 72,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF0D8).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFB85C00)),
              ),
              child: const Text(
                '仮登録圃場（境界未設定）\n位置情報による圃場内外判定は行われません',
                style: TextStyle(
                  color: Color(0xFFB85C00),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  bool get _canStartMeasurement {
    return _isConnected &&
        _recallDone &&
        _bgDone &&
        _selectedFarm != null &&
        _effectiveMeasurementLocation != null &&
        !_isSerialBusy &&
        (_isProvisionalFarm || _markerGeoStatus != GeoFenceStatus.outside);
  }

  Widget _buildTopStatusBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: _FarmStatusChip(
              label: _selectedFarm?.farmName ?? '圃場を選択',
              isDone: _selectedFarm != null,
              isLoading: _isSelectingFarm,
              onTap: _isSerialBusy ? null : _openFarmSelection,
            ),
          ),
          const SizedBox(width: 8),
          _ActionStatusChip(
            label: _isConnected ? '接続中' : '接続',
            subLabel: _isConnected ? 'タップで切断' : 'センサ',
            isDone: _isConnected && _recallDone,
            isLoading: _isConnecting || _isRecalling,
            onTap: _isSerialBusy
                ? null
                : _isConnected
                ? _disconnect
                : _connect,
          ),
          const SizedBox(width: 8),
          _ActionStatusChip(
            label: _bgDone ? 'BG 再測定' : 'BG',
            subLabel: _bgDone ? 'タップで再測定' : '基準',
            isDone: _bgDone,
            isLoading: _bgIsMeasuring,
            onTap: (_isConnected && _recallDone && !_isSerialBusy)
                ? _startBg
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomMeasureButton() {
    final isCorrectingSpot = _correctingSpotId != null;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: isCorrectingSpot
                  ? const Color(0xFF2E5C39)
                  : _canStartMeasurement
                  ? const Color(0xFFB02020)
                  : Colors.grey.shade400,
              foregroundColor: Colors.white,
            ),
            onPressed: isCorrectingSpot && !_isSerialBusy
                ? _confirmPinCorrection
                : _canStartMeasurement
                ? _startMeasureSequence
                : null,
            icon: isCorrectingSpot
                ? const Icon(Icons.check)
                : _isMeasuring
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(
              isCorrectingSpot
                  ? '位置を確定'
                  : _isMeasuring
                  ? '測定中...'
                  : '測定開始',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmPinCorrection() async {
    if (_isSerialBusy) return;
    final spot = _spotById(_correctingSpotId);
    if (spot?.resultPointId != null) {
      try {
        await _resultsRepository.updateResultPointLocation(
          pointId: spot!.resultPointId!,
          lat: spot.position.latitude,
          lng: spot.position.longitude,
        );
        spot.createdAt = DateTime.now();
        await _loadTodayResultPinsForSelectedFarm();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_resultMutationErrorMessage(e))));
        return;
      }
    }
    _manualLocationHoldTimer?.cancel();
    final gpsLocation = _currentGpsLocation;
    setState(() {
      _correctingSpotId = null;
      _manualCorrectedLocation = null;
      if (gpsLocation != null) {
        _confirmedLocation = gpsLocation;
      }
    });
    _persistSessionState();
    _openMeasurementList();
  }

  Future<bool> _deleteSpots(int farmId, Set<String> ids) async {
    final selectedSpots = _mapSpots
        .where((spot) => ids.contains(spot.id))
        .toList(growable: false);
    if (selectedSpots.isEmpty) return false;

    final deletedNumbers = [
      for (final spot in selectedSpots)
        if (spot.measurementNumber != null) spot.measurementNumber!,
    ];
    _sessionState.markMeasurementNumbersDeleted(farmId, deletedNumbers);
    try {
      await _deletedMeasurementStore.add(
        farmId: farmId,
        dateIso: _todayJstIsoDate(),
        numbers: deletedNumbers,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('削除記録の保存に失敗しました: $e');
      }
    }

    for (final spot in selectedSpots) {
      if (spot.resultPointId != null) {
        _deletedPointIds[spot.resultPointId!] = DateTime.now();
      }
    }

    _sessionState._removePins(farmId, ids);
    setState(() {
      if (_activeSpot != null && ids.contains(_activeSpot!.id)) {
        _activeSpot = null;
      }
      if (_correctingSpotId != null && ids.contains(_correctingSpotId)) {
        _correctingSpotId = null;
        _manualCorrectedLocation = null;
      }
    });
    _persistSessionState();

    unawaited(_deleteLocalMeasurementRecords(farmId, selectedSpots));
    unawaited(_deleteCloudMeasurements(selectedSpots));
    return true;
  }

  Future<void> _deleteLocalMeasurementRecords(
    int farmId,
    List<_SpotProgress> spots,
  ) async {
    final fileBases = <String>{
      for (final spot in spots)
        if (spot.fileBase != null && spot.fileBase!.isNotEmpty) spot.fileBase!,
    };
    try {
      final pending = await _pendingUploadStore.listItems();
      final records = await _localMeasurementPinStore.loadForFarmOnDate(
        farmId: farmId,
        dateIso: _todayJstIsoDate(),
        pendingItems: pending,
      );
      final selectedIds = {for (final spot in spots) spot.id};
      final selectedNumbers = {
        for (final spot in spots)
          if (spot.measurementNumber != null) spot.measurementNumber!,
      };
      for (final record in records) {
        if (selectedIds.contains(record.id) ||
            (record.measurementNumber != null &&
                selectedNumbers.contains(record.measurementNumber))) {
          fileBases.add(record.fileBase);
        }
      }
      for (final item in pending) {
        if (item.farmId != farmId) continue;
        final localPinId = item.localPinId;
        if ((localPinId != null && selectedIds.contains(localPinId)) ||
            fileBases.contains(item.fileBase) ||
            (item.pointNumber != null &&
                selectedNumbers.contains(item.pointNumber))) {
          fileBases.add(item.fileBase);
          try {
            await _pendingUploadStore.removeByFileBase(item.fileBase);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('同期待ちキューの削除に失敗しました: $e');
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ローカル測定記録の特定に失敗しました: $e');
      }
    }
    for (final fileBase in fileBases) {
      await _deleteMeasurementFiles(fileBase);
    }
  }

  Future<void> _deleteMeasurementFiles(String fileBase) async {
    for (final file in [
      await MeasurementLocalPaths.csvFile(fileBase),
      await MeasurementLocalPaths.jsonFile(fileBase),
    ]) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('測定ファイルの削除に失敗しました: $fileBase $e');
        }
      }
    }
  }

  Future<void> _deleteCloudMeasurements(List<_SpotProgress> spots) async {
    for (final spot in spots) {
      final pointId = spot.resultPointId;
      if (pointId == null) continue;
      try {
        await _resultsRepository.deleteResultPoint(pointId);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('クラウド測定の削除に失敗しました: $pointId $e');
        }
      }
    }
  }

  void _openMeasurementList() {
    final farm = _selectedFarm;
    if (_isSerialBusy || farm == null) return;
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ListenableBuilder(
          listenable: _sessionState,
          builder: (context, __) => _MeasurementListScreen(
            spotsProvider: () => _mapSpots,
            onDeleteSpots: (ids) => _deleteSpots(farm.id, ids),
            onCorrectSpot: (spot) {
              _startPinCorrection(spot);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMeasurementProgressBar() {
    final progress = _currentMeasurementProgress;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 16,
              backgroundColor: Colors.grey.shade200,
              color: const Color(0xFF2E5C39),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSerialBusy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('測定'),
          actions: [
            IconButton(
              onPressed: _isSerialBusy ? null : _openSettings,
              icon: const Icon(Icons.settings),
              tooltip: '設定',
            ),
          ],
        ),
        body: Column(
          children: [
            _buildTopStatusBar(),
            if (_isShowingMeasurementProgress) _buildMeasurementProgressBar(),
            Expanded(child: _buildMeasureBody()),
            _buildBottomMeasureButton(),
          ],
        ),
      ),
    );
  }
}

class _FarmStatusChip extends StatelessWidget {
  const _FarmStatusChip({
    required this.label,
    required this.isDone,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final bool isDone;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isDone
        ? const Color(0xFF2E5C39)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final fg = isDone ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (isLoading) ...[
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                Icon(Icons.arrow_drop_down, size: 18, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionStatusChip extends StatelessWidget {
  const _ActionStatusChip({
    required this.label,
    required this.subLabel,
    required this.isDone,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final String subLabel;
  final bool isDone;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bg = isDone
        ? const Color(0xFF2E5C39)
        : enabled
        ? const Color(0xFF5A5A5A)
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final fg = isDone || enabled ? Colors.white : Colors.black45;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          width: 96,
          height: 50,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isDone ? '✓ $label' : label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        subLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.78),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: Colors.white.withValues(alpha: 0.94),
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 21, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}

class _MeasurementListScreen extends StatefulWidget {
  const _MeasurementListScreen({
    required this.spotsProvider,
    required this.onDeleteSpots,
    required this.onCorrectSpot,
  });

  final List<_SpotProgress> Function() spotsProvider;
  final Future<bool> Function(Set<String>) onDeleteSpots;
  final ValueChanged<_SpotProgress> onCorrectSpot;

  @override
  State<_MeasurementListScreen> createState() => _MeasurementListScreenState();
}

class _MeasurementListScreenState extends State<_MeasurementListScreen> {
  final Set<String> _selected = <String>{};

  Future<void> _confirmDeleteSelected() async {
    if (_selected.isEmpty) return;
    final count = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('測定データを削除'),
        content: Text('$count件のデータ点を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final deleted = await widget.onDeleteSpots(Set<String>.from(_selected));
    if (deleted && mounted) {
      setState(() => _selected.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    final spots = widget.spotsProvider();
    final spotIds = spots.map((spot) => spot.id).toSet();
    return Scaffold(
      appBar: AppBar(
        title: const Text('測定リスト'),
        backgroundColor: const Color(0xFF1A2318),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF5F5F0),
            child: Text(
              '全 ${spots.length} 件 / 表示 ${spots.length} 件',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ),
          Expanded(
            child: spots.isEmpty
                ? const Center(child: Text('測定ピンはありません'))
                : ListView.separated(
                    itemCount: spots.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final spot = spots[index];
                      final selected = _selected.contains(spot.id);
                      final spotNumber = spot.measurementNumber;
                      final numberLabel = spotNumber?.toString() ?? '?';
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selected.add(spot.id);
                            } else {
                              _selected.remove(spot.id);
                            }
                          });
                        },
                        secondary: CircleAvatar(
                          radius: 15,
                          backgroundColor: _spotColor(spot),
                          child: Text(
                            numberLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(_spotTitle(spot)),
                        subtitle: Text(
                          '${spot.position.latitude.toStringAsFixed(6)}, '
                          '${spot.position.longitude.toStringAsFixed(6)}\n'
                          '${_spotStatusLabel(spot)}',
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _selected.where(spotIds.contains).isEmpty
                        ? null
                        : _confirmDeleteSelected,
                    child: const Text('削除'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _selected.where(spotIds.contains).length == 1
                          ? () {
                              final selectedIds = _selected
                                  .where(spotIds.contains)
                                  .toList();
                              final spot = spots.firstWhere(
                                (spot) => spot.id == selectedIds.first,
                              );
                              widget.onCorrectSpot(spot);
                            }
                          : null,
                      child: const Text('位置を修正'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _spotColor(_SpotProgress spot) => measurementSpotColor(spot);

  String _spotStatusLabel(_SpotProgress spot) {
    if (spot.uploadDone) return '推定完了';
    if (spot.saveDone) return '保存済み';
    if (spot.failed) return 'エラー';
    return '${spot.percent}%';
  }

  String _spotTitle(_SpotProgress spot) {
    final created = spot.createdAt;
    final time =
        '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
    final numberLabel = spot.measurementNumber?.toString() ?? '?';
    return '測定点 $numberLabel / $time';
  }
}
