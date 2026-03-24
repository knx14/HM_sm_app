import 'dart:convert';
import 'dart:io';

import 'measurement_local_paths.dart';

class PendingUploadItem {
  final String fileBase;
  final int farmId;
  final String? note1;
  final String? note2;
  final String measurementDate;
  final String failedPhase;
  final String lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PendingUploadItem({
    required this.fileBase,
    required this.farmId,
    required this.note1,
    required this.note2,
    required this.measurementDate,
    required this.failedPhase,
    required this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  PendingUploadItem copyWith({
    String? failedPhase,
    String? lastError,
    DateTime? updatedAt,
  }) {
    return PendingUploadItem(
      fileBase: fileBase,
      farmId: farmId,
      note1: note1,
      note2: note2,
      measurementDate: measurementDate,
      failedPhase: failedPhase ?? this.failedPhase,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileBase': fileBase,
      'farmId': farmId,
      'note1': note1,
      'note2': note2,
      'measurementDate': measurementDate,
      'failedPhase': failedPhase,
      'lastError': lastError,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory PendingUploadItem.fromJson(Map<String, dynamic> json) {
    return PendingUploadItem(
      fileBase: json['fileBase'] as String,
      farmId: (json['farmId'] as num).toInt(),
      note1: json['note1'] as String?,
      note2: json['note2'] as String?,
      measurementDate: json['measurementDate'] as String,
      failedPhase: (json['failedPhase'] as String?) ?? 'error',
      lastError: (json['lastError'] as String?) ?? '',
      createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}

class PendingUploadStore {
  Future<File> _storeFile() async {
    return MeasurementLocalPaths.pendingUploadsFile();
  }

  Future<List<PendingUploadItem>> listItems() async {
    final file = await _storeFile();
    if (!await file.exists()) return <PendingUploadItem>[];
    try {
      final text = await file.readAsString();
      if (text.trim().isEmpty) return <PendingUploadItem>[];
      final raw = jsonDecode(text);
      if (raw is! List) return <PendingUploadItem>[];
      final items = <PendingUploadItem>[];
      for (final e in raw) {
        if (e is! Map) continue;
        try {
          items.add(PendingUploadItem.fromJson(Map<String, dynamic>.from(e)));
        } catch (_) {
          // 壊れた1件があっても、残りの未アップロードを救済できるようにする。
        }
      }
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items;
    } catch (_) {
      return <PendingUploadItem>[];
    }
  }

  Future<int> count() async {
    final items = await listItems();
    return items.length;
  }

  Future<void> addOrUpdate(PendingUploadItem item) async {
    final items = await listItems();
    final now = DateTime.now();
    final index = items.indexWhere((e) => e.fileBase == item.fileBase);
    if (index >= 0) {
      items[index] = items[index].copyWith(
        failedPhase: item.failedPhase,
        lastError: item.lastError,
        updatedAt: now,
      );
    } else {
      items.add(
        PendingUploadItem(
          fileBase: item.fileBase,
          farmId: item.farmId,
          note1: item.note1,
          note2: item.note2,
          measurementDate: item.measurementDate,
          failedPhase: item.failedPhase,
          lastError: item.lastError,
          createdAt: item.createdAt,
          updatedAt: now,
        ),
      );
    }
    await _write(items);
  }

  Future<void> removeByFileBase(String fileBase) async {
    final items = await listItems();
    items.removeWhere((e) => e.fileBase == fileBase);
    await _write(items);
  }

  Future<void> _write(List<PendingUploadItem> items) async {
    final file = await _storeFile();
    final tmpFile = File('${file.path}.tmp');
    final payload = items.map((e) => e.toJson()).toList();
    final content = const JsonEncoder.withIndent('  ').convert(payload);
    try {
      await file.parent.create(recursive: true);
      await tmpFile.writeAsString(
        content,
        flush: true,
      );
      if (await file.exists()) {
        await file.delete();
      }
      await tmpFile.rename(file.path);
      return;
    } catch (primaryError) {
      // Atomic write failed (e.g., temp rename/delete race). Fallback to direct write.
      try {
        await file.writeAsString(content, flush: true);
      } catch (fallbackError) {
        throw StateError('pending write failed: $primaryError | fallback failed: $fallbackError');
      }
      try {
        if (await tmpFile.exists()) {
          await tmpFile.delete();
        }
      } catch (_) {
        // Cleanup failure should not break pending queue registration.
      }
    }
  }
}
