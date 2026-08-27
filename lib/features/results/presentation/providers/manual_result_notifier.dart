import 'package:flutter/foundation.dart';

import '../../data/manual_result_repository.dart';
import '../../domain/manual_result_parameter.dart';

class ManualResultNotifier extends ChangeNotifier {
  ManualResultNotifier({
    required this.farmId,
    required this.isProvisional,
    this.uploadId,
    String? initialMeasurementDate,
    Map<String, double?> initialValues = const {},
    ManualResultRepository? repository,
  }) : _repository = repository ?? ManualResultRepository() {
    measurementDate = initialMeasurementDate ?? _formatDate(DateTime.now());
    for (final entry in initialValues.entries) {
      final value = entry.value;
      if (value != null && valueTexts.containsKey(entry.key)) {
        valueTexts[entry.key] = _formatValue(value);
      }
    }
  }

  final int farmId;
  final bool isProvisional;
  final int? uploadId;
  final ManualResultRepository _repository;

  String measurementDate = '';
  final Map<String, String> valueTexts = {
    for (final param in manualResultParameters) param.name: '',
  };

  bool isSaving = false;
  String? saveError;

  bool get isEditing => uploadId != null;

  bool get canSubmit {
    if (isProvisional || isSaving) return false;
    return _parsedValues().isNotEmpty;
  }

  Map<String, double> _parsedValues() {
    final values = <String, double>{};
    for (final param in manualResultParameters) {
      final text = valueTexts[param.name]?.trim() ?? '';
      if (text.isEmpty) continue;
      final parsed = double.tryParse(text);
      if (parsed != null) values[param.name] = parsed;
    }
    return values;
  }

  void setMeasurementDate(String value) {
    measurementDate = value;
    saveError = null;
    notifyListeners();
  }

  void setValueText(String parameterName, String value) {
    valueTexts[parameterName] = value;
    saveError = null;
    notifyListeners();
  }

  Future<bool> submit() async {
    if (!canSubmit) return false;

    isSaving = true;
    saveError = null;
    notifyListeners();

    try {
      final values = _parsedValues();
      if (uploadId case final int id) {
        await _repository.update(
          uploadId: id,
          measurementDate: measurementDate,
          values: values,
        );
      } else {
        await _repository.create(
          farmId: farmId,
          measurementDate: measurementDate,
          values: values,
        );
      }
      return true;
    } on ManualResultBoundaryRequiredException {
      saveError = 'この圃場は境界が未設定のため、測定結果を保存できません';
      return false;
    } on ManualResultDateAlreadyExistsException {
      saveError = 'この日の手動測定結果はすでに登録されています';
      return false;
    } catch (_) {
      saveError = '${isEditing ? '更新' : '登録'}に失敗しました。通信状態を確認してください';
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _formatValue(double value) {
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
}
