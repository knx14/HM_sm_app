import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../farms/domain/farm.dart';
import '../../../services/geo_service.dart';
import '../../../utils/polygon_area.dart';

class LocationConfirmResult {
  final LatLng confirmedLocation;
  final GeoFenceStatus status;

  const LocationConfirmResult({
    required this.confirmedLocation,
    required this.status,
  });
}

class LocationConfirmScreen extends StatefulWidget {
  final Farm farm;

  const LocationConfirmScreen({
    super.key,
    required this.farm,
  });

  @override
  State<LocationConfirmScreen> createState() => _LocationConfirmScreenState();
}

class _LocationConfirmScreenState extends State<LocationConfirmScreen> {
  GoogleMapController? _mapController;

  LatLng? _currentLocation;
  LatLng? _confirmedLocation;
  GeoFenceStatus _status = GeoFenceStatus.outside;
  String? _error;
  bool _loadingLocation = true;

  List<LatLng> get _farmPolygon =>
      widget.farm.boundaryPolygon.map((p) => LatLng(p['lat']!, p['lng']!)).toList();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final polygon = _farmPolygon;
    final fallback = calculatePolygonCenter(polygon);
    setState(() {
      _confirmedLocation = fallback;
      _status = GeoService.classifyLocation(point: fallback, polygon: polygon);
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = '位置情報サービスが無効です';
          _loadingLocation = false;
        });
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _error = '位置情報の権限が拒否されています（設定から許可してください）';
          _loadingLocation = false;
        });
        return;
      }
      if (perm == LocationPermission.denied) {
        setState(() {
          _error = '位置情報の権限が必要です';
          _loadingLocation = false;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final here = LatLng(pos.latitude, pos.longitude);

      if (!mounted) return;
      setState(() {
        _currentLocation = here;
        _confirmedLocation = here;
        _status = GeoService.classifyLocation(point: here, polygon: polygon);
        _loadingLocation = false;
      });

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: here, zoom: 18)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '現在地の取得に失敗しました: $e';
        _loadingLocation = false;
      });
    }
  }

  void _setConfirmed(LatLng p) {
    final polygon = _farmPolygon;
    setState(() {
      _confirmedLocation = p;
      _status = GeoService.classifyLocation(point: p, polygon: polygon);
    });
  }

  String _statusText(GeoFenceStatus s) {
    switch (s) {
      case GeoFenceStatus.inside:
        return '判定: inside（圃場内）';
      case GeoFenceStatus.edge:
        return '判定: edge（境界付近）';
      case GeoFenceStatus.outside:
        return '判定: outside（圃場外）';
    }
  }

  @override
  Widget build(BuildContext context) {
    final polygon = _farmPolygon;
    final initialTarget = _confirmedLocation ?? calculatePolygonCenter(polygon);

    final confirmed = _confirmedLocation;
    final canConfirm = confirmed != null && _status != GeoFenceStatus.outside;

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('地点を確定'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: initialTarget, zoom: 17),
                  onMapCreated: (c) => _mapController = c,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  polygons: {
                    if (polygon.length >= 3)
                      Polygon(
                        polygonId: const PolygonId('farm'),
                        points: polygon,
                        strokeWidth: 2,
                      ),
                  },
                  markers: {
                    if (confirmed != null)
                      Marker(
                        markerId: const MarkerId('confirmed'),
                        position: confirmed,
                        draggable: false,
                      ),
                  },
                  onTap: _setConfirmed,
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Material(
                    elevation: 0,
                    color: theme.colorScheme.surface.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.farm.farmName,
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(_statusText(_status), style: theme.textTheme.bodyMedium),
                          if (_status == GeoFenceStatus.edge) ...[
                            const SizedBox(height: 6),
                            Text(
                              '警告: 境界付近です。測定は可能ですが、地点を確認してください。',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 6),
                            Text(_error!, style: theme.textTheme.bodySmall),
                          ],
                          if (_loadingLocation) ...[
                            const SizedBox(height: 6),
                            Text('現在地を取得中...', style: theme.textTheme.bodySmall),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Material(
                    elevation: 0,
                    color: theme.colorScheme.surface.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_currentLocation != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () {
                                  final here = _currentLocation;
                                  if (here == null) return;
                                  _setConfirmed(here);
                                  _mapController?.animateCamera(
                                    CameraUpdate.newCameraPosition(
                                      CameraPosition(target: here, zoom: 18),
                                    ),
                                  );
                                },
                                child: const Text('現在地に戻す'),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('キャンセル'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: canConfirm
                                      ? () {
                                          final p = _confirmedLocation;
                                          if (p == null) return;
                                          Navigator.pop(
                                            context,
                                            LocationConfirmResult(
                                              confirmedLocation: p,
                                              status: _status,
                                            ),
                                          );
                                        }
                                      : null,
                                  child: const Text('測定開始'),
                                ),
                              ),
                            ],
                          ),
                          if (_status == GeoFenceStatus.outside) ...[
                            const SizedBox(height: 6),
                            Text(
                              '圃場外のため開始できません。地点を圃場内に調整してください。',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

