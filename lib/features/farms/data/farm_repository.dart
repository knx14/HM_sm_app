import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../domain/farm.dart';
import 'farm_cache_store.dart';

class FarmCacheUnavailableException implements Exception {
  const FarmCacheUnavailableException();

  @override
  String toString() {
    return 'ネットワークに接続できません。一度オンラインで起動すると、次回からオフラインでも使用できます。';
  }
}

class FarmRepository {
  final ApiClient apiClient;
  final FarmCacheStore _cache;
  bool wasLastResultFromCache = false;

  FarmRepository(this.apiClient, {FarmCacheStore? cache})
    : _cache = cache ?? FarmCacheStore();

  /// 自分の圃場一覧を取得
  Future<List<Farm>> getFarms() async {
    wasLastResultFromCache = false;
    try {
      final response = await apiClient.dio.get('/api/v1/farms');
      print('=== 圃場一覧取得レスポンス ===');
      print('Response status: ${response.statusCode}');
      print('Response data type: ${response.data.runtimeType}');
      final data = _extractFarmList(response.data);
      final farms = data.map((json) => Farm.fromJson(json)).toList();
      await _cache.save(farms.map((farm) => farm.toJson()).toList());
      return farms;
    } on DioException catch (e) {
      print('Error fetching farms: $e');
      if (_isOfflineError(e)) {
        final cached = await _cache.load();
        if (cached == null) {
          throw const FarmCacheUnavailableException();
        }
        wasLastResultFromCache = true;
        return cached.map((json) => Farm.fromJson(json)).toList();
      }
      rethrow;
    }
  }

  List<Map<String, dynamic>> _extractFarmList(dynamic data) {
    final rawList = data is Map ? data['data'] ?? data['farms'] ?? data : data;
    if (rawList is! List) {
      throw const FormatException('Invalid farms response');
    }
    return rawList
        .whereType<Map>()
        .map((json) => Map<String, dynamic>.from(json))
        .toList();
  }

  bool _isOfflineError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.receiveTimeout;
  }

  /// 圃場を登録
  ///
  /// [farmName] 圃場名（必須、最大50文字）
  /// [cultivationMethod] 栽培方法
  /// [cropType] 作物種別
  /// [boundaryPolygon] 境界線データ（任意。省略時は仮登録）
  ///   - 形式: [{'lat': 35.0, 'lng': 139.0}, ...]
  Future<Farm> createFarm({
    required String farmName,
    String? cultivationMethod,
    String? cropType,
    List<Map<String, double>>? boundaryPolygon,
  }) async {
    try {
      // Laravel側のモデルに合わせたリクエストデータ
      final requestData = <String, dynamic>{'farm_name': farmName};

      if (boundaryPolygon != null && boundaryPolygon.isNotEmpty) {
        requestData['boundary_polygon'] = boundaryPolygon;
      }

      // オプショナルなフィールドを追加
      if (cultivationMethod != null && cultivationMethod.isNotEmpty) {
        requestData['cultivation_method'] = cultivationMethod;
      }

      if (cropType != null && cropType.isNotEmpty) {
        requestData['crop_type'] = cropType;
      }

      print('=== 圃場登録リクエストデータ ===');
      print('Request data: $requestData');

      // boundary_polygonの形式を確認
      if (boundaryPolygon != null) {
        print('boundary_polygon type: ${boundaryPolygon.runtimeType}');
        print('boundary_polygon length: ${boundaryPolygon.length}');
        if (boundaryPolygon.isNotEmpty) {
          print('boundary_polygon first item: ${boundaryPolygon.first}');
        }
      }

      // JSON文字列として送信（Dioが自動的にJSONエンコードするが、明示的に指定）
      final response = await apiClient.dio.post(
        '/api/v1/farms',
        data: requestData,
        options: Options(contentType: Headers.jsonContentType),
      );
      print('=== 圃場登録レスポンス ===');
      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');
      print('Response data type: ${response.data.runtimeType}');

      // レスポンスが {data: {...}} の形式の場合
      final responseData = response.data;
      final farmData = responseData is Map && responseData.containsKey('data')
          ? responseData['data']
          : responseData;

      print('Farm data: $farmData');
      return Farm.fromJson(farmData as Map<String, dynamic>);
    } catch (e) {
      print('Error creating farm: $e');
      if (e is DioException && e.response != null) {
        print('Response status: ${e.response?.statusCode}');
        print('Response data: ${e.response?.data}');
        print('Response headers: ${e.response?.headers}');
      }
      rethrow;
    }
  }

  /// 圃場を更新
  ///
  /// [farmId] 更新する圃場のID
  /// [farmName] 圃場名（必須、最大50文字）
  /// [cultivationMethod] 栽培方法
  /// [cropType] 作物種別
  /// [boundaryPolygon] 境界線データ（任意。仮登録更新時は空配列可）
  ///   - 形式: [{'lat': 35.0, 'lng': 139.0}, ...]
  Future<Farm> updateFarm({
    required int farmId,
    required String farmName,
    String? cultivationMethod,
    String? cropType,
    List<Map<String, double>>? boundaryPolygon,
  }) async {
    try {
      // Laravel側のモデルに合わせたリクエストデータ
      final requestData = <String, dynamic>{'farm_name': farmName};

      if (boundaryPolygon != null) {
        requestData['boundary_polygon'] = boundaryPolygon;
      }

      // オプショナルなフィールドを追加
      if (cultivationMethod != null && cultivationMethod.isNotEmpty) {
        requestData['cultivation_method'] = cultivationMethod;
      }

      if (cropType != null && cropType.isNotEmpty) {
        requestData['crop_type'] = cropType;
      }

      print('=== 圃場更新リクエストデータ ===');
      print('Farm ID: $farmId');
      print('Request data: $requestData');

      // boundary_polygonの形式を確認
      if (boundaryPolygon != null) {
        print('boundary_polygon type: ${boundaryPolygon.runtimeType}');
        print('boundary_polygon length: ${boundaryPolygon.length}');
        if (boundaryPolygon.isNotEmpty) {
          print('boundary_polygon first item: ${boundaryPolygon.first}');
        }
      }

      // JSON文字列として送信（Dioが自動的にJSONエンコードするが、明示的に指定）
      final response = await apiClient.dio.put(
        '/api/v1/farms/$farmId',
        data: requestData,
        options: Options(contentType: Headers.jsonContentType),
      );

      print('=== 圃場更新レスポンス ===');
      print('Response status: ${response.statusCode}');
      print('Response data: ${response.data}');
      print('Response data type: ${response.data.runtimeType}');

      // レスポンスが {data: {...}} の形式の場合
      final responseData = response.data;
      final farmData = responseData is Map && responseData.containsKey('data')
          ? responseData['data']
          : responseData;

      print('Farm data: $farmData');
      return Farm.fromJson(farmData as Map<String, dynamic>);
    } catch (e) {
      print('Error updating farm: $e');
      if (e is DioException && e.response != null) {
        print('Response status: ${e.response?.statusCode}');
        print('Response data: ${e.response?.data}');
        print('Response headers: ${e.response?.headers}');
      }
      rethrow;
    }
  }

  /// 圃場を削除
  Future<void> delete(int farmId) async {
    await apiClient.dio.delete('/api/v1/farms/$farmId');
  }

  /// ログインユーザー情報を取得（疎通確認用）
  Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await apiClient.dio.get('/api/v1/me');
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      print('Error fetching user info: $e');
      rethrow;
    }
  }
}
