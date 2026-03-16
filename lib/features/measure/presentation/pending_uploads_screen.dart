import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/measurement_local_paths.dart';
import '../data/measurement_upload_service.dart';
import '../data/pending_upload_store.dart';

class PendingUploadsScreen extends StatefulWidget {
  const PendingUploadsScreen({super.key});

  @override
  State<PendingUploadsScreen> createState() => _PendingUploadsScreenState();
}

class _PendingUploadsScreenState extends State<PendingUploadsScreen> {
  final PendingUploadStore _store = PendingUploadStore();
  List<PendingUploadItem> _items = const [];
  final Set<String> _uploading = <String>{};
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
      _isLoading = false;
    });
  }

  Future<void> _retryUpload(PendingUploadItem item) async {
    setState(() => _uploading.add(item.fileBase));
    try {
      final csvFile = await MeasurementLocalPaths.csvFile(item.fileBase);
      final jsonFile = await MeasurementLocalPaths.jsonFile(item.fileBase);
      if (!await csvFile.exists() || !await jsonFile.exists()) {
        throw StateError('再送対象ファイルが見つかりません');
      }
      final measurementParameters =
          jsonDecode(await jsonFile.readAsString()) as Map<String, dynamic>;
      final uploader = MeasurementUploadService();
      await uploader.uploadCsvWithInitComplete(
        farmId: item.farmId,
        csvFile: csvFile,
        measurementParameters: measurementParameters,
        measurementDate: item.measurementDate,
        note1: item.note1,
        note2: item.note2,
        cultivationType: null,
      );
      await _store.removeByFileBase(item.fileBase);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('アップロード完了: ${item.fileBase}')),
      );
      await _load();
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('再アップロード失敗: $e')),
      );
      await _load();
    } finally {
      if (mounted) {
        setState(() => _uploading.remove(item.fileBase));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('未アップロード一覧'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('未アップロードデータはありません'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final isUploading = _uploading.contains(item.fileBase);
                      return ListTile(
                        title: Text(item.fileBase),
                        subtitle: Text(
                          'farm_id=${item.farmId} / phase=${item.failedPhase}\n${item.lastError}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: FilledButton(
                          onPressed: isUploading ? null : () => _retryUpload(item),
                          child: Text(isUploading ? '送信中' : 'アップロード'),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
