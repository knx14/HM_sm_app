import 'package:shared_preferences/shared_preferences.dart';

/// サウンド設定（測定完了音の再生可否）の永続化。
class SoundSettingsStore {
  static const _soundEnabledKey = 'sound_settings_enabled';
  static const bool defaultEnabled = true;

  Future<bool> loadSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundEnabledKey) ?? defaultEnabled;
  }

  Future<void> saveSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, enabled);
  }
}
