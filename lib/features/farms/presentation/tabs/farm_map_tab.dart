import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../results/domain/farm_result_date.dart';
import '../../../results/domain/result_parameter.dart';
import '../../../results/presentation/providers/result_map_notifier.dart';
import '../../../results/presentation/widgets/point_result_bottom_sheet.dart';
import '../../../results/presentation/widgets/result_legend.dart';
import '../../../results/utils/result_formatters.dart' as fmt;
import '../../../results/utils/result_map_bounds.dart';
import '../../domain/farm.dart';

class FarmMapTab extends StatelessWidget {
  const FarmMapTab({
    super.key,
    required this.farm,
    required this.dates,
    required this.selectedDate,
    required this.isLoadingDates,
    required this.onRefreshDates,
    required this.onDateSelected,
  });

  final Farm farm;
  final List<FarmResultDateItem> dates;
  final DateTime? selectedDate;
  final bool isLoadingDates;
  final Future<void> Function() onRefreshDates;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final date = selectedDate;
    if (isLoadingDates && date == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (date == null) {
      return _EmptyMapState(onRefresh: onRefreshDates);
    }

    return ChangeNotifierProvider(
      key: ValueKey('${farm.id}_${date.toIso8601String()}'),
      create: (_) =>
          ResultMapNotifier(farmId: farm.id, date: date)..loadInitial(),
      child: _FarmMapView(
        dates: dates,
        selectedDate: date,
        onDateSelected: onDateSelected,
      ),
    );
  }
}

class _FarmMapView extends StatefulWidget {
  const _FarmMapView({
    required this.dates,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final List<FarmResultDateItem> dates;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  State<_FarmMapView> createState() => _FarmMapViewState();
}

class _FarmMapViewState extends State<_FarmMapView> {
  GoogleMapController? _mapController;
  bool _didFit = false;

  static const _fallbackCamera = CameraPosition(
    target: LatLng(35.6812, 139.7671),
    zoom: 12,
  );

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ResultMapNotifier>(
      builder: (context, state, child) {
        final colorScheme = Theme.of(context).colorScheme;
        final boundary = state.boundaryPolygon;
        final pointLatLngs = state.normalPoints
            .map((point) => LatLng(point.lat, point.lng))
            .toList(growable: false);
        final hasBoundary = boundary.isNotEmpty;
        final hasPoints = pointLatLngs.isNotEmpty;
        final bounds = hasBoundary
            ? boundsFromLatLngs(boundary)
            : (hasPoints ? boundsFromLatLngs(pointLatLngs) : null);

        if (_mapController != null &&
            !_didFit &&
            bounds != null &&
            state.normalData != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            try {
              await _mapController!.animateCamera(
                CameraUpdate.newLatLngBounds(bounds, 56),
              );
              _didFit = true;
            } catch (_) {
              // GoogleMap の初回レイアウト前は失敗することがあるため無視する。
            }
          });
        }

        final stats = state.currentStats;
        final parameter = state.parameter;
        final legendMin = stats.min ?? 0.0;
        final legendMax = stats.max ?? 0.0;

        return Column(
          children: [
            _MapToolbar(
              dates: widget.dates,
              selectedDate: widget.selectedDate,
              selectedParameter: parameter,
              isUpdating: state.isLoading || state.isUpdatingMarkers,
              onDateSelected: (date) {
                _didFit = false;
                widget.onDateSelected(date);
              },
              onParameterSelected: (parameter) {
                context.read<ResultMapNotifier>().setParameter(parameter);
              },
            ),
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: _fallbackCamera,
                    mapType: MapType.satellite,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    onMapCreated: (controller) {
                      setState(() => _mapController = controller);
                    },
                    markers: state.markerVms
                        .map(
                          (marker) => Marker(
                            markerId: MarkerId('pt_${marker.pointId}'),
                            position: marker.position,
                            icon: marker.icon,
                            onTap: () {
                              final point = context
                                  .read<ResultMapNotifier>()
                                  .findNormalPoint(marker.pointId);
                              if (point == null) return;
                              showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => DefaultTabController(
                                  length: 2,
                                  child: PointResultBottomSheet.normal(
                                    point: point,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                        .toSet(),
                    polygons: hasBoundary
                        ? {
                            Polygon(
                              polygonId: const PolygonId('farm_boundary'),
                              points: boundary,
                              strokeWidth: 2,
                              strokeColor: colorScheme.primary.withValues(
                                alpha: 0.9,
                              ),
                              fillColor: colorScheme.primary.withValues(
                                alpha: 0.08,
                              ),
                            ),
                          }
                        : {},
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: ResultLegend(
                      isCompare: false,
                      parameter: parameter,
                      min: legendMin,
                      max: legendMax,
                      deltaMax: 0,
                    ),
                  ),
                  if (state.isLoading && state.normalData == null)
                    const Center(child: CircularProgressIndicator()),
                  if (state.error != null && state.normalData == null)
                    Center(
                      child: Card(
                        margin: const EdgeInsets.all(24),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('マップデータの取得に失敗しました'),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: context
                                    .read<ResultMapNotifier>()
                                    .loadInitial,
                                child: const Text('再読み込み'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (state.normalData != null &&
                      state.markerVms.isEmpty &&
                      !state.isLoading)
                    const Center(child: Text('この日の測定データがありません')),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MapToolbar extends StatelessWidget {
  const _MapToolbar({
    required this.dates,
    required this.selectedDate,
    required this.selectedParameter,
    required this.isUpdating,
    required this.onDateSelected,
    required this.onParameterSelected,
  });

  final List<FarmResultDateItem> dates;
  final DateTime selectedDate;
  final ResultParameter selectedParameter;
  final bool isUpdating;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<ResultParameter> onParameterSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          children: [
            DropdownButtonFormField<DateTime>(
              initialValue: selectedDate,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: '測定日',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: dates
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.measurementDate,
                      child: Text(
                        '${fmt.formatYyyyMmDdSlash(item.measurementDate)}（${item.cecStats.countPoints}点）',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: isUpdating
                  ? null
                  : (date) {
                      if (date != null) {
                        onDateSelected(date);
                      }
                    },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ResultParameter>(
                segments: const [
                  ButtonSegment(value: ResultParameter.cec, label: Text('CEC')),
                  ButtonSegment(value: ResultParameter.cao, label: Text('CaO')),
                  ButtonSegment(value: ResultParameter.k2o, label: Text('K2O')),
                  ButtonSegment(value: ResultParameter.mgo, label: Text('MgO')),
                ],
                selected: {selectedParameter},
                showSelectedIcon: false,
                onSelectionChanged: isUpdating
                    ? null
                    : (values) => onParameterSelected(values.first),
              ),
            ),
            if (isUpdating) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }
}

class _EmptyMapState extends StatelessWidget {
  const _EmptyMapState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('表示できる測定日がありません'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRefresh, child: const Text('再読み込み')),
          ],
        ),
      ),
    );
  }
}
