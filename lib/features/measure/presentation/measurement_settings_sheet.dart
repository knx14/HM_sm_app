import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../data/measurement_upload_service.dart';

class MeasurementSettingsSheet extends StatelessWidget {
  final bool isConnected;
  final bool isMeasuring;
  final bool isUploading;

  final VoidCallback onSendId;
  final VoidCallback onSendList;
  final VoidCallback onSendStore;

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
    required this.onSendId,
    required this.onSendList,
    required this.onSendStore,
    required this.logController,
    required this.logScrollController,
    required this.uploadLogController,
    required this.uploadLogScrollController,
    required this.uploadPhase,
  });

  bool get _disableDuringSession => isMeasuring || isUploading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  // ── ID取得 / List / Store ──
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: (!isConnected || _disableDuringSession)
                            ? null
                            : onSendId,
                        child: const Text('ID取得'),
                      ),
                      OutlinedButton(
                        onPressed: (!isConnected || _disableDuringSession)
                            ? null
                            : onSendList,
                        child: const Text('List'),
                      ),
                      OutlinedButton(
                        onPressed: (!isConnected || _disableDuringSession)
                            ? null
                            : onSendStore,
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
                      style: const TextStyle(
                        fontSize: AppConstants.standardFontSize,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── アップロードログ ──
                  Text(
                    'アップロードログ（${uploadPhase.name}）',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 200,
                    child: TextField(
                      controller: uploadLogController,
                      scrollController: uploadLogScrollController,
                      maxLines: null,
                      expands: true,
                      readOnly: true,
                      style: const TextStyle(
                        fontSize: AppConstants.standardFontSize,
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
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
