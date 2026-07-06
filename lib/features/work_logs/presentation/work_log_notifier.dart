import 'package:flutter/foundation.dart';

import '../data/work_log_repository.dart';
import '../domain/work_log_entry.dart';

class WorkLogNotifier extends ChangeNotifier {
  WorkLogNotifier({
    required this.farmId,
    WorkLogRepository? repository,
    int? editWorkLogId,
  }) : _repository = repository ?? WorkLogRepository(),
       _editWorkLogId = editWorkLogId {
    workDate = _formatDate(DateTime.now());
  }

  final int farmId;
  final WorkLogRepository _repository;
  final int? _editWorkLogId;

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
  bool get isEditMode => _editWorkLogId != null;

  factory WorkLogNotifier.forEdit({
    required int farmId,
    required int workLogId,
    required WorkLogEntry initial,
    WorkLogRepository? repository,
  }) {
    final notifier = WorkLogNotifier(
      farmId: farmId,
      repository: repository,
      editWorkLogId: workLogId,
    );
    notifier
      ..workType = WorkType.fromValue(initial.workType)
      ..workDate = initial.workDate
      ..title = initial.title ?? ''
      ..detail = initial.detail ?? ''
      ..amountText = initial.amountValue?.toString() ?? ''
      ..amountUnit = initial.amountUnit ?? unitPresets.first
      ..step = 1;
    return notifier;
  }

  void selectWorkType(WorkType value) {
    workType = value;
    step = 1;
    _clearSaveResult();
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
    _clearSaveResult();
    notifyListeners();
  }

  void goBack() {
    if (step == 0) return;
    step--;
    notifyListeners();
  }

  Future<void> pickDate(DateTime date) async {
    workDate = _formatDate(date);
    _clearSaveResult();
    notifyListeners();
  }

  Future<void> save() async {
    final selectedType = workType;
    if (selectedType == null || isSaving || isSaveComplete) return;

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
      final editWorkLogId = _editWorkLogId;
      if (editWorkLogId == null) {
        final result = await _repository.create(farmId: farmId, entry: entry);
        saveQueued = result.queued;
      } else {
        await _repository.update(workLogId: editWorkLogId, entry: entry);
        saveQueued = false;
      }
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

  void _clearSaveResult() {
    saveQueued = null;
    saveError = null;
  }
}
