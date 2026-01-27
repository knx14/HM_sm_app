import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

/// 測定パラメータ（TypeDコマンド生成用）
class AppSettings extends ChangeNotifier {
  double _fstart = 10000.0;
  double _fdelta = 1500.0;
  int _points = AppConstants.defaultPointCount;
  double _excite = 1.0;
  double _range = 0.5;
  double _integrate = 0.1;
  int _average = 1;

  double get fstart => _fstart;
  double get fdelta => _fdelta;
  int get points => _points;
  double get excite => _excite;
  double get range => _range;
  double get integrate => _integrate;
  int get average => _average;

  void update({
    double? fstart,
    double? fdelta,
    int? points,
    double? excite,
    double? range,
    double? integrate,
    int? average,
  }) {
    var changed = false;
    if (fstart != null && fstart != _fstart) {
      _fstart = fstart;
      changed = true;
    }
    if (fdelta != null && fdelta != _fdelta) {
      _fdelta = fdelta;
      changed = true;
    }
    if (points != null && points != _points) {
      _points = points;
      changed = true;
    }
    if (excite != null && excite != _excite) {
      _excite = excite;
      changed = true;
    }
    if (range != null && range != _range) {
      _range = range;
      changed = true;
    }
    if (integrate != null && integrate != _integrate) {
      _integrate = integrate;
      changed = true;
    }
    if (average != null && average != _average) {
      _average = average;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  String getZeroCommand() =>
      'zero $fstart $fdelta $points $excite $range $integrate $average';
}

