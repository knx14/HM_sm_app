import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../results/domain/result_map.dart';

/// 当日の測定結果マップを端末へ保持し、オフライン時の表示に使う。
///
/// 測定画面は結果マップ API の取得に成功するたびに保存し、取得に失敗して
/// 表示中の結果ピンも無い場合にここから読み戻す。保持するのは1日分のみで、
/// 日付が変わった時点で以前の日付のエントリは破棄する。
class ResultMapCacheStore {
  ResultMapCacheStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationDocumentsDirectory;

  static const _fileName = 'result_map_cache.json';

  final Future<Directory> Function() _directoryProvider;

  Future<File> _file() async {
    final dir = await _directoryProvider();
    return File('${dir.path}/$_fileName');
  }

  /// 取得に成功した結果マップを圃場・日付単位で保存する。
  Future<void> save({
    required int farmId,
    required String dateIso,
    required ResultMapResponse response,
  }) async {
    final cached = await _read();
    final maps = <String, dynamic>{};
    if (cached != null && cached['date'] == dateIso) {
      final existing = cached['maps'];
      if (existing is Map) {
        maps.addAll(Map<String, dynamic>.from(existing));
      }
    }
    maps['$farmId'] = _encode(response);
    await _write({'date': dateIso, 'maps': maps});
  }

  /// 保存済みの結果マップを返す。
  /// 保存が無い場合と、保存されている日付が [dateIso] と異なる場合は null を返す。
  Future<ResultMapResponse?> load({
    required int farmId,
    required String dateIso,
  }) async {
    final cached = await _read();
    if (cached == null || cached['date'] != dateIso) return null;
    final maps = cached['maps'];
    if (maps is! Map) return null;
    final entry = maps['$farmId'];
    if (entry is! Map) return null;
    try {
      return ResultMapResponse.fromJson(Map<String, dynamic>.from(entry));
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _encode(ResultMapResponse response) {
    return {
      'farm': {
        'farm_id': response.farm.farmId,
        'farm_name': response.farm.farmName,
        'boundary_polygon': [
          for (final point in response.farm.boundaryPolygon)
            {'lat': point.lat, 'lng': point.lng},
        ],
      },
      'measurement_date': response.measurementDate.toIso8601String(),
      'points': [
        for (final point in response.points)
          {
            'point_id': point.pointId,
            'upload_id': point.uploadId,
            'measurement_number': point.measurementNumber,
            'lat': point.lat,
            'lng': point.lng,
            'created_at': point.createdAt?.toUtc().toIso8601String(),
            'values': [
              for (final value in point.values)
                {
                  'parameter': value.parameter,
                  'value': value.value,
                  'unit': value.unit,
                },
            ],
          },
      ],
    };
  }

  Future<Map<String, dynamic>?> _read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(Map<String, dynamic> content) async {
    final file = await _file();
    final tmpFile = File('${file.path}.tmp');
    final encoded = jsonEncode(content);
    try {
      await file.parent.create(recursive: true);
      await tmpFile.writeAsString(encoded, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tmpFile.rename(file.path);
    } catch (_) {
      await file.writeAsString(encoded, flush: true);
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
    }
  }
}
