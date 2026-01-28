import '../domain/result_map.dart';
import '../domain/result_map_diff.dart';

double? findValueByParameter(List<ResultValue> values, String parameter) {
  for (final v in values) {
    if (v.parameter == parameter) return v.value;
  }
  return null;
}

ResultValue? findResultValue(List<ResultValue> values, String parameter) {
  for (final v in values) {
    if (v.parameter == parameter) return v;
  }
  return null;
}

double? findDiffValueByParameter(List<ResultDiffValue> values, String parameter) {
  for (final v in values) {
    if (v.parameter == parameter) return v.diffValue;
  }
  return null;
}

