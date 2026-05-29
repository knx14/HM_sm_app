import 'dart:convert';

import 'package:flutter/material.dart';

import '../../measure/data/measurement_local_paths.dart';
import '../../measure/data/measurement_upload_service.dart';
import '../../measure/data/pending_upload_store.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final PendingUploadStore _store = PendingUploadStore();
  final Set<String> _selected = <String>{};
  final Set<String> _syncing = <String>{};
  List<PendingUploadItem> _items = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final items = await _store.listItems();
    if (!mounted) return;
    setState(() {
      _items = items;
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
      await MeasurementUploadService().uploadCsvWithInitComplete(
        farmId: item.farmId,
        csvFile: csvFile,
        measurementParameters: measurementParameters,
        measurementDate: item.measurementDate,
        note1: item.note1,
        note2: item.note2,
        cultivationType: null,
      );
      await _store.removeByFileBase(item.fileBase);
      _selected.remove(item.fileBase);
    } catch (e) {
      await _store.addOrUpdate(
        PendingUploadItem(
          fileBase: item.fileBase,
          farmId: item.farmId,
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

  Future<void> _syncSelected() async {
    final targets = _items
        .where((item) => _selected.contains(item.fileBase))
        .toList();
    var success = 0;
    var failed = 0;
    for (final item in targets) {
      try {
        await _syncItem(item);
        success++;
      } catch (_) {
        failed++;
      }
    }
    await _load();
    if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('同期'),
        backgroundColor: const Color(0xFFB07820),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const Center(child: Text('未アップロードデータはありません'))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  color: const Color(0xFFFEF0D8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '未同期 ${_items.length} 件',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton(
                        onPressed: _syncing.isEmpty ? _toggleAll : null,
                        child: Text(
                          _selected.length == _items.length ? '全解除' : '全選択',
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final selected = _selected.contains(item.fileBase);
                        final syncing = _syncing.contains(item.fileBase);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: syncing
                              ? null
                              : (value) {
                                  setState(() {
                                    if (value == true) {
                                      _selected.add(item.fileBase);
                                    } else {
                                      _selected.remove(item.fileBase);
                                    }
                                  });
                                },
                          title: Text(item.fileBase),
                          subtitle: Text(
                            'farm_id=${item.farmId} / ${item.measurementDate}\nphase=${item.failedPhase} / ${item.lastError}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          secondary: syncing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  item.lastError.isNotEmpty
                                      ? Icons.warning_amber_rounded
                                      : Icons.cloud_upload_outlined,
                                  color: item.lastError.isNotEmpty
                                      ? colorScheme.error
                                      : null,
                                ),
                        );
                      },
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed: _selected.isEmpty || _syncing.isNotEmpty
                              ? null
                              : _deleteSelected,
                          child: const Text('選択を削除'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _selected.isEmpty || _syncing.isNotEmpty
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
