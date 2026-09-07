import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../../settings/domain/sound_settings_store.dart';

/// 測定完了音の再生を担当する。
///
/// 再生直前にサウンド設定を読み込むため、設定画面での変更は
/// 測定画面を開き直さなくても次回の再生から反映される。
class MeasurementSoundService {
  MeasurementSoundService({SoundSettingsStore? settingsStore})
    : _settingsStore = settingsStore ?? SoundSettingsStore();

  static const String _completionAsset = 'sounds/measurement_complete.wav';

  final SoundSettingsStore _settingsStore;
  final AudioPlayer _player = AudioPlayer();

  Future<void> playMeasurementComplete() async {
    try {
      if (!await _settingsStore.loadSoundEnabled()) return;
      await _player.stop();
      await _player.play(AssetSource(_completionAsset));
    } catch (e) {
      // 再生失敗は測定フローを中断させない。
      debugPrint('測定完了音の再生に失敗しました: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _player.dispose();
    } catch (e) {
      debugPrint('測定完了音プレイヤーの破棄に失敗しました: $e');
    }
  }
}
