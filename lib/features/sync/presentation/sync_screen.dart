import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../measure/data/measurement_local_paths.dart';
import '../../measure/data/measurement_upload_service.dart';
import '../../measure/data/pending_upload_store.dart';
import '../../measure/presentation/measurement_session_screen.dart'
    show MeasurementStateProvider;
import '../../work_logs/data/work_log_repository.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final PendingUploadStore _store = PendingUploadStore();
  final WorkLogRepository _workLogRepository = WorkLogRepository();
  final Set<String> _selected = <String>{};
  final Set<String> _syncing = <String>{};
  List<PendingUploadItem> _items = const [];
  int _pendingWorkLogCount = 0;
  bool _isLoading = true;
  bool _isSyncingWorkLogs = false;
  bool _isSyncingSelected = false;
  int _syncedCount = 0;
  int _totalToSync = 0;
  String _lastSyncedAt = '未同期';

  @override
  void initState() {
    super.initState();
    _loadLastSyncedAt();
    _load();
  }

  Future<void> _loadLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _lastSyncedAt = prefs.getString('last_synced_at') ?? '未同期';
    });
  }

  Future<void> _saveLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final label =
        '${now.month}/${now.day} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    await prefs.setString('last_synced_at', label);
    if (!mounted) return;
    setState(() => _lastSyncedAt = label);
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      _store.listItems(),
      _workLogRepository.pendingCount(),
    ]);
    final items = results[0] as List<PendingUploadItem>;
    final pendingWorkLogCount = results[1] as int;
    if (!mounted) return;
    setState(() {
      _items = items;
      _pendingWorkLogCount = pendingWorkLogCount;
      _selected.removeWhere(
        (fileBase) => !items.any((item) => item.fileBase == fileBase),
      );
      _isLoading = false;
    });
  }

  Future<void> _syncItem(PendingUploadItem item) async {
    setState(() => _syncing.add(item.fileBase));
    try {
      final csvFile = await MeasurementLocalPaths.csvFile(item.fileBase);
      final jsonFile = await MeasurementLocalPaths.jsonFile(item.fileBase);
      if (!await csvFile.exists() || !await jsonFile.exists()) {
        throw StateError('再送対象ファイルが見つかりません');
      }

      final measurementParameters =
          jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
      final latitude =
          item.latitude ??
          (measurementParameters['latitude'] as num?)?.toDouble();
      final longitude =
          item.longitude ??
          (measurementParameters['longitude'] as num?)?.toDouble();
      await MeasurementUploadService().uploadCsvWithInitComplete(
        farmId: item.farmId,
        csvFile: csvFile,
        measurementParameters: measurementParameters,
        measurementDate: item.measurementDate,
        note1: item.note1,
        note2: item.note2,
        cultivationType: null,
      );
      if (mounted) {
        context.read<MeasurementStateProvider>().removeSyncedLocalPins(
          farmId: item.farmId,
          localPinId: item.localPinId,
          latitude: latitude,
          longitude: longitude,
        );
      }
      await _store.removeByFileBase(item.fileBase);
      _selected.remove(item.fileBase);
    } catch (e) {
      await _store.addOrUpdate(
        PendingUploadItem(
          fileBase: item.fileBase,
          farmId: item.farmId,
          farmName: item.farmName,
          pointNumber: item.pointNumber,
          localPinId: item.localPinId,
          latitude: item.latitude,
          longitude: item.longitude,
          note1: item.note1,
          note2: item.note2,
          measurementDate: item.measurementDate,
          failedPhase: 'retry',
          lastError: e.toString(),
          createdAt: item.createdAt,
          updatedAt: DateTime.now(),
        ),
      );
      rethrow;
    } finally {
      if (mounted) {
        setState(() => _syncing.remove(item.fileBase));
      }
    }
  }

  Future<void> _syncPendingWorkLogs() async {
    setState(() => _isSyncingWorkLogs = true);
    final result = await _workLogRepository.flushQueue();
    if (result.success > 0) {
      await _saveLastSyncedAt();
    }
    await _load();
    if (!mounted) return;
    setState(() => _isSyncingWorkLogs = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '作業記録の同期完了: 成功 ${result.success} 件 / 失敗 ${result.failed} 件',
        ),
      ),
    );
  }

  Future<void> _syncSelected() async {
    final targets = _items
        .where((item) => _selected.contains(item.fileBase))
        .toList();
    if (targets.isEmpty) return;
    setState(() {
      _isSyncingSelected = true;
      _syncedCount = 0;
      _totalToSync = targets.length;
    });
    var success = 0;
    var failed = 0;
    for (final item in targets) {
      try {
        await _syncItem(item);
        success++;
        if (mounted) {
          setState(() => _syncedCount = success);
        }
      } catch (_) {
        failed++;
      }
    }
    if (success > 0) {
      await _saveLastSyncedAt();
    }
    await _load();
    if (!mounted) return;
    setState(() => _isSyncingSelected = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('同期完了: 成功 $success 件 / 失敗 $failed 件')),
    );
  }

  Future<void> _deleteSelected() async {
    final targets = _items
        .where((item) => _selected.contains(item.fileBase))
        .toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('選択を削除'),
        content: Text('${targets.length}件の未同期データを一覧から削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    for (final item in targets) {
      await _store.removeByFileBase(item.fileBase);
    }
    _selected.clear();
    await _load();
  }

  void _toggleAll() {
    setState(() {
      if (_selected.length == _items.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(_items.map((item) => item.fileBase));
      }
    });
  }

  String _farmLabel(PendingUploadItem item) {
    final farmName = item.farmName?.trim();
    if (farmName != null && farmName.isNotEmpty) return farmName;
    return '圃場ID ${item.farmId}';
  }

  String _pointLabel(PendingUploadItem item, int index) {
    final pointNumber = item.pointNumber ?? index + 1;
    return '地点 $pointNumber';
  }

  String _dateTimeLabel(PendingUploadItem item) {
    final parsed = DateTime.tryParse(item.measurementDate)?.toLocal();
    final time = parsed ?? item.createdAt;
    final date =
        '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}';
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$date $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('同期'),
        backgroundColor: const Color(0xFFB07820),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty && _pendingWorkLogCount == 0
          ? const Center(child: Text('未アップロードデータはありません'))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  color: const Color(0xFFFEF0D8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '未同期 ${_items.length + _pendingWorkLogCount} 件',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '最終同期: $_lastSyncedAt',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (_items.isNotEmpty)
                            TextButton(
                              onPressed: _syncing.isEmpty && !_isSyncingSelected
                                  ? _toggleAll
                                  : null,
                              child: Text(
                                _selected.length == _items.length
                                    ? '全解除'
                                    : '全選択',
                              ),
                            ),
                        ],
                      ),
                      if (_isSyncingSelected) ...[
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: _totalToSync > 0
                              ? _syncedCount / _totalToSync
                              : null,
                          backgroundColor: Colors.orange[100],
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_syncedCount / $_totalToSync 件 同期中...',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      children: [
                        if (_pendingWorkLogCount > 0) ...[
                          ListTile(
                            leading: _isSyncingWorkLogs
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.agriculture,
                                    color: Color(0xFFB85C00),
                                  ),
                            title: Text('未送信の作業記録: $_pendingWorkLogCount 件'),
                            subtitle: const Text('オフライン時に保存された作業記録です'),
                            trailing: FilledButton(
                              onPressed: _isSyncingWorkLogs
                                  ? null
                                  : _syncPendingWorkLogs,
                              child: const Text('送信'),
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                        for (var index = 0; index < _items.length; index++) ...[
                          Builder(
                            builder: (context) {
                              final item = _items[index];
                              final selected = _selected.contains(
                                item.fileBase,
                              );
                              final syncing = _syncing.contains(item.fileBase);
                              return ListTile(
                                leading: syncing
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Checkbox(
                                        value: selected,
                                        onChanged: _isSyncingSelected
                                            ? null
                                            : (value) {
                                                setState(() {
                                                  if (value == true) {
                                                    _selected.add(
                                                      item.fileBase,
                                                    );
                                                  } else {
                                                    _selected.remove(
                                                      item.fileBase,
                                                    );
                                                  }
                                                });
                                              },
                                      ),
                                title: Text(
                                  '${_farmLabel(item)} / ${_pointLabel(item, index)}',
                                ),
                                subtitle: Text(
                                  '日時: ${_dateTimeLabel(item)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                          const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_items.isNotEmpty)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          OutlinedButton(
                            onPressed:
                                _selected.isEmpty ||
                                    _syncing.isNotEmpty ||
                                    _isSyncingSelected
                                ? null
                                : _deleteSelected,
                            child: const Text('選択を削除'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed:
                                  _selected.isEmpty ||
                                      _syncing.isNotEmpty ||
                                      _isSyncingSelected
                                  ? null
                                  : _syncSelected,
                              icon: const Icon(Icons.cloud_upload_outlined),
                              label: const Text('同期'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
