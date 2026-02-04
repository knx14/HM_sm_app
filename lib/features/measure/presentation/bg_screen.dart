import 'package:flutter/material.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../constants/app_constants.dart';
import '../data/serial_comm_android.dart';
import '../domain/app_settings.dart';
import '../domain/measurement_parser.dart';
import '../domain/measurement_service.dart';

/// BG（null測定）画面
class BgScreen extends StatefulWidget {
  const BgScreen({super.key});

  @override
  State<BgScreen> createState() => _BgScreenState();
}

class _BgScreenState extends State<BgScreen> {
  final TextEditingController _logController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();

  final _points = TextEditingController(text: AppConstants.defaultPointCount.toString());
  final _integrate = TextEditingController(text: '0.1');
  final _average = TextEditingController(text: '1');

  final AppSettings _settings = AppSettings();

  double _progress = 0.0;
  int totalPoints = AppConstants.defaultPointCount;
  int receivedPoints = 0;
  bool _isMeasuring = false;

  @override
  void initState() {
    super.initState();
    SerialComm.init(_onReceive);
  }

  @override
  void dispose() {
    SerialComm.removeListener(_onReceive);
    _logController.dispose();
    _logScrollController.dispose();
    _points.dispose();
    _integrate.dispose();
    _average.dispose();
    super.dispose();
  }

  void _appendLog(String text) {
    setState(() {
      _logController.text += text;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_logScrollController.hasClients) {
        _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
      }
    });
  }

  void _updateSettings() {
    _settings.update(
      points: int.tryParse(_points.text),
      integrate: double.tryParse(_integrate.text),
      average: int.tryParse(_average.text),
    );
  }

  void _sendBgCommand() {
    _updateSettings();
    setState(() {
      _progress = 0.0;
      _logController.clear();
      receivedPoints = 0;
      totalPoints = _settings.points;
      _isMeasuring = true;
    });

    // BG測定開始
    _appendLog('送信: null ${_settings.excite} ${_settings.range} ${_settings.integrate} ${_settings.average}\n');
    MeasurementService.sendBgMeasurementCommand(_settings);
  }

  void _onReceive(String data) {
    if (!mounted) return;

    setState(() {
      _logController.text += data;

      final newLines = data.split('\n');
      for (var line in newLines) {
        line = line.trim();
        if (line.isEmpty) continue;

        if (line.startsWith('*')) {
          receivedPoints++;
          _progress = (receivedPoints / totalPoints).clamp(0.0, 1.0);
        }

        if (MeasurementParser.isOkLine(line)) {
          _isMeasuring = false;
          _progress = 1.0;
          receivedPoints = totalPoints;
        } else if (MeasurementParser.isErrorLine(line)) {
          _isMeasuring = false;
          _logController.text += '${AppConstants.errorMeasurementFailed}\n';
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isMeasuring,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('BG測定'),
          automaticallyImplyLeading: !_isMeasuring,
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(child: _field('測定点数(points)', _points, keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: _field('積分[s]', _integrate, keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: _field('平均回数', _average, keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isMeasuring ? null : _sendBgCommand,
                child: const Text('BG測定'),
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
              const SizedBox(height: 6),
              LinearPercentIndicator(
                lineHeight: AppConstants.progressBarHeight,
                percent: _progress.clamp(0.0, 1.0),
                center: Text('${(_progress * 100).toStringAsFixed(0)}%'),
                backgroundColor: Colors.grey[300],
                progressColor: Colors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

