import 'package:shared_preferences/shared_preferences.dart';

/// データ同期方式。
enum SyncMode {
  /// 測定完了後すぐにクラウドへ送信し、推定結果まで取得する（従来動作）。
  auto,

  /// 測定データは端末に保存のみ行い、同期画面からユーザーが手動で送信する。
  manual,
}

class SyncSettingsStore {
  static const _syncModeKey = 'sync_settings_mode';

  Future<SyncMode> loadSyncMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_syncModeKey);
    for (final mode in SyncMode.values) {
      if (mode.name == raw) return mode;
    }
    return SyncMode.auto;
  }

  Future<void> saveSyncMode(SyncMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncModeKey, mode.name);
  }
}
