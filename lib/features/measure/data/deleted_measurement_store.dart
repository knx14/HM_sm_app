import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 圃場・日ごとに、画面から消した測定番号を残す。結果マップやファイル復元で戻さない。
class DeletedMeasurementStore {
  DeletedMeasurementStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationDocumentsDirectory;

  static const _fileName = 'deleted_measurements.json';

  final Future<Directory> Function() _directoryProvider;

  Future<void> add({
    required int farmId,
    required String dateIso,
    required Iterable<int> numbers,
  }) async {
    final toAdd = numbers.where((number) => number > 0).toSet();
    if (toAdd.isEmpty) return;
    final cached = await _read();
    final byDate = <String, dynamic>{};
    if (cached != null) {
      byDate.addAll(cached);
    }
    final farms = <String, dynamic>{};
    final existingDate = byDate[dateIso];
    if (existingDate is Map) {
      farms.addAll(Map<String, dynamic>.from(existingDate));
    }
    final existingNumbers = <int>{
      for (final value in _asIntList(farms['$farmId'])) value,
    };
    existingNumbers.addAll(toAdd);
    farms['$farmId'] = existingNumbers.toList()..sort();
    byDate[dateIso] = farms;
    await _write(byDate);
  }

  Future<Set<int>> load({
    required int farmId,
    required String dateIso,
  }) async {
    final cached = await _read();
    if (cached == null) return {};
    final farms = cached[dateIso];
    if (farms is! Map) return {};
    return {for (final value in _asIntList(farms['$farmId'])) value};
  }

  List<int> _asIntList(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is int)
          item
        else if (item is num)
          item.toInt(),
    ];
  }

  Future<File> _file() async {
    final dir = await _directoryProvider();
    return File('${dir.path}/$_fileName');
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
