import 'package:shared_preferences/shared_preferences.dart';

import 'measure_settings.dart';

class StoredMeasureSettings {
  const StoredMeasureSettings({
    required this.settings,
    required this.selectedSensor,
  });

  final MeasureSettings settings;
  final String selectedSensor;
}

class MeasureSettingsStore {
  static const _fstartKey = 'measure_settings_fstart';
  static const _fdeltaKey = 'measure_settings_fdelta';
  static const _pointsKey = 'measure_settings_points';
  static const _exciteKey = 'measure_settings_excite';
  static const _rangeKey = 'measure_settings_range';
  static const _integrateKey = 'measure_settings_integrate';
  static const _averageKey = 'measure_settings_average';
  static const _selectedSensorKey = 'measure_settings_selected_sensor';

  Future<StoredMeasureSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = MeasureSettings.defaults;
    return StoredMeasureSettings(
      settings: MeasureSettings(
        fstart: prefs.getDouble(_fstartKey) ?? defaults.fstart,
        fdelta: prefs.getDouble(_fdeltaKey) ?? defaults.fdelta,
        points: prefs.getInt(_pointsKey) ?? defaults.points,
        excite: prefs.getDouble(_exciteKey) ?? defaults.excite,
        range: prefs.getDouble(_rangeKey) ?? defaults.range,
        integrate: prefs.getDouble(_integrateKey) ?? defaults.integrate,
        average: prefs.getInt(_averageKey) ?? defaults.average,
      ),
      selectedSensor: prefs.getString(_selectedSensorKey) ?? '0',
    );
  }

  Future<void> save(StoredMeasureSettings value) async {
    final prefs = await SharedPreferences.getInstance();
    final settings = value.settings;
    await Future.wait([
      prefs.setDouble(_fstartKey, settings.fstart),
      prefs.setDouble(_fdeltaKey, settings.fdelta),
      prefs.setInt(_pointsKey, settings.points),
      prefs.setDouble(_exciteKey, settings.excite),
      prefs.setDouble(_rangeKey, settings.range),
      prefs.setDouble(_integrateKey, settings.integrate),
      prefs.setInt(_averageKey, settings.average),
      prefs.setString(_selectedSensorKey, value.selectedSensor),
    ]);
  }
}
