import 'package:flutter/material.dart';

import '../../domain/result_map.dart';
import '../../domain/result_map_diff.dart';
import '../../domain/result_parameter.dart';
import '../../utils/result_formatters.dart' as fmt;
import '../../utils/result_value_extractors.dart';
import 'three_component_radar_chart.dart';

class PointResultBottomSheet extends StatelessWidget {
  final bool isCompare;
  final ResultPoint? normalPoint;
  final ResultDiffPoint? diffPoint;

  const PointResultBottomSheet.normal({
    super.key,
    required ResultPoint point,
  })  : isCompare = false,
        normalPoint = point,
        diffPoint = null;

  const PointResultBottomSheet.compare({
    super.key,
    required ResultDiffPoint point,
  })  : isCompare = true,
        normalPoint = null,
        diffPoint = point;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.35,
      minChildSize: 0.2,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 8),
              const TabBar(
                tabs: [
                  Tab(text: '成分一覧'),
                  Tab(text: '3成分バランス'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _IngredientsTab(isCompare: isCompare, normalPoint: normalPoint, diffPoint: diffPoint, controller: controller),
                    _BalanceTab(isCompare: isCompare, normalPoint: normalPoint, diffPoint: diffPoint, controller: controller),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IngredientsTab extends StatelessWidget {
  final bool isCompare;
  final ResultPoint? normalPoint;
  final ResultDiffPoint? diffPoint;
  final ScrollController controller;

  const _IngredientsTab({
    required this.isCompare,
    required this.normalPoint,
    required this.diffPoint,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (!isCompare) {
      final pt = normalPoint!;
      return ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildBigCec(pt.values),
          const SizedBox(height: 16),
          _buildMajorRows(pt.values),
          const SizedBox(height: 16),
          _buildOtherTable(pt.values),
        ],
      );
    }

    final pt = diffPoint!;
    final current = {for (final v in pt.currentValues) v.parameter: v};
    final previous = pt.previousValues == null ? <String, ResultValue>{} : {for (final v in pt.previousValues!) v.parameter: v};
    final diff = {for (final v in pt.diffValues) v.parameter: v};
    final previousMissing = pt.previousValues == null;

    final orderedParams = <String>[];
    for (final v in pt.diffValues) {
      if (!orderedParams.contains(v.parameter)) orderedParams.add(v.parameter);
    }
    for (final v in pt.currentValues) {
      if (!orderedParams.contains(v.parameter)) orderedParams.add(v.parameter);
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: orderedParams.length,
      itemBuilder: (context, index) {
        final p = orderedParams[index];
        final c = current[p];
        final pv = previous[p];
        final dv = diff[p];

        final currentText = fmt.format1OrDash(c?.value);
        final prevText = fmt.format1OrDash(pv?.value);
        final diffText = previousMissing ? '--' : fmt.formatDiff1OrDash(dv?.diffValue);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '$p 当日 $currentText / 前回 $prevText / 差分 $diffText',
            style: const TextStyle(fontSize: 14),
          ),
        );
      },
    );
  }

  Widget _buildBigCec(List<ResultValue> values) {
    final cec = findValueByParameter(values, ResultParameter.cec.apiName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CEC', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          fmt.format1OrDash(cec),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildMajorRows(List<ResultValue> values) {
    Widget row(String p) {
      final v = findResultValue(values, p);
      final valueText = fmt.format1OrDash(v?.value);
      final unit = (v?.value == null) ? null : v?.unit;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            SizedBox(width: 64, child: Text(p, style: const TextStyle(fontWeight: FontWeight.w700))),
            Expanded(
              child: Text(unit == null ? valueText : '$valueText $unit'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(ResultParameter.k2o.apiName),
        row(ResultParameter.cao.apiName),
        row(ResultParameter.mgo.apiName),
      ],
    );
  }

  Widget _buildOtherTable(List<ResultValue> values) {
    final majors = {
      ResultParameter.cec.apiName,
      ResultParameter.k2o.apiName,
      ResultParameter.cao.apiName,
      ResultParameter.mgo.apiName,
    };
    final others = values.where((v) => !majors.contains(v.parameter)).toList();

    if (others.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('その他', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(1.0),
            2: FlexColumnWidth(0.8),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            const TableRow(
              children: [
                Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('parameter', style: TextStyle(fontWeight: FontWeight.w700))),
                Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('value', style: TextStyle(fontWeight: FontWeight.w700))),
                Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('unit', style: TextStyle(fontWeight: FontWeight.w700))),
              ],
            ),
            ...others.map((v) {
              final valueText = fmt.format1OrDash(v.value);
              final unitText = (v.unit == null) ? '' : v.unit!;
              return TableRow(
                children: [
                  Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(v.parameter)),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(valueText)),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(unitText)),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }
}

class _BalanceTab extends StatelessWidget {
  final bool isCompare;
  final ResultPoint? normalPoint;
  final ResultDiffPoint? diffPoint;
  final ScrollController controller;

  const _BalanceTab({
    required this.isCompare,
    required this.normalPoint,
    required this.diffPoint,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final values = isCompare ? diffPoint!.currentValues : normalPoint!.values;

    final cec = findValueByParameter(values, ResultParameter.cec.apiName);
    if (cec == null || cec == 0) {
      return ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: const [
          Text('この地点には有効なCECデータがありません。'),
        ],
      );
    }

    double sat(String p) {
      final v = findValueByParameter(values, p);
      if (v == null) return 0.0;
      return (v / cec) * 100.0;
    }

    final k2o = sat(ResultParameter.k2o.apiName);
    final cao = sat(ResultParameter.cao.apiName);
    final mgo = sat(ResultParameter.mgo.apiName);

    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text('K2O飽和度 / CaO飽和度 / MgO飽和度', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ThreeComponentRadarChart(k2o: k2o, cao: cao, mgo: mgo),
        const SizedBox(height: 12),
        Text('K2O ${k2o.toStringAsFixed(1)}%'),
        Text('CaO ${cao.toStringAsFixed(1)}%'),
        Text('MgO ${mgo.toStringAsFixed(1)}%'),
      ],
    );
  }
}

