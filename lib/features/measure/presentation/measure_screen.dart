import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import '../../../providers/user_provider.dart';
import '../constants/app_constants.dart';
import '../data/local_save_service.dart';
import '../data/measurement_upload_service.dart';
import '../data/serial_comm_android.dart';
import '../domain/chart_data.dart';
import '../domain/app_settings.dart';
import '../domain/measure_settings.dart';
import '../domain/measurement_service.dart';
import '../domain/measurement_parser.dart';
import 'bg_screen.dart';
import 'farm_select_screen.dart';
import 'widgets/measurement_chart.dart';
import '../../farms/domain/farm.dart';

class MeasureScreen extends StatefulWidget {
  const MeasureScreen({super.key});

  @override
  State<MeasureScreen> createState() => _MeasureScreenState();
}

enum MeasureOp { idle, zero, exec }

class _MeasureScreenState extends State<MeasureScreen> {
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
  MeasureOp _currentOp = MeasureOp.idle;

  final List<ChartData> _chartData = [];

  Farm? _selectedFarm;
  UploadPhase _uploadPhase = UploadPhase.idle;
  UploadResult? _lastUploadResult;

  @override
  void initState() {
    super.initState();
    // 受信は SerialComm（HomeScreen互換の onReceive(data)）で扱う
    SerialComm.init(_onReceive);
  }

  @override
  void dispose() {
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
    });
    _appendLog(success
        ? '${AppConstants.messageConnectionSuccess}\n'
        : '${AppConstants.errorConnectionFailed}\n');
  }

  void _disconnect() {
    SerialComm.disconnect();
    setState(() {
      _isConnected = false;
      _currentOp = MeasureOp.idle;
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

  void _sendZeroCommand(AppSettings settings) {
    _updateSettings();
    setState(() {
      _logController.clear();
      _progress = 0.0;
      receivedPoints = 0;
      totalPoints = int.tryParse(_points.text) ?? AppConstants.defaultPointCount;
      _currentOp = MeasureOp.zero;
    });

    final cmd = settings.getZeroCommand();
    _appendLog('送信: $cmd\n');
    MeasurementService.sendZeroCommand(settings);
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
      _currentOp = MeasureOp.exec;
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

  Future<void> _selectFarmAndStartExec() async {
    if (_isMeasuring) return;
    final farm = await _selectFarm();
    if (!mounted) return;
    if (farm == null) {
      _appendLog('圃場選択がキャンセルされました\n');
      return;
    }
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

        // 進捗カウント: Zeroは「&」, 測定(exec)は「*」(正解実装準拠)
        final isZeroPoint = _currentOp == MeasureOp.zero && line.startsWith('&');
        final isExecPoint = _currentOp != MeasureOp.zero && line.startsWith('*');
        if (isZeroPoint || isExecPoint) {
          if (isExecPoint) {
            final idx = receivedPoints;
            final freq = _fstartValue() + (_fdeltaValue() * idx);
            final point = MeasurementParser.tryParseExecDataLine(line, frequency: freq);
            if (point != null) {
              _chartData.add(point);
            }
          }
          receivedPoints++;
          _progress = (receivedPoints / totalPoints).clamp(0.0, 1.0);
        }

        if (MeasurementParser.isOkLine(line)) {
          _isMeasuring = false;
          _progress = 1.0;
          receivedPoints = totalPoints;
          _currentOp = MeasureOp.idle;
        } else if (MeasurementParser.isErrorLine(line)) {
          _isMeasuring = false;
          _logController.text += '測定中にエラーが発生しました\n';
          _currentOp = MeasureOp.idle;
        }
      }
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_logScrollController.hasClients) {
        _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
      }
    });
  }

  Widget _field(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('測定')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            // 問題点1: 接続状態表示は不要のため削除
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              child: ListTile(
                title: const Text('選択圃場'),
                subtitle: Text(
                  _selectedFarm == null
                      ? '未選択（測定ボタン押下で選択画面へ）'
                      : '${_selectedFarm!.farmName} (ID: ${_selectedFarm!.id})',
                ),
                trailing: TextButton(
                  onPressed: _isMeasuring ? null : _selectFarm,
                  child: const Text('変更'),
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isConnected ? null : _connect,
                  child: const Text('接続'),
                ),
                ElevatedButton(
                  onPressed: (!_isConnected || _isMeasuring) ? null : _disconnect,
                  child: const Text('切断'),
                ),
                ElevatedButton(
                  onPressed: (!_isConnected || _isMeasuring) ? null : _sendIDCommand,
                  child: const Text('ID取得'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field('励起[V]', _excite, keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _field('レンジ[V]', _range, keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _field('積分[s]', _integrate, keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _field('平均回数', _average, keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _field('fstart[Hz]', _fstart, keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _field('fdelta[Hz]', _fdelta, keyboardType: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _field('points', _points, keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _field('メモ1(半角英数10)', _note1)),
                const SizedBox(width: 8),
                Expanded(child: _field('メモ2(半角英数10)', _note2)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _selectedSensor,
                  items: List.generate(
                    8,
                    (i) => DropdownMenuItem(value: '$i', child: Text('Sensor $i')),
                  ),
                  onChanged: _isMeasuring ? null : (v) => setState(() => _selectedSensor = v ?? '0'),
                ),
                ElevatedButton(
                  onPressed: (!_isConnected || _isMeasuring) ? null : () => _sendZeroCommand(_settings),
                  child: const Text('Zeroバランス'),
                ),
                ElevatedButton(
                  onPressed: (!_isConnected || _isMeasuring) ? null : _sendStoreCommand,
                  child: const Text('Store'),
                ),
                ElevatedButton(
                  onPressed: (!_isConnected || _isMeasuring) ? null : _sendrecallCommand,
                  child: const Text('Recall'),
                ),
                ElevatedButton(
                  onPressed: (!_isConnected || _isMeasuring) ? null : _sendListCommand,
                  child: const Text('List'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isMeasuring ? null : _selectFarmAndStartExec,
                  child: const Text('測定'),
                ),
                ElevatedButton(
                  onPressed: _isMeasuring
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BgScreen()),
                          ),
                  child: const Text('BG測定'),
                ),
                ElevatedButton(
                  onPressed: (_chartData.isNotEmpty && !_isMeasuring) ? _save : null,
                  child: const Text('保存'),
                ),
                ElevatedButton(
                  onPressed: (_chartData.isNotEmpty && !_isMeasuring && !_isUploading)
                      ? _saveAndUpload
                      : null,
                  child: const Text('保存＆アップロード'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearPercentIndicator(
              lineHeight: AppConstants.progressBarHeight,
              percent: _progress.clamp(0.0, 1.0),
              center: Text('${(_progress * 100).toStringAsFixed(0)}%'),
              backgroundColor: Colors.grey[300],
              progressColor: Colors.teal,
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _logController,
              scrollController: _logScrollController,
              maxLines: AppConstants.logAreaMaxLines,
              readOnly: true,
              style: const TextStyle(fontSize: AppConstants.standardFontSize),
              decoration: const InputDecoration(
                labelText: '応答ログ',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _uploadLogController,
              scrollController: _uploadLogScrollController,
              maxLines: 6,
              readOnly: true,
              style: const TextStyle(fontSize: AppConstants.standardFontSize),
              decoration: InputDecoration(
                labelText: 'アップロードログ（${_uploadPhase.name}）',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                helperText: _lastUploadResult == null ? null : 'upload_id=${_lastUploadResult!.uploadId}',
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 320,
              child: MeasurementChart(
                chartData: _chartData,
                initialMode: GraphMode.complex,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
