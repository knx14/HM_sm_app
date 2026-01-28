import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../domain/result_parameter.dart';
import '../utils/result_formatters.dart' as fmt;
import '../utils/result_map_bounds.dart';
import 'providers/result_map_notifier.dart';
import 'widgets/point_result_bottom_sheet.dart';
import 'widgets/result_legend.dart';

class ResultMapScreen extends StatefulWidget {
  final int farmId;
  final DateTime date;

  const ResultMapScreen({
    super.key,
    required this.farmId,
    required this.date,
  });

  @override
  State<ResultMapScreen> createState() => _ResultMapScreenState();
}

class _ResultMapScreenState extends State<ResultMapScreen> {
  GoogleMapController? _mapController;
  bool _didFit = false;

  static const _tokyo = CameraPosition(target: LatLng(35.6812, 139.7671), zoom: 12);

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ResultMapNotifier(farmId: widget.farmId, date: widget.date)..loadInitial(),
      child: Consumer<ResultMapNotifier>(
        builder: (context, state, child) {
          final cs = Theme.of(context).colorScheme;

          final boundary = state.boundaryPolygon;
          final pointLatLngs = state.isCompare
              ? state.diffPoints.map((p) => LatLng(p.lat, p.lng)).toList(growable: false)
              : state.normalPoints.map((p) => LatLng(p.lat, p.lng)).toList(growable: false);

          final hasPoly = boundary.isNotEmpty;
          final hasPts = pointLatLngs.isNotEmpty;
          final bounds = hasPoly
              ? boundsFromLatLngs(boundary)
              : (hasPts ? boundsFromLatLngs(pointLatLngs) : null);

          if (_mapController != null && !_didFit && bounds != null && state.normalData != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              try {
                await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 56));
                _didFit = true;
              } catch (_) {
                // fitBounds失敗時は無視
              }
            });
          }

          final stats = state.currentStats;
          final param = state.parameter;

          final headerLine3 = state.isCompare
              ? '${param.apiName} 差分 -${fmt.format1OrZero(state.deltaMax)}–+${fmt.format1OrZero(state.deltaMax)}'
              : '${param.apiName} 平均 ${fmt.format1OrDash(stats.avg)} / ${fmt.format1OrDash(stats.min)}–${fmt.format1OrDash(stats.max)}';

          final legendMin = stats.min ?? 0.0;
          final legendMax = stats.max ?? 0.0;
          final legendDelta = state.deltaMax;

          return Scaffold(
            backgroundColor: cs.surface,
            body: SafeArea(
              child: Column(
                children: [
                  _Header(
                    farmName: state.farmName,
                    date: widget.date,
                    parameter: param,
                    isCompare: state.isCompare,
                    isTogglingCompare: state.isTogglingCompare,
                    headerLine3: headerLine3,
                    previousDate: state.previousMeasurementDate,
                    onToggleCompare: (v) async {
                      if (v) {
                        final ok = await context.read<ResultMapNotifier>().enableCompare();
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('前回データがありません')),
                          );
                          // 自動でOFF（stateがnormalのままなのでSwitchも戻る）
                        }
                      } else {
                        await context.read<ResultMapNotifier>().disableCompare();
                      }
                    },
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        GoogleMap(
                          initialCameraPosition: _tokyo,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          onMapCreated: (c) => setState(() => _mapController = c),
                          markers: state.markerVms
                              .map(
                                (m) => Marker(
                                  markerId: MarkerId('pt_${m.pointId}'),
                                  position: m.position,
                                  icon: m.icon,
                                  onTap: () {
                                    final notifier = context.read<ResultMapNotifier>();
                                    if (notifier.isCompare) {
                                      final p = notifier.findDiffPoint(m.pointId);
                                      if (p == null) return;
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) => DefaultTabController(
                                          length: 2,
                                          child: PointResultBottomSheet.compare(point: p),
                                        ),
                                      );
                                    } else {
                                      final p = notifier.findNormalPoint(m.pointId);
                                      if (p == null) return;
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) => DefaultTabController(
                                          length: 2,
                                          child: PointResultBottomSheet.normal(point: p),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              )
                              .toSet(),
                          polygons: hasPoly
                              ? {
                                  Polygon(
                                    polygonId: const PolygonId('farm_boundary'),
                                    points: boundary,
                                    strokeWidth: 2,
                                    strokeColor: cs.primary.withValues(alpha: 0.9),
                                    fillColor: cs.primary.withValues(alpha: 0.08),
                                  ),
                                }
                              : {},
                        ),
                        Positioned(
                          left: 12,
                          bottom: 72,
                          child: ResultLegend(
                            isCompare: state.isCompare,
                            parameter: param,
                            min: legendMin,
                            max: legendMax,
                            deltaMax: legendDelta,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _ParameterSegment(
                            selected: param,
                            onChanged: (p) => context.read<ResultMapNotifier>().setParameter(p),
                          ),
                        ),
                        if (state.isLoading && state.normalData == null)
                          const Center(child: CircularProgressIndicator()),
                        if (state.error != null && state.normalData == null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('取得に失敗しました'),
                                  const SizedBox(height: 12),
                                  FilledButton(
                                    onPressed: context.read<ResultMapNotifier>().loadInitial,
                                    child: const Text('再読み込み'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String farmName;
  final DateTime date;
  final ResultParameter parameter;
  final bool isCompare;
  final bool isTogglingCompare;
  final String headerLine3;
  final DateTime? previousDate;
  final Future<void> Function(bool) onToggleCompare;

  const _Header({
    required this.farmName,
    required this.date,
    required this.parameter,
    required this.isCompare,
    required this.isTogglingCompare,
    required this.headerLine3,
    required this.previousDate,
    required this.onToggleCompare,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outline.withValues(alpha: 0.08))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    farmName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(fmt.formatYyyyMmDdSlash(date), style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text('表示: ${parameter.apiName}')),
                Row(
                  children: [
                    const Text('比較'),
                    const SizedBox(width: 6),
                    Switch(
                      value: isCompare,
                      onChanged: isTogglingCompare ? null : onToggleCompare,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(headerLine3),
            if (isCompare && previousDate != null) ...[
              const SizedBox(height: 4),
              Text('前回: ${fmt.formatYyyyMmDdSlash(previousDate!)}', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7))),
            ],
          ],
        ),
      ),
    );
  }
}

class _ParameterSegment extends StatelessWidget {
  final ResultParameter selected;
  final ValueChanged<ResultParameter> onChanged;

  const _ParameterSegment({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.08))),
      ),
      child: SegmentedButton<ResultParameter>(
        segments: const [
          ButtonSegment(value: ResultParameter.cec, label: Text('CEC')),
          ButtonSegment(value: ResultParameter.k2o, label: Text('K2O')),
          ButtonSegment(value: ResultParameter.cao, label: Text('CaO')),
          ButtonSegment(value: ResultParameter.mgo, label: Text('MgO')),
        ],
        selected: {selected},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.first),
      ),
    );
  }
}

