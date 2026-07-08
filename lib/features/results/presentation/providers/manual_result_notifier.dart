import 'package:flutter/foundation.dart';

import '../../data/manual_result_repository.dart';
import '../../domain/manual_result_parameter.dart';

class ManualResultNotifier extends ChangeNotifier {
  ManualResultNotifier({
    required this.farmId,
    required this.isProvisional,
    ManualResultRepository? repository,
  }) : _repository = repository ?? ManualResultRepository() {
    measurementDate = _formatDate(DateTime.now());
  }

  final int farmId;
  final bool isProvisional;
  final ManualResultRepository _repository;

  String measurementDate = '';
  final Map<String, String> valueTexts = {
    for (final param in manualResultParameters) param.name: '',
  };

  bool isSaving = false;
  String? saveError;

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
      await _repository.create(
        farmId: farmId,
        measurementDate: measurementDate,
        values: _parsedValues(),
      );
      return true;
    } on ManualResultBoundaryRequiredException {
      saveError = 'この圃場は境界が未設定のため、過去実績を登録できません';
      return false;
    } on ManualResultDateAlreadyExistsException {
      saveError = 'この日の過去実績はすでに登録されています';
      return false;
    } catch (_) {
      saveError = '登録に失敗しました。通信状態を確認してください';
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
}
