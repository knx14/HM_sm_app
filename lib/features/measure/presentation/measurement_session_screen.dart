import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';

import '../../../providers/user_provider.dart';
import '../../farms/domain/farm.dart';
import '../../../services/geo_service.dart';
import '../constants/app_constants.dart';
import '../data/local_save_service.dart';
import '../data/measurement_upload_service.dart';
import '../data/serial_comm_android.dart';
import '../domain/app_settings.dart';
import '../domain/chart_data.dart';
import '../domain/measure_settings.dart';
import '../domain/measurement_parser.dart';
import '../domain/measurement_service.dart';
import 'farm_select_screen.dart';
import 'location_confirm_screen.dart';
import 'measurement_settings_sheet.dart';
import 'widgets/measurement_chart.dart';
import 'widgets/step_indicator_bar.dart';

enum SessionStep { connect, bg, measure }

class MeasurementSessionScreen extends StatefulWidget {
  const MeasurementSessionScreen({super.key});

  @override
  State<MeasurementSessionScreen> createState() => _MeasurementSessionScreenState();
}

class _MeasurementSessionScreenState extends State<MeasurementSessionScreen> {
  final _logController = TextEditingController();
  final _logScrollController = ScrollController();
  final _uploadLogController = TextEditingController();
  final _uploadLogScrollController = ScrollController();

  final _fstart = TextEditingController(text: MeasureSettings.defaults.fstart.toString());
  final _fdelta = TextEditingController(text: MeasureSettings.defaults.fdelta.toString());
  final _points = TextEditingController(text: MeasureSettings.defaults.points.toString());
  final _excite = TextEditingController(text: MeasureSettings.defaults.excite.toString());
  final _range = TextEditingController(text: MeasureSettings.defaults.range.toString());
  final _integrate = TextEditingController(text: MeasureSettings.defaults.integrate.toString());
  final _average = TextEditingController(text: MeasureSettings.defaults.average.toString());

  final _note1 = TextEditingController();
  final _note2 = TextEditingController();

  final AppSettings _settings = AppSettings();

  bool _isConnected = false;
  bool _isMeasuring = false;
  int receivedPoints = 0;
  int totalPoints = AppConstants.defaultPointCount;
  double _progress = 0.0;
  String _selectedSensor = '0';
  String? _ampId;

  final List<ChartData> _chartData = [];

  Farm? _selectedFarm;
  UploadPhase _uploadPhase = UploadPhase.idle;
  // NOTE: upload_id等はログ本文に出すため、UIでの表示用途は持たない
  UploadResult? _lastUploadResult;

  LatLng? _confirmedLocation;
  GeoFenceStatus? _lastGeoStatus;

  SessionStep _currentStep = SessionStep.connect;

  // Auto recall state (Step1 -> Step2 transition)
  bool _isRecalling = false;
  bool _recallDone = false;
  Timer? _recallTimeoutTimer;

  // BG step state (UI-only; behavior matches BgScreen)
  bool _bgIsMeasuring = false;
  bool _bgDone = false;
  int _bgReceivedPoints = 0;
  int _bgTotalPoints = AppConstants.defaultPointCount;
  double _bgProgress = 0.0;

  TextStyle _getTextStyle() => const TextStyle(fontSize: AppConstants.standardFontSize);

  @override
  void initState() {
    super.initState();
    // 受信は SerialComm（HomeScreen互換の onReceive(data)）で扱う
    SerialComm.init(_onReceive);
    SerialComm.addDisconnectListener(_onUsbDisconnected);
  }

  @override
  void dispose() {
    _recallTimeoutTimer?.cancel();
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
    super.dispose();
  }

  void _onUsbDisconnected() {
    if (!mounted) return;
    _recallTimeoutTimer?.cancel();
    setState(() {
      _isConnected = false;
      _currentStep = SessionStep.connect;

      _isRecalling = false;
      _recallDone = false;

      _bgIsMeasuring = false;
      _bgDone = false;

      _isMeasuring = false;
      _progress = 0.0;
      _bgProgress = 0.0;
    });
    _appendLog('USBが切断されました。接続からやり直してください。\n');
  }

  void _appendLog(String text) {
    setState(() {
      _logController.text += text;
    });
  }

  void _appendUploadLog(String text) {
    setState(() {
      _uploadLogController.text += text.endsWith('\n') ? text : '$text\n';
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_uploadLogScrollController.hasClients) {
        _uploadLogScrollController.jumpTo(_uploadLogScrollController.position.maxScrollExtent);
      }
    });
  }

  bool get _isUploading =>
      _uploadPhase == UploadPhase.saving ||
      _uploadPhase == UploadPhase.initCalling ||
      _uploadPhase == UploadPhase.uploading ||
      _uploadPhase == UploadPhase.completing;

  int _pointsValue() => int.tryParse(_points.text.trim()) ?? MeasureSettings.defaults.points;
  double _fstartValue() => double.tryParse(_fstart.text.trim()) ?? MeasureSettings.defaults.fstart;
  double _fdeltaValue() => double.tryParse(_fdelta.text.trim()) ?? MeasureSettings.defaults.fdelta;
  double _exciteValue() => double.tryParse(_excite.text.trim()) ?? MeasureSettings.defaults.excite;
  double _rangeValue() => double.tryParse(_range.text.trim()) ?? MeasureSettings.defaults.range;
  double _integrateValue() => double.tryParse(_integrate.text.trim()) ?? MeasureSettings.defaults.integrate;
  int _averageValue() => int.tryParse(_average.text.trim()) ?? MeasureSettings.defaults.average;

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

  void _setupSerialComm() {
    // connect後にlistenerを確実に有効化
    SerialComm.init(_onReceive);
  }

  Future<void> _connect() async {
    final success = await SerialComm.connect();
    if (success) {
      _setupSerialComm();
    }
    setState(() {
      _isConnected = success;
      // Step1 stays on connect; transition to BG happens after recall ok.
      _currentStep = SessionStep.connect;
    });
    _appendLog(success
        ? '${AppConstants.messageConnectionSuccess}\n'
        : '${AppConstants.errorConnectionFailed}\n');

    if (success) {
      _startAutoRecall();
    }
  }

  void _startAutoRecall() {
    if (!_isConnected) return;

    // sensorNumber is fixed to 0 for now (spec)
    const sensorNumber = '0';
    _selectedSensor = sensorNumber;

    _recallTimeoutTimer?.cancel();
    setState(() {
      _isRecalling = true;
      _recallDone = false;
    });

    _appendLog('送信: condition recall $sensorNumber\n');
    MeasurementService.sendRecallCommand(sensorNumber);

    _recallTimeoutTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted) return;
      if (!_isRecalling) return;

      setState(() {
        _isRecalling = false;
        _recallDone = false;
        _currentStep = SessionStep.connect;
      });
      _appendLog('Recallタイムアウト（20秒）\n');
    });
  }

  void _disconnect() {
    SerialComm.disconnect();
    _recallTimeoutTimer?.cancel();
    setState(() {
      _isConnected = false;
      _currentStep = SessionStep.connect;
      _isRecalling = false;
      _recallDone = false;
      _bgIsMeasuring = false;
      _bgDone = false;
    });
    _appendLog('${AppConstants.messageDisconnected}\n');
  }

  void _sendIDCommand() {
    if (!_isConnected || _isMeasuring) return;
    MeasurementService.sendIdCommand();
  }

  void _sendListCommand() {
    if (!_isConnected || _isMeasuring) return;
    MeasurementService.sendListCommand();
  }

  void _sendStoreCommand() {
    if (!_isConnected || _isMeasuring) return;
    MeasurementService.sendStoreCommand(_selectedSensor);
  }

  void _sendrecallCommand() {
    if (!_isConnected || _isMeasuring) return;
    MeasurementService.sendListCommand();

    // リスト応答を待って設定値を解析・適用
    Future.delayed(const Duration(milliseconds: 300), () {
      final lines = _logController.text.split('\n');
      for (final line in lines) {
        if (line.trim().startsWith(_selectedSensor)) {
          final parts = line.trim().split(RegExp(r'\s+'));
          if (parts.length >= 8) {
            setState(() {
              _fstart.text = parts[1];
              _fdelta.text = parts[2];
              _points.text = parts[3];
              _excite.text = parts[4];
              _range.text = parts[5];
              _integrate.text = parts[6];
              _average.text = parts[7];
            });
          }
        }
      }
      MeasurementService.sendRecallCommand(_selectedSensor);
    });
  }

  void _startBg() {
    if (!_isConnected) {
      _appendLog('${AppConstants.errorConnectFirst}\n');
      return;
    }
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

    _appendLog(
      '送信: null ${_settings.excite} ${_settings.range} ${_settings.integrate} ${_settings.average}\n',
    );
    MeasurementService.sendBgMeasurementCommand(_settings);
  }

  Future<void> _startExec() async {
    if (!_isConnected) {
      _appendLog('${AppConstants.errorConnectFirst}\n');
      return;
    }
    _updateSettings();
    final settings = _settings;
    if (settings.points <= 0) {
      _appendLog('${AppConstants.errorPointsInvalid}\n');
      return;
    }

    setState(() {
      _chartData.clear();
      _logController.clear();
      receivedPoints = 0;
      _progress = 0.0;
      _isMeasuring = true;
      totalPoints = int.tryParse(_points.text) ?? AppConstants.defaultPointCount;
    });

    MeasurementService.sendMeasurementCommand(settings);
  }

  Future<Farm?> _selectFarm() async {
    final farm = await Navigator.push<Farm>(
      context,
      MaterialPageRoute(builder: (_) => const FarmSelectScreen()),
    );
    if (!mounted) return null;
    if (farm != null) {
      setState(() => _selectedFarm = farm);
    }
    return farm;
  }

  Future<void> _confirmLocationAndStartExec() async {
    if (_isMeasuring) return;
    final farm = _selectedFarm ?? await _selectFarm();
    if (!mounted) return;
    if (farm == null) {
      _appendLog('圃場選択がキャンセルされました\n');
      return;
    }

    final result = await Navigator.push<LocationConfirmResult>(
      context,
      MaterialPageRoute(builder: (_) => LocationConfirmScreen(farm: farm)),
    );
    if (!mounted) return;
    if (result == null) {
      _appendLog('地点確定がキャンセルされました\n');
      return;
    }

    setState(() {
      _confirmedLocation = result.confirmedLocation;
      _lastGeoStatus = result.status;
    });

    await _startExec();
  }

  Future<void> _save() async {
    final userId = context.read<UserProvider>().userId;
    if (userId == null || userId.trim().isEmpty) {
      _appendLog('ユーザIDが未設定のため保存できません\n');
      return;
    }

    final note1 = _note1.text.trim();
    final note2 = _note2.text.trim();
    if (!LocalSaveService.isValidMemo(note1) || !LocalSaveService.isValidMemo(note2)) {
      _appendLog('${AppConstants.errorInvalidMemoFormat}\n');
      return;
    }

    try {
      final fileBase = await LocalSaveService.saveMeasurement(
        chartData: List<ChartData>.from(_chartData),
        userId: userId,
        note1: note1,
        note2: note2,
        settings: _currentSettings(),
        ampId: _ampId,
        latitude: _confirmedLocation?.latitude,
        longitude: _confirmedLocation?.longitude,
      );
      _appendLog('保存完了: $fileBase\n');
    } catch (e) {
      _appendLog('保存エラー: $e\n');
    }
  }

  Future<void> _saveAndUpload() async {
    if (_isMeasuring || _isUploading) return;

    final userId = context.read<UserProvider>().userId;
    if (userId == null || userId.trim().isEmpty) {
      _appendUploadLog('error: ユーザIDが未設定のためアップロードできません');
      return;
    }
    if (_chartData.isEmpty) {
      _appendUploadLog('error: アップロードするデータがありません');
      return;
    }

    final note1 = _note1.text.trim();
    final note2 = _note2.text.trim();
    if (!LocalSaveService.isValidMemo(note1) || !LocalSaveService.isValidMemo(note2)) {
      _appendUploadLog('error: ${AppConstants.errorInvalidMemoFormat}');
      return;
    }

    final farm = _selectedFarm ?? await _selectFarm();
    if (!mounted) return;
    if (farm == null) {
      _appendUploadLog('error: 圃場が未選択です');
      return;
    }

    setState(() {
      _uploadPhase = UploadPhase.saving;
      _lastUploadResult = null;
      _uploadLogController.clear();
    });

    try {
      _appendUploadLog('save: start');
      final fileBase = await LocalSaveService.saveMeasurement(
        chartData: List<ChartData>.from(_chartData),
        userId: userId,
        note1: note1,
        note2: note2,
        settings: _currentSettings(),
        ampId: _ampId,
        latitude: _confirmedLocation?.latitude,
        longitude: _confirmedLocation?.longitude,
      );
      _appendUploadLog('save: ok $fileBase');

      final dir = await getApplicationDocumentsDirectory();
      final csvFile = File('${dir.path}/$fileBase.csv');
      final jsonFile = File('${dir.path}/$fileBase.json');

      final measurementParameters =
          jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
      final measurementDate =
          (measurementParameters['timestamp'] as String?) ?? DateTime.now().toIso8601String();

      final uploader = MeasurementUploadService();
      final result = await uploader.uploadCsvWithInitComplete(
        farmId: farm.id,
        csvFile: csvFile,
        measurementParameters: measurementParameters,
        measurementDate: measurementDate,
        note1: note1.isEmpty ? null : note1,
        note2: note2.isEmpty ? null : note2,
        cultivationType: null,
        onPhase: (p) {
          if (!mounted) return;
          setState(() => _uploadPhase = p);
        },
        onLog: (m) {
          if (!mounted) return;
          _appendUploadLog(m);
        },
      );

      if (!mounted) return;
      setState(() {
        _lastUploadResult = result;
        _uploadPhase = UploadPhase.done;
      });
      _appendUploadLog('done: upload_id=${result.uploadId} (受付完了: 処理中)');
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadPhase = UploadPhase.error);
      _appendUploadLog('error: $e');
    }
  }

  // ignore: unused_element
  UploadResult? get _unusedLastUploadResult => _lastUploadResult;

  void _onReceive(String data) {
    if (!mounted) return;

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
        }

        if (MeasurementParser.isOkLine(line)) {
          // Step1: auto recall completed -> move to BG
          if (_isRecalling) {
            _recallTimeoutTimer?.cancel();
            _isRecalling = false;
            _recallDone = true;
            _currentStep = SessionStep.bg;
            continue;
          }

          // Step2: BG completed -> move to measure
          if (_currentStep == SessionStep.bg && _bgIsMeasuring) {
            _bgIsMeasuring = false;
            _bgDone = true;
            _currentStep = SessionStep.measure;
            continue;
          }

          // Step3: exec completed
          if (_currentStep == SessionStep.measure && _isMeasuring) {
            _isMeasuring = false;
            _progress = 1.0;
            receivedPoints = totalPoints;
            continue;
          }
        } else if (MeasurementParser.isErrorLine(line)) {
          if (_isRecalling) {
            _recallTimeoutTimer?.cancel();
            _isRecalling = false;
            _recallDone = false;
            _currentStep = SessionStep.connect;
            _logController.text += 'Recallに失敗しました\n';
            continue;
          }

          if (_currentStep == SessionStep.bg && _bgIsMeasuring) {
            _bgIsMeasuring = false;
            _logController.text += 'BG測定中にエラーが発生しました\n';
            continue;
          }

          if (_currentStep == SessionStep.measure && _isMeasuring) {
            _isMeasuring = false;
            _logController.text += '測定中にエラーが発生しました\n';
            continue;
          }
        }

        // BG progress (required)
        if (_currentStep == SessionStep.bg && _bgIsMeasuring && line.startsWith('*')) {
          _bgReceivedPoints++;
          _bgProgress = (_bgReceivedPoints / _bgTotalPoints).clamp(0.0, 1.0);
          continue;
        }

        // Exec progress + plot
        if (_currentStep == SessionStep.measure && _isMeasuring && line.startsWith('*')) {
          final idx = receivedPoints;
          final freq = _fstartValue() + (_fdeltaValue() * idx);
          final point = MeasurementParser.tryParseExecDataLine(line, frequency: freq);
          if (point != null) {
            _chartData.add(point);
          }
          receivedPoints++;
          _progress = (receivedPoints / totalPoints).clamp(0.0, 1.0);
        }
      }
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_logScrollController.hasClients) {
        _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
      }
    });
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
            isMeasuring: _isMeasuring,
            isUploading: _isUploading,
            selectedFarm: _selectedFarm,
            onSelectFarm: () {
              Navigator.pop(sheetContext);
              _selectFarm();
            },
            fstart: _fstart,
            fdelta: _fdelta,
            points: _points,
            excite: _excite,
            range: _range,
            integrate: _integrate,
            average: _average,
            note1: _note1,
            note2: _note2,
            selectedSensor: _selectedSensor,
            onSensorChanged: (v) => setState(() => _selectedSensor = v),
            onSendId: _sendIDCommand,
            onSendList: _sendListCommand,
            onSendStore: _sendStoreCommand,
            onSendRecall: _sendrecallCommand,
            logController: _logController,
            logScrollController: _logScrollController,
            lastGeoStatus: _lastGeoStatus,
          ),
        );
      },
    );
  }

  Widget _stepBodyTitle(BuildContext context, String title, String description) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(description, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _standardLogField({
    required TextEditingController controller,
    required ScrollController scrollController,
    required String label,
  }) {
    return TextField(
      controller: controller,
      scrollController: scrollController,
      readOnly: true,
      maxLines: AppConstants.logAreaMaxLines,
      style: _getTextStyle(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _getTextStyle(),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
    );
  }

  // upload log UI is rendered via the same TextField design as response log

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(''),
        actions: [
          IconButton(
            onPressed: (_isMeasuring || _bgIsMeasuring || _isUploading || _isRecalling) ? null : _openSettings,
            icon: const Icon(Icons.settings),
            tooltip: '設定',
          ),
        ],
      ),
      body: Column(
        children: [
          StepIndicatorBar(
            currentStep: _currentStep,
            isStep1Done: _isConnected && _recallDone,
            isBgDone: _bgDone,
          ),

          // Step bodies (only one visible)
          if (_currentStep == SessionStep.connect) ...[
            Expanded(
              child: Column(
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _stepBodyTitle(context, 'Step 1: 接続', ''),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton(
                                onPressed: _isConnected ? null : _connect,
                                child: const Text('接続'),
                              ),
                              ElevatedButton(
                                onPressed: (!_isConnected || _isMeasuring || _isRecalling) ? null : _disconnect,
                                child: const Text('切断'),
                              ),
                              OutlinedButton(
                                onPressed: (!_isConnected || _isRecalling || _recallDone) ? null : _startAutoRecall,
                                child: const Text('Recall再試行'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_isConnected) ...[
                            Text(
                              _isRecalling
                                  ? 'Recall実行中…（最大20秒）'
                                  : _recallDone
                                      ? 'Recall完了（OK）'
                                      : 'Recall未完了',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _standardLogField(
                        controller: _logController,
                        scrollController: _logScrollController,
                        label: '応答ログ',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_currentStep == SessionStep.bg) ...[
            Expanded(
              child: Column(
                children: [
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _stepBodyTitle(context, 'Step 2: BG測定（必須）', '完了後に本測定へ進みます。'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton(
                                onPressed: _bgIsMeasuring ? null : _startBg,
                                child: const Text('BG測定開始'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearPercentIndicator(
                            lineHeight: AppConstants.progressBarHeight,
                            percent: _bgProgress.clamp(0.0, 1.0),
                            center: Text('${(_bgProgress * 100).toStringAsFixed(0)}%'),
                            backgroundColor: Colors.grey[300],
                            progressColor: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: _standardLogField(
                        controller: _logController,
                        scrollController: _logScrollController,
                        label: '応答ログ',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_currentStep == SessionStep.measure) ...[
            Expanded(
              child: Column(
                children: [
                  // 上部の説明/開始/進捗（必要ならスクロール可）
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _stepBodyTitle(context, 'Step 3: 本測定', '地点確定のあと測定を開始し、アップロードできます。'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton(
                                onPressed: _isMeasuring ? null : _confirmLocationAndStartExec,
                                child: const Text('測定地点選択'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearPercentIndicator(
                            lineHeight: AppConstants.progressBarHeight,
                            percent: _progress.clamp(0.0, 1.0),
                            center: Text('${(_progress * 100).toStringAsFixed(0)}%'),
                            backgroundColor: Colors.grey[300],
                            progressColor: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  // 保存/アップロードはタブ（Log/Plot）に関係なく常に見える位置に固定
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton(
                              onPressed: (_chartData.isNotEmpty && !_isMeasuring) ? _save : null,
                              child: const Text('保存'),
                            ),
                            ElevatedButton(
                              onPressed: (_chartData.isNotEmpty && !_isMeasuring && !_isUploading)
                                  ? _saveAndUpload
                                  : null,
                              child: const Text('アップロード'),
                            ),
                          ],
                        ),
                        if (_uploadPhase == UploadPhase.done) ...[
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: (_isMeasuring || _isUploading) ? null : _confirmLocationAndStartExec,
                            child: const Text('続けて測定'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _standardLogField(
                            controller: _logController,
                            scrollController: _logScrollController,
                            label: '応答ログ',
                          ),
                          const SizedBox(height: 12),
                          _standardLogField(
                            controller: _uploadLogController,
                            scrollController: _uploadLogScrollController,
                            label: 'アップロードログ',
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 420,
                            child: MeasurementChart(
                              chartData: _chartData,
                              initialMode: GraphMode.complex,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

