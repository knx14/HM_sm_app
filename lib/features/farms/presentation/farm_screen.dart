import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../providers/user_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../utils/static_maps.dart';
import '../../../utils/polygon_area.dart';
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
  String? _googleMapsApiKey;
  
  static const MethodChannel _channel = MethodChannel('com.example.hmapp_smartphone/google_maps_api_key');

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
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadGoogleMapsApiKey();
    await _loadFarms();
  }

  /// AndroidManifest.xmlからGoogle Maps APIキーを取得（MethodChannel経由）
  Future<void> _loadGoogleMapsApiKey() async {
    try {
      final apiKey = await _channel.invokeMethod<String>('getGoogleMapsApiKey');
      if (apiKey != null && apiKey.isNotEmpty) {
        setState(() {
          _googleMapsApiKey = apiKey;
        });
        if (kDebugMode) {
          debugPrint('Google Maps APIキーを取得しました: ${apiKey.substring(0, 10)}... (長さ: ${apiKey.length})');
        }
      } else {
        if (kDebugMode) {
          debugPrint('Google Maps APIキーが取得できませんでした（nullまたは空）');
        }
        // フォールバック: local.propertiesから直接読み込む（開発用）
        await _loadApiKeyFromLocalProperties();
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('Google Maps APIキーの取得に失敗（PlatformException）: ${e.message}');
        debugPrint('エラーコード: ${e.code}');
      }
      // フォールバック: local.propertiesから直接読み込む（開発用）
      await _loadApiKeyFromLocalProperties();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Google Maps APIキーの取得に失敗: $e');
      }
      // フォールバック: local.propertiesから直接読み込む（開発用）
      await _loadApiKeyFromLocalProperties();
    }
  }

  /// local.propertiesから直接APIキーを読み込む（開発用フォールバック）
  Future<void> _loadApiKeyFromLocalProperties() async {
    try {
      final file = File('android/local.properties');
      if (await file.exists()) {
        final content = await file.readAsString();
        final lines = content.split('\n');
        for (final line in lines) {
          if (line.startsWith('GOOGLE_MAPS_API_KEY=')) {
            final apiKey = line.substring('GOOGLE_MAPS_API_KEY='.length).trim();
            if (apiKey.isNotEmpty) {
              setState(() {
                _googleMapsApiKey = apiKey;
              });
              if (kDebugMode) {
                debugPrint('local.propertiesからAPIキーを読み込みました: ${apiKey.substring(0, 10)}...');
              }
              return;
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('local.propertiesからの読み込みも失敗: $e');
      }
    }
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

  /// 境界点をLatLngのリストに変換
  List<LatLng> _boundaryPolygonToLatLng(List<Map<String, double>> boundaryPolygon) {
    return boundaryPolygon.map((point) {
      return LatLng(point['lat']!, point['lng']!);
    }).toList();
  }

  /// 圃場カードウィジェット
  Widget _buildFarmCard(Farm farm, ThemeData theme, ColorScheme colorScheme) {
    final boundaryPoints = _boundaryPolygonToLatLng(farm.boundaryPolygon);
    final center = boundaryPoints.isNotEmpty
        ? _calculateCenter(boundaryPoints)
        : const LatLng(35.6812, 139.7671);
    final area = boundaryPoints.length >= 3
        ? calculatePolygonArea(boundaryPoints)
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: InkWell(
        onTap: () {
          // TODO: 圃場詳細画面へ遷移
          debugPrint('圃場詳細: ${farm.farmName}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左側: 地図サムネイル
                  _buildMapThumbnail(
                    farm: farm,
                    boundaryPoints: boundaryPoints,
                    center: center,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(width: 12),
                  // 右側: 圃場情報（編集アイコンのスペースを確保）
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 40), // 編集アイコンのスペース
                      child: _buildFarmInfo(
                        farm: farm,
                        area: area,
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 右上に編集アイコン
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FarmFormScreen(
                          farmRepository: _farmRepository,
                          farm: farm, // 既存の圃場データを渡す
                        ),
                      ),
                    );

                    // 更新成功時は一覧を再読み込み
                    if (result == true) {
                      _loadFarms();
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.edit,
                      size: 20,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 地図サムネイルウィジェット
  Widget _buildMapThumbnail({
    required Farm farm,
    required List<LatLng> boundaryPoints,
    required LatLng center,
    required ColorScheme colorScheme,
  }) {
    // カードの3分の1程度のサイズに調整
    const double thumbnailWidth = 100.0;
    const double thumbnailHeight = 90.0;
    const double borderRadius = 12.0;

    // APIキーがない場合はプレースホルダー
    if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) {
      return _buildMapPlaceholder(
        width: thumbnailWidth,
        height: thumbnailHeight,
        borderRadius: borderRadius,
        colorScheme: colorScheme,
      );
    }

    // Static Maps APIのURLを生成
    // キャッシュバスター: farm.idとupdatedAtを使用（変更時のみ再生成）
    final cacheBuster = '${farm.id}_${farm.updatedAt?.millisecondsSinceEpoch ?? farm.createdAt?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}';
    
    final mapUrl = buildStaticMapUrl(
      boundaryPoints: boundaryPoints,
      apiKey: _googleMapsApiKey!,
      width: (thumbnailWidth * 2).toInt(), // scale=2なので2倍
      height: (thumbnailHeight * 2).toInt(),
      cacheBuster: cacheBuster,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: thumbnailWidth,
        height: thumbnailHeight,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: CachedNetworkImage(
          imageUrl: mapUrl,
          key: ValueKey(mapUrl), // URLが変わったら必ず再描画されるように
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high, // 高品質フィルタリング
          // メモリキャッシュサイズ（高解像度画像用）
          memCacheWidth: (thumbnailWidth * 2).toInt(),
          memCacheHeight: (thumbnailHeight * 2).toInt(),
          // ローディング中
          placeholder: (context, url) => _buildMapSkeleton(
            width: thumbnailWidth,
            height: thumbnailHeight,
            colorScheme: colorScheme,
          ),
          // エラー時
          errorWidget: (context, url, error) {
            if (kDebugMode) {
              debugPrint('地図画像の読み込みエラー: $error');
              debugPrint('URL: ${mapUrl.replaceAll(_googleMapsApiKey ?? '', '***')}');
            }
            return _buildMapPlaceholder(
              width: thumbnailWidth,
              height: thumbnailHeight,
              borderRadius: borderRadius,
              colorScheme: colorScheme,
            );
          },
        ),
      ),
    );
  }

  /// 地図スケルトン（ローディング中）
  Widget _buildMapSkeleton({
    required double width,
    required double height,
    required ColorScheme colorScheme,
  }) {
    return Container(
      width: width,
      height: height,
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }

  /// 地図プレースホルダー（エラー時）
  Widget _buildMapPlaceholder({
    required double width,
    required double height,
    required double borderRadius,
    required ColorScheme colorScheme,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Center(
        child: Text(
          'Map',
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.4),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// 圃場情報ウィジェット
  Widget _buildFarmInfo({
    required Farm farm,
    required double area,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    // 画像の高さ（90）と同じ高さに設定、上下に10pxずつスペースを設ける
    return SizedBox(
      height: 90, // 画像の高さと同じ
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10), // 上下に10pxずつスペース
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // 圃場名（文字サイズを少し小さく）
            Text(
              farm.farmName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
                fontSize: 16,
                height: 1.2, // 行の高さを小さく
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4), // 小さなスペース
            // 栽培方式と栽培種目を横並び
            Row(
              children: [
                // 栽培方式
                Text(
                  farm.cultivationMethod ?? '未設定',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 13,
                    height: 1.2, // 行の高さを小さく
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(width: 8), // スペースで間隔をあける
                // 栽培種目
                Flexible(
                  child: Text(
                    farm.cropType ?? '未設定',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontSize: 13,
                      height: 1.2, // 行の高さを小さく
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4), // 小さなスペース
            // 面積（必ず表示）
            Text(
              area > 0 ? formatArea(area) : '面積未設定',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.6),
                fontSize: 12,
                height: 1.2, // 行の高さを小さく
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// 日付をフォーマット
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '今日';
    } else if (difference.inDays == 1) {
      return '昨日';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}日前';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}週間前';
    } else {
      return '${date.year}/${date.month}/${date.day}';
    }
  }

  /// 中心座標を計算
  LatLng _calculateCenter(List<LatLng> points) {
    if (points.isEmpty) {
      return const LatLng(35.6812, 139.7671);
    }

    double sumLat = 0.0;
    double sumLng = 0.0;

    for (final point in points) {
      sumLat += point.latitude;
      sumLng += point.longitude;
    }

    return LatLng(
      sumLat / points.length,
      sumLng / points.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          '圃場管理',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (_isLoading && _farms.isEmpty) {
            return Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
              ),
            );
          }

          if (_error != null && _farms.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'エラーが発生しました',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loadFarms,
                      child: const Text('再試行'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_farms.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '登録されている圃場がありません',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '新しい圃場を登録してください',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadFarms,
            color: colorScheme.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _farms.length,
              itemBuilder: (context, index) {
                return _buildFarmCard(_farms[index], theme, colorScheme);
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
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.add),
        tooltip: '圃場を登録',
      ),
    );
  }
}

