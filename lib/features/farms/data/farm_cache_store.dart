import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class FarmCacheStore {
  static const _fileName = 'farm_cache.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// 圃場リストをキャッシュに保存する。
  /// オンライン時に圃場一覧 API 成功後に呼ぶ。
  Future<void> save(List<Map<String, dynamic>> farms) async {
    final file = await _file();
    final tmpFile = File('${file.path}.tmp');
    final content = const JsonEncoder.withIndent(
      '  ',
    ).convert({'saved_at': DateTime.now().toIso8601String(), 'farms': farms});
    try {
      await file.parent.create(recursive: true);
      await tmpFile.writeAsString(content, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tmpFile.rename(file.path);
    } catch (_) {
      await file.writeAsString(content, flush: true);
      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }
    }
  }

  /// キャッシュから圃場リストを読み込む。
  /// キャッシュが存在しない場合は null を返す。
  Future<List<Map<String, dynamic>>?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final farms = decoded['farms'];
      if (farms is! List) return null;
      return farms
          .whereType<Map>()
          .map((farm) => Map<String, dynamic>.from(farm))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// キャッシュの保存日時を返す。
  /// キャッシュが存在しない場合は null を返す。
  Future<DateTime?> savedAt() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return DateTime.parse(decoded['saved_at'] as String);
    } catch (_) {
      return null;
    }
  }
}
