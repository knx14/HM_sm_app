import 'package:flutter/material.dart';
import 'package:graphic/graphic.dart' as graphic;

import '../../domain/chart_data.dart';

enum GraphMode { complex, amplitude, phase }

class MeasurementChart extends StatefulWidget {
  final List<ChartData> chartData;
  final GraphMode initialMode;

  const MeasurementChart({
    super.key,
    required this.chartData,
    this.initialMode = GraphMode.complex,
  });

  @override
  State<MeasurementChart> createState() => _MeasurementChartState();
}

class _MeasurementChartState extends State<MeasurementChart> {
  late GraphMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  Map<String, dynamic> _map(ChartData d) {
    switch (_mode) {
      case GraphMode.complex:
        return {'real': d.real, 'imag': d.imag};
      case GraphMode.amplitude:
        return {'frequency': d.frequency, 'value': d.amplitude};
      case GraphMode.phase:
        return {'frequency': d.frequency, 'value': d.phase};
    }
  }

  Widget _buildChart() {
    if (widget.chartData.isEmpty) {
      return const Center(
        child: Text(
          'データがありません',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      );
    }

    return graphic.Chart(
      data: widget.chartData.map(_map).toList(),
      variables: _mode == GraphMode.complex
          ? {
              'real': graphic.Variable(
                accessor: (map) => (map as Map)['real'] as num,
                scale: graphic.LinearScale(formatter: (v) => v.toStringAsFixed(6)),
              ),
              'imag': graphic.Variable(
                accessor: (map) => (map as Map)['imag'] as num,
                scale: graphic.LinearScale(formatter: (v) => v.toStringAsFixed(6)),
              ),
            }
          : {
              'frequency': graphic.Variable(
                accessor: (map) => (map as Map)['frequency'] as num,
                scale: graphic.LinearScale(formatter: (v) => v.toInt().toString()),
              ),
              'value': graphic.Variable(
                accessor: (map) => (map as Map)['value'] as num,
                scale: graphic.LinearScale(
                  formatter: (v) => v.toStringAsFixed(_mode == GraphMode.phase ? 1 : 6),
                ),
              ),
            },
      marks: _mode == GraphMode.complex
          ? [
              graphic.PointMark(
                position: graphic.Varset('real') * graphic.Varset('imag'),
                color: graphic.ColorEncode(value: Colors.blue),
              ),
            ]
          : [
              graphic.LineMark(
                position: graphic.Varset('frequency') * graphic.Varset('value'),
                color: graphic.ColorEncode(value: Colors.blue),
              ),
              graphic.PointMark(
                position: graphic.Varset('frequency') * graphic.Varset('value'),
                color: graphic.ColorEncode(value: Colors.blue),
              ),
            ],
      axes: [
        graphic.Defaults.horizontalAxis,
        graphic.Defaults.verticalAxis,
      ],
      selections: {
        'tooltip': graphic.PointSelection(
          on: {graphic.GestureType.hover, graphic.GestureType.tap},
          dim: graphic.Dim.x,
        ),
      },
      crosshair: graphic.CrosshairGuide(),
    );
  }

  String _xLabel() => _mode == GraphMode.complex ? 'Real' : '周波数 [Hz]';

  String _yLabel() {
    switch (_mode) {
      case GraphMode.complex:
        return 'Imaginary';
      case GraphMode.amplitude:
        return '振幅';
      case GraphMode.phase:
        return '位相 [deg]';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: SegmentedButton<GraphMode>(
            segments: const [
              ButtonSegment(value: GraphMode.complex, label: Text('複素平面')),
              ButtonSegment(value: GraphMode.amplitude, label: Text('振幅')),
              ButtonSegment(value: GraphMode.phase, label: Text('位相')),
            ],
            selected: {_mode},
            onSelectionChanged: (newSelection) => setState(() => _mode = newSelection.first),
            showSelectedIcon: false,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: RotatedBox(
                  quarterTurns: -1,
                  child: Text(_yLabel(), style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: _buildChart()),
                    const SizedBox(height: 4),
                    Text(_xLabel(), style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ],
    );
  }
}

