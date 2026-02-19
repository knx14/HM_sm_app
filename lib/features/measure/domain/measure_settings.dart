/// TypeD exec測定に必要な測定パラメータ
class MeasureSettings {
  final double fstart;
  final double fdelta;
  final int points;
  final double excite;
  final double range;
  final double integrate;
  final int average;

  const MeasureSettings({
    required this.fstart,
    required this.fdelta,
    required this.points,
    required this.excite,
    required this.range,
    required this.integrate,
    required this.average,
  });

  static const MeasureSettings defaults = MeasureSettings(
    fstart: 10000.0,
    fdelta: 1500.0,
    points: 150,
    excite: 1.0,
    range: 0.5,
    integrate: 0.1,
    average: 1,
  );

  String execCommand() => 'exec $excite $range $integrate $average';

  String zeroCommand() => 'zero $fstart $fdelta $points $excite $range $integrate $average';
}

