import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/farm_repository.dart';

class FarmFormScreen extends StatefulWidget {
  final FarmRepository farmRepository;

  const FarmFormScreen({
    required this.farmRepository,
    super.key,
  });

  @override
  State<FarmFormScreen> createState() => _FarmFormScreenState();
}

class _FarmFormScreenState extends State<FarmFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _farmNameController = TextEditingController();
  final _cultivationMethodController = TextEditingController();
  final _cropTypeController = TextEditingController();
  final _scrollController = ScrollController();

  GoogleMapController? _mapController;
  List<LatLng> _boundaryPoints = [];
  Set<Marker> _markers = {};
  Set<Polygon> _polygons = {};
  bool _isLoading = false;
  bool _mapInitialized = false;
  String? _mapError;
  DateTime? _mapLoadStartTime;

  // 初期位置（東京）
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(35.6812, 139.7671),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    _mapLoadStartTime = DateTime.now();
    // 30秒後にタイムアウトチェック
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && !_mapInitialized && _mapError == null) {
        setState(() {
          _mapError = 'マップの読み込みがタイムアウトしました。\n\n考えられる原因:\n1. Google Maps APIキーの試用期間が終了している\n2. APIキーが無効または制限されている\n3. インターネット接続の問題\n\nGoogle Cloud Consoleで以下を確認してください:\n- Maps SDK for Android が有効になっているか\n- APIキーの使用制限が設定されていないか\n- 請求アカウントが有効になっているか';
        });
      }
    });
  }

  @override
  void dispose() {
    _farmNameController.dispose();
    _cultivationMethodController.dispose();
    _cropTypeController.dispose();
    _scrollController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapTap(LatLng position) {
    setState(() {
      _boundaryPoints.add(position);
      _updateMarkersAndPolygon();
    });
  }

  void _updateMarkersAndPolygon() {
    // マーカーを更新
    _markers = _boundaryPoints.asMap().entries.map((entry) {
      int index = entry.key;
      LatLng point = entry.value;
      return Marker(
        markerId: MarkerId('point_$index'),
        position: point,
        infoWindow: InfoWindow(
          title: 'ポイント ${index + 1}',
          snippet: '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueGreen,
        ),
      );
    }).toSet();

    // ポリゴンを更新（3点以上の場合）
    if (_boundaryPoints.length >= 3) {
      _polygons = {
        Polygon(
          polygonId: const PolygonId('boundary'),
          points: _boundaryPoints,
          strokeColor: Colors.green,
          strokeWidth: 2,
          fillColor: Colors.green.withOpacity(0.3),
        ),
      };
    } else {
      _polygons = {};
    }
  }

  void _removeLastPoint() {
    if (_boundaryPoints.isNotEmpty) {
      setState(() {
        _boundaryPoints.removeLast();
        _updateMarkersAndPolygon();
      });
    }
  }

  void _clearAllPoints() {
    setState(() {
      _boundaryPoints.clear();
      _markers.clear();
      _polygons.clear();
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_boundaryPoints.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('境界点は最低4点必要です'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // boundaryPolygonをMap形式に変換
      final boundaryPolygon = _boundaryPoints.map((point) {
        return {
          'lat': point.latitude,
          'lng': point.longitude,
        };
      }).toList();

      await widget.farmRepository.createFarm(
        farmName: _farmNameController.text.trim(),
        cultivationMethod: _cultivationMethodController.text.trim().isEmpty
            ? null
            : _cultivationMethodController.text.trim(),
        cropType: _cropTypeController.text.trim().isEmpty
            ? null
            : _cropTypeController.text.trim(),
        boundaryPolygon: boundaryPolygon,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('圃場を登録しました'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true); // 成功時にtrueを返す
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラー: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('圃場登録'),
        elevation: 0,
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // フォーム部分（モダンなデザイン）
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 圃場名
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.agriculture,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  '基本情報',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _farmNameController,
                              decoration: InputDecoration(
                                labelText: '圃場名',
                                hintText: '例: 第一圃場',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                prefixIcon: const Icon(Icons.edit),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return '圃場名を入力してください';
                                }
                                if (value.length > 50) {
                                  return '圃場名は50文字以内で入力してください';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _cultivationMethodController,
                              decoration: InputDecoration(
                                labelText: '栽培方法',
                                hintText: '例: 有機栽培、慣行栽培など',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                prefixIcon: const Icon(Icons.eco),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _cropTypeController,
                              decoration: InputDecoration(
                                labelText: '作物種別',
                                hintText: '例: トマト、レタスなど',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                prefixIcon: const Icon(Icons.local_florist),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 境界点の情報（モダンなデザイン）
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: _boundaryPoints.length >= 4
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _boundaryPoints.length >= 4
                                        ? Colors.green.shade100
                                        : Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.map,
                                    color: _boundaryPoints.length >= 4
                                        ? Colors.green
                                        : Colors.orange,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '境界点: ${_boundaryPoints.length}点',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      if (_boundaryPoints.length < 4)
                                        Text(
                                          '最低4点必要（あと${4 - _boundaryPoints.length}点）',
                                          style: TextStyle(
                                            color: Colors.orange.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        )
                                      else
                                        Text(
                                          '登録可能です',
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'マップ上をタップして境界点を追加してください',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                            if (_boundaryPoints.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _removeLastPoint,
                                      icon: const Icon(Icons.undo, size: 18),
                                      label: const Text('最後を削除'),
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _clearAllPoints,
                                      icon: const Icon(Icons.clear, size: 18),
                                      label: const Text('すべて削除'),
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // マップ部分
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                ),
                child: _mapError != null
                    ? Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'マップの読み込みに失敗しました',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Card(
                                color: Colors.red.shade50,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    _mapError!,
                                    textAlign: TextAlign.left,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _mapError = null;
                                        _mapInitialized = false;
                                        _mapLoadStartTime = DateTime.now();
                                      });
                                    },
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('再試行'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                    icon: const Icon(Icons.arrow_back),
                                    label: const Text('戻る'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : Stack(
                        children: [
                          GoogleMap(
                            initialCameraPosition: _initialPosition,
                            onMapCreated: (GoogleMapController controller) {
                              try {
                                setState(() {
                                  _mapController = controller;
                                  _mapInitialized = true;
                                  _mapError = null;
                                  _mapLoadStartTime = null;
                                });
                                print('Google Maps initialized successfully');
                              } catch (e) {
                                print('Google Maps initialization error: $e');
                                setState(() {
                                  _mapError = 'マップの初期化に失敗しました: $e';
                                  _mapInitialized = false;
                                });
                              }
                            },
                            onTap: _onMapTap,
                            markers: _markers,
                            polygons: _polygons,
                            myLocationButtonEnabled: true,
                            myLocationEnabled: true,
                            mapType: MapType.satellite,
                            zoomControlsEnabled: true,
                            compassEnabled: true,
                            liteModeEnabled: false,
                            mapToolbarEnabled: false,
                          ),
                          if (!_mapInitialized)
                            Container(
                              color: Colors.grey.shade200,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 16),
                                    const Text('マップを読み込んでいます...'),
                                    const SizedBox(height: 8),
                                    Text(
                                      _mapLoadStartTime != null
                                          ? '読み込み時間: ${DateTime.now().difference(_mapLoadStartTime!).inSeconds}秒'
                                          : '',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _mapError = 'マップの読み込みがタイムアウトしました。\n\n考えられる原因:\n1. Google Maps APIキーの試用期間が終了している\n2. インターネット接続の問題\n3. APIキーの設定が正しくない\n\nGoogle Cloud ConsoleでAPIキーの状態を確認してください。';
                                          _mapInitialized = false;
                                        });
                                      },
                                      child: const Text('タイムアウト'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _submitForm,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.save),
        label: const Text('登録'),
        backgroundColor: _boundaryPoints.length >= 4
            ? Colors.green.shade700
            : Colors.grey,
        foregroundColor: Colors.white,
      ),
    );
  }
}

