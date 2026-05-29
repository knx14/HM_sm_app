import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../domain/work_log_entry.dart';

class PendingWorkLog {
  const PendingWorkLog({
    required this.localId,
    required this.farmId,
    required this.entry,
    required this.createdAt,
  });

  final String localId;
  final int farmId;
  final WorkLogEntry entry;
  final DateTime createdAt;

  Map<String, dynamic> toJson() {
    return {
      'localId': localId,
      'farmId': farmId,
      'entry': entry.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PendingWorkLog.fromJson(Map<String, dynamic> json) {
    return PendingWorkLog(
      localId: json['localId'] as String,
      farmId: (json['farmId'] as num).toInt(),
      entry: WorkLogEntry.fromJson(
        Map<String, dynamic>.from(json['entry'] as Map),
      ),
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class WorkLogQueue {
  static const String fileName = 'pending_work_logs.json';

  Future<File> _storeFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  Future<List<PendingWorkLog>> listItems() async {
    final file = await _storeFile();
    if (!await file.exists()) return <PendingWorkLog>[];
    try {
      final text = await file.readAsString();
      if (text.trim().isEmpty) return <PendingWorkLog>[];
      final raw = jsonDecode(text);
      if (raw is! List) return <PendingWorkLog>[];
      final items = <PendingWorkLog>[];
      for (final item in raw) {
        if (item is! Map) continue;
        try {
          items.add(PendingWorkLog.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {
          // 壊れた1件があっても、残りの作業ログキューは同期できるようにする。
        }
      }
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (_) {
      return <PendingWorkLog>[];
    }
  }

  Future<int> count() async {
    final items = await listItems();
    return items.length;
  }

  Future<void> enqueue(int farmId, WorkLogEntry entry) async {
    final items = await listItems();
    final now = DateTime.now();
    items.add(
      PendingWorkLog(
        localId: now.microsecondsSinceEpoch.toString(),
        farmId: farmId,
        entry: entry,
        createdAt: now,
      ),
    );
    await _write(items);
  }

  Future<void> removeByLocalId(String localId) async {
    final items = await listItems();
    items.removeWhere((item) => item.localId == localId);
    await _write(items);
  }

  Future<void> _write(List<PendingWorkLog> items) async {
    final file = await _storeFile();
    final tmpFile = File('${file.path}.tmp');
    final payload = items.map((item) => item.toJson()).toList();
    final content = const JsonEncoder.withIndent('  ').convert(payload);
    try {
      await file.parent.create(recursive: true);
      await tmpFile.writeAsString(content, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tmpFile.rename(file.path);
      return;
    } catch (primaryError) {
      try {
        await file.writeAsString(content, flush: true);
      } catch (fallbackError) {
        throw StateError(
          'work log queue write failed: $primaryError | fallback failed: $fallbackError',
        );
      }
      try {
        if (await tmpFile.exists()) {
          await tmpFile.delete();
        }
      } catch (_) {
        // Cleanup failure should not break queue registration.
      }
    }
  }
}
