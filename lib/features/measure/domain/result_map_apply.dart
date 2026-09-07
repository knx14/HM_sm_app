/// 結果マップの1点を、端末の表示系列へどう適用するかを決める。
///
/// 突合は測定番号だけ。番号が無いクラウド点は距離では当てない。
class ResultMapPointDecision {
  const ResultMapPointDecision({required this.action, this.matchingIndex});

  final ResultMapPointAction action;
  final int? matchingIndex;

  static ResultMapPointDecision decide({
    required int? measurementNumber,
    required int? resultPointId,
    required List<int?> localNumbers,
    required List<int?> localResultPointIds,
    required Set<int> deletedMeasurementNumbers,
    required Set<int> deletedResultPointIds,
  }) {
    if (measurementNumber != null &&
        deletedMeasurementNumbers.contains(measurementNumber)) {
      return const ResultMapPointDecision(
        action: ResultMapPointAction.skipDeleted,
      );
    }
    if (resultPointId != null &&
        deletedResultPointIds.contains(resultPointId)) {
      return const ResultMapPointDecision(
        action: ResultMapPointAction.skipDeleted,
      );
    }
    if (measurementNumber != null) {
      final index = localNumbers.indexWhere((n) => n == measurementNumber);
      if (index >= 0) {
        return ResultMapPointDecision(
          action: ResultMapPointAction.update,
          matchingIndex: index,
        );
      }
      return const ResultMapPointDecision(action: ResultMapPointAction.add);
    }
    if (resultPointId != null) {
      final index = localResultPointIds.indexWhere((id) => id == resultPointId);
      if (index >= 0) {
        return ResultMapPointDecision(
          action: ResultMapPointAction.update,
          matchingIndex: index,
        );
      }
    }
    return const ResultMapPointDecision(action: ResultMapPointAction.add);
  }
}

enum ResultMapPointAction { update, add, skipDeleted }
