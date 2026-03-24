import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../data/measurement_upload_service.dart';

class MeasurementSettingsSheet extends StatelessWidget {
  final bool isConnected;
  final bool isMeasuring;
  final bool isUploading;

  final TextEditingController fstart;
  final TextEditingController fdelta;
  final TextEditingController points;
  final TextEditingController excite;
  final TextEditingController range;
  final TextEditingController integrate;
  final TextEditingController average;
  final TextEditingController note1;
  final TextEditingController note2;

  final String selectedSensor;
  final ValueChanged<String> onSensorChanged;

  final VoidCallback onSendId;
  final VoidCallback onSendList;
  final VoidCallback onSendStore;
  final VoidCallback onSendRecall;

  final TextEditingController logController;
  final ScrollController logScrollController;
  final TextEditingController uploadLogController;
  final ScrollController uploadLogScrollController;
  final UploadPhase uploadPhase;

  const MeasurementSettingsSheet({
    super.key,
    required this.isConnected,
    required this.isMeasuring,
    required this.isUploading,
    required this.fstart,
    required this.fdelta,
    required this.points,
    required this.excite,
    required this.range,
    required this.integrate,
    required this.average,
    required this.note1,
    required this.note2,
    required this.selectedSensor,
    required this.onSensorChanged,
    required this.onSendId,
    required this.onSendList,
    required this.onSendStore,
    required this.onSendRecall,
    required this.logController,
    required this.logScrollController,
    required this.uploadLogController,
    required this.uploadLogScrollController,
    required this.uploadPhase,
  });

  bool get _disableDuringSession => isMeasuring || isUploading;

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        enabled: enabled,
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
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            Row(
              children: [
                Text('詳細設定', style: theme.textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('閉じる'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  // ── 測定パラメータ ──
                  Text('測定パラメータ', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          '励起電圧[V]',
                          excite,
                          keyboardType: TextInputType.number,
                          enabled: !_disableDuringSession,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _field(
                          'レンジ[V]',
                          range,
                          keyboardType: TextInputType.number,
                          enabled: !_disableDuringSession,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          '積分時間[s]',
                          integrate,
                          keyboardType: TextInputType.number,
                          enabled: !_disableDuringSession,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _field(
                          '平均回数',
                          average,
                          keyboardType: TextInputType.number,
                          enabled: !_disableDuringSession,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          'fstart[Hz]',
                          fstart,
                          keyboardType: TextInputType.number,
                          enabled: !_disableDuringSession,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _field(
                          'fdelta[Hz]',
                          fdelta,
                          keyboardType: TextInputType.number,
                          enabled: !_disableDuringSession,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _field(
                          'points',
                          points,
                          keyboardType: TextInputType.number,
                          enabled: !_disableDuringSession,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── メモ ──
                  Text('メモ', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          'メモ1(半角英数10)',
                          note1,
                          enabled: !_disableDuringSession,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _field(
                          'メモ2(半角英数10)',
                          note2,
                          enabled: !_disableDuringSession,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ── センサー番号選択 ──
                  Text('センサー', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      DropdownButton<String>(
                        value: selectedSensor,
                        items: List.generate(
                          8,
                          (i) => DropdownMenuItem(value: '$i', child: Text('Sensor $i')),
                        ),
                        onChanged: _disableDuringSession
                            ? null
                            : (v) => onSensorChanged(v ?? '0'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // ── ID取得 / List / Store ──
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: (!isConnected || _disableDuringSession) ? null : onSendId,
                        child: const Text('ID取得'),
                      ),
                      OutlinedButton(
                        onPressed: (!isConnected || _disableDuringSession) ? null : onSendList,
                        child: const Text('List'),
                      ),
                      OutlinedButton(
                        onPressed: (!isConnected || _disableDuringSession) ? null : onSendStore,
                        child: const Text('Store'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // ── 応答ログ ──
                  Text('応答ログ', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: TextField(
                      controller: logController,
                      scrollController: logScrollController,
                      maxLines: null,
                      expands: true,
                      readOnly: true,
                      style: const TextStyle(fontSize: AppConstants.standardFontSize),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── アップロードログ ──
                  Text('アップロードログ（${uploadPhase.name}）', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: TextField(
                      controller: uploadLogController,
                      scrollController: uploadLogScrollController,
                      maxLines: null,
                      expands: true,
                      readOnly: true,
                      style: const TextStyle(fontSize: AppConstants.standardFontSize),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
