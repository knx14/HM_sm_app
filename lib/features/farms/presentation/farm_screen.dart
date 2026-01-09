import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/user_provider.dart';
import '../../../core/api/api_client.dart';
import '../../auth/data/amplify_auth_service.dart';
import '../data/farm_repository.dart';
import '../domain/farm.dart';
import 'farm_form_screen.dart';

class FarmScreen extends StatefulWidget {
  const FarmScreen({super.key});

  @override
  State<FarmScreen> createState() => _FarmScreenState();
}

class _FarmScreenState extends State<FarmScreen> {
  late final FarmRepository _farmRepository;
  List<Farm> _farms = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // APIクライアントとリポジトリを初期化
    final authService = AmplifyAuthService();
    final baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.hm-admin.com',
    );
    final apiClient = ApiClient(
      baseUrl: baseUrl,
      authService: authService,
    );
    _farmRepository = FarmRepository(apiClient);
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final farms = await _farmRepository.getFarms();
      setState(() {
        _farms = farms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }


  /// 圃場カードウィジェット
  Widget _buildFarmCard(Farm farm) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左側: 地図画像
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
              child: farm.boundaryPolygon.isNotEmpty
                  ? _buildMapPlaceholder(farm)
                  : Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.map,
                        color: Colors.grey,
                        size: 40,
                      ),
                    ),
            ),
          ),
          // 右側: 圃場情報
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    farm.farmName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (farm.cultivationMethod != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.agriculture, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            farm.cultivationMethod!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (farm.cropType != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.local_florist, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            farm.cropType!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    );
  }

  /// 地図プレースホルダー（boundary_polygonを描画）
  Widget _buildMapPlaceholder(Farm farm) {
    return CustomPaint(
      painter: _MapPolygonPainter(farm.boundaryPolygon),
      child: Container(
        color: Colors.grey[100],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('圃場管理'),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (_isLoading && _farms.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (_error != null && _farms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'エラーが発生しました',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadFarms,
                    child: const Text('再試行'),
                  ),
                ],
              ),
            );
          }

          if (_farms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.agriculture, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    '登録されている圃場がありません',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '新しい圃場を登録してください',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadFarms,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _farms.length,
              itemBuilder: (context, index) {
                return _buildFarmCard(_farms[index]);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FarmFormScreen(
                farmRepository: _farmRepository,
              ),
            ),
          );
          
          // 登録成功時は一覧を再読み込み
          if (result == true) {
            _loadFarms();
          }
        },
        child: const Icon(Icons.add),
        tooltip: '圃場を登録',
      ),
    );
  }
}

/// 地図上にポリゴンを描画するカスタムペインター
class _MapPolygonPainter extends CustomPainter {
  final List<Map<String, double>> boundaryPolygon;

  _MapPolygonPainter(this.boundaryPolygon);

  @override
  void paint(Canvas canvas, Size size) {
    if (boundaryPolygon.isEmpty) return;

    // 境界点の座標を正規化（0-1の範囲に変換）
    double minLat = boundaryPolygon.map((p) => p['lat']!).reduce((a, b) => a < b ? a : b);
    double maxLat = boundaryPolygon.map((p) => p['lat']!).reduce((a, b) => a > b ? a : b);
    double minLng = boundaryPolygon.map((p) => p['lng']!).reduce((a, b) => a < b ? a : b);
    double maxLng = boundaryPolygon.map((p) => p['lng']!).reduce((a, b) => a > b ? a : b);

    // マージンを追加
    double latRange = maxLat - minLat;
    double lngRange = maxLng - minLng;
    double margin = 0.1; // 10%のマージン
    minLat -= latRange * margin;
    maxLat += latRange * margin;
    minLng -= lngRange * margin;
    maxLng += lngRange * margin;

    // 座標を画面座標に変換
    List<Offset> points = boundaryPolygon.map((p) {
      double x = ((p['lng']! - minLng) / (maxLng - minLng)) * size.width;
      double y = ((maxLat - p['lat']!) / (maxLat - minLat)) * size.height;
      return Offset(x, y);
    }).toList();

    // ポリゴンを描画
    final paint = Paint()
      ..color = Colors.green.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final path = Path();
    if (points.isNotEmpty) {
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      path.close();
    }

    canvas.drawPath(path, paint);

    // 境界線を描画
    final strokePaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
