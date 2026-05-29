import 'package:flutter/foundation.dart';

import '../data/work_log_repository.dart';
import '../domain/work_log_entry.dart';

class WorkLogNotifier extends ChangeNotifier {
  WorkLogNotifier({required this.farmId, WorkLogRepository? repository})
    : _repository = repository ?? WorkLogRepository() {
    workDate = _formatDate(DateTime.now());
  }

  final int farmId;
  final WorkLogRepository _repository;

  int step = 0;
  WorkType? workType;
  String workDate = '';
  String title = '';
  String detail = '';
  String amountText = '';
  String amountUnit = unitPresets.first;

  bool isSaving = false;
  bool? saveQueued;
  String? saveError;

  bool get isSaveComplete => saveQueued != null && saveError == null;

  void selectWorkType(WorkType value) {
    workType = value;
    step = 1;
    notifyListeners();
  }

  void updateDetails({
    required String nextDate,
    required String nextTitle,
    required String nextDetail,
    required String nextAmountText,
    required String nextAmountUnit,
  }) {
    workDate = nextDate;
    title = nextTitle;
    detail = nextDetail;
    amountText = nextAmountText;
    amountUnit = nextAmountUnit;
    step = 2;
    notifyListeners();
  }

  void goBack() {
    if (step == 0) return;
    step--;
    notifyListeners();
  }

  Future<void> pickDate(DateTime date) async {
    workDate = _formatDate(date);
    notifyListeners();
  }

  Future<void> save() async {
    final selectedType = workType;
    if (selectedType == null || isSaving) return;

    isSaving = true;
    saveError = null;
    saveQueued = null;
    notifyListeners();

    final parsedAmount = double.tryParse(amountText);
    final entry = WorkLogEntry(
      workType: selectedType.value,
      workDate: workDate,
      title: title.trim().isEmpty ? null : title.trim(),
      detail: detail.trim().isEmpty ? null : detail.trim(),
      amountValue: parsedAmount,
      amountUnit: parsedAmount == null ? null : amountUnit,
    );

    try {
      final result = await _repository.create(farmId: farmId, entry: entry);
      saveQueued = result.queued;
    } catch (e) {
      saveError = '保存に失敗しました';
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
