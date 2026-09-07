import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'pending_upload_store.dart';

/// 端末に残っている測定メタデータと未同期キューから、ピン表示用の記録を読む。
class LocalMeasurementRecord {
  const LocalMeasurementRecord({
    required this.id,
    required this.fileBase,
    required this.farmId,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.isPending,
    this.measurementNumber,
  });

  final String id;
  final String fileBase;
  final int farmId;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final bool isPending;
  final int? measurementNumber;
}

/// 測定画面がオフライン時にピンへ復元するための、端末上の測定データ読み出し。
class LocalMeasurementPinStore {
  LocalMeasurementPinStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationDocumentsDirectory;

  static const _skippedFileNames = {
    'pending_uploads.json',
    'result_map_cache.json',
    'farm_cache.json',
    'deleted_measurements.json',
  };

  final Future<Directory> Function() _directoryProvider;

  Future<List<LocalMeasurementRecord>> loadForFarmOnDate({
    required int farmId,
    required String dateIso,
    List<PendingUploadItem> pendingItems = const [],
  }) async {
    final byFileBase = <String, LocalMeasurementRecord>{};

    for (final item in pendingItems) {
      if (item.farmId != farmId) continue;
      final latitude = item.latitude;
      final longitude = item.longitude;
      if (latitude == null || longitude == null) continue;
      if (!_isOnDate(
        dateIso: dateIso,
        fileBase: item.fileBase,
        timestamp: null,
        measurementDate: item.measurementDate,
      )) {
        continue;
      }
      byFileBase[item.fileBase] = LocalMeasurementRecord(
        id: (item.localPinId != null && item.localPinId!.isNotEmpty)
            ? item.localPinId!
            : 'localfile_${item.fileBase}',
        fileBase: item.fileBase,
        farmId: farmId,
        latitude: latitude,
        longitude: longitude,
        createdAt:
            DateTime.tryParse(item.measurementDate) ?? item.createdAt,
        isPending: true,
        measurementNumber: item.pointNumber,
      );
    }

    final dir = await _directoryProvider();
    if (!await dir.exists()) {
      return byFileBase.values.toList(growable: false);
    }

    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.path.split(RegExp(r'[/\\]')).last;
      if (!name.endsWith('.json')) continue;
      if (_skippedFileNames.contains(name)) continue;

      final fileBase = name.substring(0, name.length - 5);
      try {
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is! Map) continue;
        final metadata = Map<String, dynamic>.from(decoded);
        final metadataFarmId = _asInt(metadata['farmId']);
        if (metadataFarmId != farmId) continue;
        final latitude = (metadata['latitude'] as num?)?.toDouble();
        final longitude = (metadata['longitude'] as num?)?.toDouble();
        if (latitude == null || longitude == null) continue;
        final timestamp = DateTime.tryParse(
          (metadata['timestamp'] as String?) ?? '',
        );
        if (!_isOnDate(
          dateIso: dateIso,
          fileBase: fileBase,
          timestamp: timestamp,
          measurementDate: metadata['timestamp'] as String?,
        )) {
          continue;
        }

        final pending = byFileBase[fileBase];
        if (pending != null) {
          byFileBase[fileBase] = LocalMeasurementRecord(
            id: pending.id,
            fileBase: fileBase,
            farmId: farmId,
            latitude: pending.latitude,
            longitude: pending.longitude,
            createdAt: timestamp ?? pending.createdAt,
            isPending: true,
            measurementNumber:
                _asInt(metadata['measurement_number']) ??
                pending.measurementNumber,
          );
          continue;
        }

        byFileBase[fileBase] = LocalMeasurementRecord(
          id: 'localfile_$fileBase',
          fileBase: fileBase,
          farmId: farmId,
          latitude: latitude,
          longitude: longitude,
          createdAt: timestamp ?? DateTime.now(),
          isPending: false,
          measurementNumber: _asInt(metadata['measurement_number']),
        );
      } catch (_) {
        // 壊れた測定メタデータはスキップする。
      }
    }

    final records = byFileBase.values.toList();
    records.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return records;
  }

  bool _isOnDate({
    required String dateIso,
    required String fileBase,
    required DateTime? timestamp,
    required String? measurementDate,
  }) {
    final compact = dateIso.replaceAll('-', '');
    if (fileBase.length >= 8 && fileBase.startsWith(compact)) return true;
    if (timestamp != null && _jstDateString(timestamp) == dateIso) return true;
    final parsed = DateTime.tryParse(measurementDate ?? '');
    if (parsed != null && _jstDateString(parsed) == dateIso) return true;
    if (measurementDate != null &&
        measurementDate.length >= 10 &&
        measurementDate.substring(0, 10) == dateIso) {
      return true;
    }
    return false;
  }

  String _jstDateString(DateTime value) {
    final jst = value.toUtc().add(const Duration(hours: 9));
    final month = jst.month.toString().padLeft(2, '0');
    final day = jst.day.toString().padLeft(2, '0');
    return '${jst.year}-$month-$day';
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
