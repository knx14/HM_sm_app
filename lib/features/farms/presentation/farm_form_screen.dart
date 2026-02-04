import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../utils/polygon_area.dart';
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
  final PageController _pageController = PageController();
  int _currentStep = 0; // 0: Step1, 1: Step2

  // Step1: 基本情報
  final _formKey = GlobalKey<FormState>();
  final _farmNameController = TextEditingController();
  String? _selectedCultivationMethod; // 栽培方式（プルダウン選択）
  final _cropTypeController = TextEditingController();

  // Step2: 境界設定
  GoogleMapController? _mapController;
  List<LatLng> _boundaryPoints = [];
  Set<Marker> _markers = {};
  Set<Polygon> _polygons = {};
  bool _mapInitialized = false;
  String? _mapError;
  CameraPosition? _initialPosition;

  // 登録状態
  bool _isLoading = false;

  // デフォルト位置（東京）- 現在地が取得できない場合のフォールバック
  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(35.6812, 139.7671),
    zoom: 15,
  );

  @override
  void initState() {
    super.initState();
    // 30秒後にタイムアウトチェック
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && !_mapInitialized && _mapError == null && _currentStep == 1) {
        setState(() {
          _mapError = 'マップの読み込みがタイムアウトしました。\n\n考えられる原因:\n1. Google Maps APIキーの試用期間が終了している\n2. APIキーが無効または制限されている\n3. インターネット接続の問題\n\nGoogle Cloud Consoleで以下を確認してください:\n- Maps SDK for Android が有効になっているか\n- APIキーの使用制限が設定されていないか\n- 請求アカウントが有効になっているか';
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _farmNameController.dispose();
    _cropTypeController.dispose();
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
          strokeColor: Theme.of(context).colorScheme.primary,
          strokeWidth: 3,
          fillColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
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

  void _confirmBoundary() {
    if (_boundaryPoints.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('境界点は最低4点必要です（現在: ${_boundaryPoints.length}点）'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Step1に戻る
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentStep = 0;
    });
  }

  Future<void> _goToStep2() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 現在地を取得して初期位置を設定
    await _getCurrentLocation();

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentStep = 1;
    });
  }

  /// 現在地を取得して初期位置を設定
  Future<void> _getCurrentLocation() async {
    try {
      // 位置情報サービスが有効か確認
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // サービスが無効な場合はデフォルト位置を使用
        _initialPosition = _defaultPosition;
        return;
      }

      // 位置情報のパーミッションを確認
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // パーミッションが拒否された場合はデフォルト位置を使用
          _initialPosition = _defaultPosition;
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // パーミッションが永続的に拒否された場合はデフォルト位置を使用
        _initialPosition = _defaultPosition;
        return;
      }

      // 現在地を取得
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 初期位置を現在地に設定
      _initialPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 15,
      );
    } catch (e) {
      // エラーが発生した場合はデフォルト位置を使用
      debugPrint('現在地の取得に失敗しました: $e');
      _initialPosition = _defaultPosition;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_boundaryPoints.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('境界点は最低4点必要です'),
          backgroundColor: Theme.of(context).colorScheme.error,
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
        cultivationMethod: _selectedCultivationMethod,
        cropType: _cropTypeController.text.trim().isEmpty
            ? null
            : _cropTypeController.text.trim(),
        boundaryPolygon: boundaryPolygon,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('圃場を登録しました'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラー: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _currentStep == 0 ? '基本情報' : '境界設定',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStep1Form(theme, colorScheme),
          _buildStep2Map(theme, colorScheme),
        ],
      ),
      bottomNavigationBar: _currentStep == 0
          ? _buildStep1Footer(theme, colorScheme)
          : null,
    );
  }

  Widget _buildStep1Form(ThemeData theme, ColorScheme colorScheme) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ステップインジケーター
              _buildStepIndicator(colorScheme),
              const SizedBox(height: 32),

              // 基本情報カード
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '基本情報',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 圃場名
                      TextFormField(
                        controller: _farmNameController,
                        decoration: InputDecoration(
                          labelText: '圃場名',
                          hintText: '例: 第一圃場',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                        ),
                        style: theme.textTheme.bodyLarge,
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
                      const SizedBox(height: 20),

                      // 栽培方式（プルダウン）
                      DropdownButtonFormField<String>(
                        value: _selectedCultivationMethod,
                        decoration: InputDecoration(
                          labelText: '栽培方式',
                          hintText: '選択してください',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                        ),
                        style: theme.textTheme.bodyLarge,
                        items: const [
                          DropdownMenuItem<String>(
                            value: '畑',
                            child: Text('畑'),
                          ),
                          DropdownMenuItem<String>(
                            value: '施設',
                            child: Text('施設'),
                          ),
                          DropdownMenuItem<String>(
                            value: '水田',
                            child: Text('水田'),
                          ),
                        ],
                        onChanged: (String? value) {
                          setState(() {
                            _selectedCultivationMethod = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '栽培方式を選択してください';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // 作物種別
                      TextFormField(
                        controller: _cropTypeController,
                        decoration: InputDecoration(
                          labelText: '作物種別',
                          hintText: '例: トマト、レタスなど',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                        ),
                        style: theme.textTheme.bodyLarge,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '作物種別を入力してください';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 境界情報カード（境界が設定されている場合）
              if (_boundaryPoints.isNotEmpty) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _boundaryPoints.length >= 4
                          ? colorScheme.primary.withOpacity(0.3)
                          : colorScheme.error.withOpacity(0.3),
                    ),
                  ),
                  color: _boundaryPoints.length >= 4
                      ? colorScheme.primaryContainer.withOpacity(0.3)
                      : colorScheme.errorContainer.withOpacity(0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '境界情報',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildBoundaryInfo(theme, colorScheme),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 次へボタン
              FilledButton(
                onPressed: _goToStep2,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  '境界設定へ',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 100), // フッター分の余白
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(ColorScheme colorScheme) {
    return Row(
      children: [
        _buildStepDot(0, colorScheme),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep >= 1
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
          ),
        ),
        _buildStepDot(1, colorScheme),
      ],
    );
  }

  Widget _buildStepDot(int step, ColorScheme colorScheme) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive || isCompleted
            ? colorScheme.primary
            : colorScheme.outline.withOpacity(0.3),
      ),
      child: Center(
        child: Text(
          '${step + 1}',
          style: TextStyle(
            color: isActive || isCompleted
                ? colorScheme.onPrimary
                : colorScheme.onSurface.withOpacity(0.5),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBoundaryInfo(ThemeData theme, ColorScheme colorScheme) {
    final pointCount = _boundaryPoints.length;
    final area = pointCount >= 3
        ? calculatePolygonArea(_boundaryPoints)
        : 0.0;
    final center = pointCount > 0
        ? calculatePolygonCenter(_boundaryPoints)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
          '点数',
          '$pointCount点',
          theme,
          colorScheme,
        ),
        if (area > 0) ...[
          const SizedBox(height: 12),
          _buildInfoRow(
            '面積',
            formatArea(area),
            theme,
            colorScheme,
          ),
        ],
        if (center != null) ...[
          const SizedBox(height: 12),
          _buildInfoRow(
            '中心座標',
            '${center.latitude.toStringAsFixed(6)}, ${center.longitude.toStringAsFixed(6)}',
            theme,
            colorScheme,
          ),
        ],
        if (pointCount < 4) ...[
          const SizedBox(height: 12),
          Text(
            '最低4点必要（あと${4 - pointCount}点）',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep1Footer(ThemeData theme, ColorScheme colorScheme) {
    final canSubmit = _boundaryPoints.length >= 4 &&
        _farmNameController.text.trim().isNotEmpty &&
        _selectedCultivationMethod != null &&
        _cropTypeController.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        child: FilledButton(
          onPressed: canSubmit && !_isLoading ? _submitForm : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: canSubmit
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
          ),
          child: _isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.onPrimary,
                    ),
                  ),
                )
              : Text(
                  '登録',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: canSubmit
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildStep2Map(ThemeData theme, ColorScheme colorScheme) {
    return Stack(
      children: [
        // 地図
        _mapError != null
            ? _buildMapError(theme, colorScheme)
            : GoogleMap(
                initialCameraPosition: _initialPosition ?? _defaultPosition,
                onMapCreated: (GoogleMapController controller) async {
                  try {
                    setState(() {
                      _mapController = controller;
                      _mapInitialized = true;
                      _mapError = null;
                    });

                    // 現在地が設定されている場合は地図を移動
                    if (_initialPosition != null) {
                      await controller.animateCamera(
                        CameraUpdate.newCameraPosition(_initialPosition!),
                      );
                    }
                  } catch (e) {
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

        // ローディング表示
        if (!_mapInitialized && _mapError == null)
          Container(
            color: colorScheme.surface,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'マップを読み込んでいます...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 下部操作パネル
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildMapControlPanel(theme, colorScheme),
        ),
      ],
    );
  }

  Widget _buildMapError(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'マップの読み込みに失敗しました',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Card(
              color: colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _mapError!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                setState(() {
                  _mapError = null;
                  _mapInitialized = false;
                });
              },
              child: const Text('再試行'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControlPanel(ThemeData theme, ColorScheme colorScheme) {
    final pointCount = _boundaryPoints.length;
    final area = pointCount >= 3
        ? calculatePolygonArea(_boundaryPoints)
        : 0.0;
    final canConfirm = pointCount >= 4;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 境界情報
            if (pointCount > 0) ...[
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '境界情報',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              '点数',
                              '$pointCount点',
                              theme,
                              colorScheme,
                            ),
                          ),
                          if (area > 0)
                            Expanded(
                              child: _buildInfoItem(
                                '面積',
                                formatArea(area),
                                theme,
                                colorScheme,
                              ),
                            ),
                        ],
                      ),
                      if (pointCount < 4) ...[
                        const SizedBox(height: 8),
                        Text(
                          '最低4点必要（あと${4 - pointCount}点）',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 操作ボタン
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _boundaryPoints.isNotEmpty
                        ? _removeLastPoint
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '1つ戻す',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _boundaryPoints.isNotEmpty
                        ? _clearAllPoints
                        : null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'クリア',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: canConfirm ? _confirmBoundary : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: canConfirm
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                    ),
                    child: Text(
                      '確定',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: canConfirm
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
