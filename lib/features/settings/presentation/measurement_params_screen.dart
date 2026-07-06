import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../measure/domain/measure_settings.dart';
import '../../measure/domain/measure_settings_store.dart';

class MeasurementParamsScreen extends StatefulWidget {
  const MeasurementParamsScreen({super.key});

  @override
  State<MeasurementParamsScreen> createState() =>
      _MeasurementParamsScreenState();
}

class _MeasurementParamsScreenState extends State<MeasurementParamsScreen> {
  final MeasureSettingsStore _store = MeasureSettingsStore();
  final _formKey = GlobalKey<FormState>();
  final _fstart = TextEditingController();
  final _fdelta = TextEditingController();
  final _points = TextEditingController();
  final _excite = TextEditingController();
  final _range = TextEditingController();
  final _integrate = TextEditingController();
  final _average = TextEditingController();
  String _selectedSensor = '0';
  bool _isLoading = true;

  static const _maxFrequencyHz = 1000000;
  static const _maxPoints = 2500;
  static const _allowedRanges = [0.5, 0.2, 0.1, 0.05, 0.02];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fstart.dispose();
    _fdelta.dispose();
    _points.dispose();
    _excite.dispose();
    _range.dispose();
    _integrate.dispose();
    _average.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final stored = await _store.load();
    if (!mounted) return;
    final settings = stored.settings;
    setState(() {
      _fstart.text = _formatIntLike(settings.fstart);
      _fdelta.text = _formatIntLike(settings.fdelta);
      _points.text = settings.points.toString();
      _excite.text = settings.excite.toString();
      _range.text = _normalizeRange(settings.range).toString();
      _integrate.text = settings.integrate.toString();
      _average.text = settings.average.toString();
      _selectedSensor = stored.selectedSensor;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('入力内容を確認してください')));
      return;
    }

    final settings = MeasureSettings(
      fstart: _parseInt(_fstart)!.toDouble(),
      fdelta: _parseInt(_fdelta)!.toDouble(),
      points: _parseInt(_points)!,
      excite: _parseDouble(_excite)!,
      range: _parseDouble(_range)!,
      integrate: _parseDouble(_integrate)!,
      average: _parseInt(_average)!,
    );
    await _store.save(
      StoredMeasureSettings(
        settings: settings,
        selectedSensor: _selectedSensor,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('測定条件を保存しました')));
  }

  String _formatIntLike(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toString();
  }

  double _normalizeRange(double value) {
    for (final allowed in _allowedRanges) {
      if ((value - allowed).abs() < 0.000001) return allowed;
    }
    return MeasureSettings.defaults.range;
  }

  int? _parseInt(TextEditingController controller) {
    return int.tryParse(controller.text.trim());
  }

  double? _parseDouble(TextEditingController controller) {
    return double.tryParse(controller.text.trim());
  }

  int? _endFrequencyHz() {
    final fstart = _parseInt(_fstart);
    final fdelta = _parseInt(_fdelta);
    final points = _parseInt(_points);
    if (fstart == null || fdelta == null || points == null) return null;
    return fstart + (fdelta * (points - 1));
  }

  String? _validateExcite(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null) return '数値で入力してください';
    if (parsed < 0 || parsed > 4.5) return '0〜4.5[V]の範囲で入力してください';
    return null;
  }

  String? _validateIntegrate(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null) return '数値で入力してください';
    if (parsed <= 0) return '0より大きい値を入力してください';
    final fstart = _parseInt(_fstart);
    if (fstart == null || fstart <= 0) return null;
    final minIntegrate = 10 / fstart;
    if (parsed < minIntegrate) {
      return '最低値は10/開始周波数 = ${minIntegrate.toStringAsPrecision(4)}[s]です';
    }
    return null;
  }

  String? _validateAverage(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null) return '整数で入力してください';
    if (parsed < 1) return '1以上を入力してください';
    return null;
  }

  String? _validateFstart(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null) return '整数で入力してください';
    if (parsed < 1 || parsed > _maxFrequencyHz) {
      return '1〜$_maxFrequencyHz[Hz]の範囲で入力してください';
    }
    return null;
  }

  String? _validateFdelta(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null) return '整数で入力してください';
    if (parsed < 1) return '1以上を入力してください';
    final endFrequency = _endFrequencyHz();
    if (endFrequency != null && endFrequency > _maxFrequencyHz) {
      return '終了周波数が1MHz以下になる値にしてください';
    }
    return null;
  }

  String? _validatePoints(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null) return '整数で入力してください';
    if (parsed < 1 || parsed > _maxPoints) {
      return '1〜$_maxPoints点の範囲で入力してください';
    }
    final endFrequency = _endFrequencyHz();
    if (endFrequency != null && endFrequency > _maxFrequencyHz) {
      return '終了周波数が1MHz以下になる点数にしてください';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('測定条件の設定'),
        backgroundColor: const Color(0xFF6B5C44),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionLabel('測定パラメータ'),
                  Row(
                    children: [
                      Expanded(
                        child: _decimalField(
                          label: '励起電圧[V]',
                          controller: _excite,
                          hintText: '0.5',
                          validator: _validateExcite,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: _rangeField()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _decimalField(
                          label: '積分時間[s]',
                          controller: _integrate,
                          hintText: '0.1',
                          validator: _validateIntegrate,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _integerField(
                          label: '平均回数',
                          controller: _average,
                          hintText: '1',
                          validator: _validateAverage,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('周波数パラメータ'),
                  Row(
                    children: [
                      Expanded(
                        child: _integerField(
                          label: '開始周波数[Hz]',
                          controller: _fstart,
                          hintText: '10000',
                          validator: _validateFstart,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _integerField(
                          label: '周波数増分[Hz]',
                          controller: _fdelta,
                          hintText: '1500',
                          validator: _validateFdelta,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _integerField(
                    label: '測定点数',
                    controller: _points,
                    hintText: '150',
                    validator: _validatePoints,
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel('センサー'),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSensor,
                    decoration: const InputDecoration(
                      labelText: 'センサー番号',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(
                      8,
                      (i) => DropdownMenuItem(
                        value: '$i',
                        child: Text('Sensor $i'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedSensor = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('保存'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _decimalField({
    required String label,
    required TextEditingController controller,
    required FormFieldValidator<String> validator,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: validator,
    );
  }

  Widget _integerField({
    required String label,
    required TextEditingController controller,
    required FormFieldValidator<String> validator,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: validator,
    );
  }

  Widget _rangeField() {
    final selectedRange = _normalizeRange(_parseDouble(_range) ?? 0);
    return DropdownButtonFormField<double>(
      initialValue: selectedRange,
      decoration: const InputDecoration(
        labelText: '入力レンジ[V]',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: _allowedRanges
          .map(
            (value) => DropdownMenuItem<double>(
              value: value,
              child: Text(value.toString()),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _range.text = value.toString());
      },
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF6B5C44),
        ),
      ),
    );
  }
}
