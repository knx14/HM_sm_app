import 'dart:convert';

import '../domain/chart_data.dart';
import '../domain/measure_settings.dart';
import 'measurement_local_paths.dart';

class LocalSaveService {
  static final RegExp _memoPattern = RegExp(r'^[a-zA-Z0-9]{0,10}$');

  static bool isValidMemo(String memo) => _memoPattern.hasMatch(memo);

  static Future<String> saveMeasurement({
    required List<ChartData> chartData,
    required String userId,
    required int farmId,
    required String note1,
    required String note2,
    required MeasureSettings settings,
    required String? ampId,
    double? latitude,
    double? longitude,
  }) async {
    if (userId.trim().isEmpty) {
      throw ArgumentError('userIdが空です');
    }
    if (!isValidMemo(note1) || !isValidMemo(note2)) {
      throw ArgumentError('メモは半角英数10文字以内で入力してください');
    }
    if (chartData.isEmpty) {
      throw ArgumentError('保存するデータがありません');
    }

    final now = DateTime.now();
    final date = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final time = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    // ファイル名に使える形へ（念のため）
    final safeUserId = userId.replaceAll(RegExp(r'[^a-zA-Z0-9\\-_]'), '_');
    final fileNameBase = '${date}_${time}_${safeUserId}_${note1}_$note2';

    final csvFile = await MeasurementLocalPaths.csvFile(fileNameBase);
    final jsonFile = await MeasurementLocalPaths.jsonFile(fileNameBase);

    // CSV: real群, imag群（1行）
    final realValues = chartData.map((e) => e.real.toStringAsFixed(6)).toList();
    final imagValues = chartData.map((e) => e.imag.toStringAsFixed(6)).toList();
    final csvContent = [...realValues, ...imagValues].join(',');
    await csvFile.writeAsString(csvContent);

    // JSON: メタデータ
    final metadata = <String, dynamic>{
      'timestamp': now.toIso8601String(),
      'userId': userId,
      'farmId': farmId,
      'note1': note1,
      'note2': note2,
      'ampId': ampId,
      if (latitude != null && longitude != null) 'latitude': latitude,
      if (latitude != null && longitude != null) 'longitude': longitude,
      'predicted_CEC': null,
      'start_frequency': settings.fstart.toString(),
      'delta_frequency': settings.fdelta.toString(),
      'step_count': settings.points.toString(),
      'excitation_voltage': settings.excite.toString(),
      'input_range': settings.range.toString(),
      'integration_time': settings.integrate.toString(),
      'average_count': settings.average.toString(),
    };
    await jsonFile.writeAsString(const JsonEncoder.withIndent('  ').convert(metadata));

    return fileNameBase;
  }
}

