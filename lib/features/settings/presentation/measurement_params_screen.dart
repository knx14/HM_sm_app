import 'package:flutter/material.dart';

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
  final _fstart = TextEditingController();
  final _fdelta = TextEditingController();
  final _points = TextEditingController();
  final _excite = TextEditingController();
  final _range = TextEditingController();
  final _integrate = TextEditingController();
  final _average = TextEditingController();
  String _selectedSensor = '0';
  bool _isLoading = true;

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
      _fstart.text = settings.fstart.toString();
      _fdelta.text = settings.fdelta.toString();
      _points.text = settings.points.toString();
      _excite.text = settings.excite.toString();
      _range.text = settings.range.toString();
      _integrate.text = settings.integrate.toString();
      _average.text = settings.average.toString();
      _selectedSensor = stored.selectedSensor;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    final defaults = MeasureSettings.defaults;
    final settings = MeasureSettings(
      fstart: double.tryParse(_fstart.text.trim()) ?? defaults.fstart,
      fdelta: double.tryParse(_fdelta.text.trim()) ?? defaults.fdelta,
      points: int.tryParse(_points.text.trim()) ?? defaults.points,
      excite: double.tryParse(_excite.text.trim()) ?? defaults.excite,
      range: double.tryParse(_range.text.trim()) ?? defaults.range,
      integrate: double.tryParse(_integrate.text.trim()) ?? defaults.integrate,
      average: int.tryParse(_average.text.trim()) ?? defaults.average,
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionLabel('測定パラメータ'),
                Row(
                  children: [
                    Expanded(child: _field('励起電圧[V]', _excite)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('レンジ[V]', _range)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _field('積分時間[s]', _integrate)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('平均回数', _average)),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionLabel('周波数パラメータ'),
                Row(
                  children: [
                    Expanded(child: _field('fstart[Hz]', _fstart)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('fdelta[Hz]', _fdelta)),
                  ],
                ),
                const SizedBox(height: 8),
                _field('points', _points),
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
                    (i) =>
                        DropdownMenuItem(value: '$i', child: Text('Sensor $i')),
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
    );
  }

  Widget _field(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
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
