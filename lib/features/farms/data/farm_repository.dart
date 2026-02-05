import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../domain/farm.dart';

class FarmRepository {
  final ApiClient apiClient;

  FarmRepository(this.apiClient);

  /// 自分の圃場一覧を取得
  Future<List<Farm>> getFarms() async {
    try {
      final response = await apiClient.dio.get('/api/v1/farms');
      print('=== 圃場一覧取得レスポンス ===');
      print('Response status: ${response.statusCode}');
      print('Response data type: ${response.data.runtimeType}');
      final List<dynamic> data = response.data['data'] ?? response.data;
      return data.map((json) => Farm.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching farms: $e');
      rethrow;
    }
  }

  /// 圃場を登録
  /// 
  /// [farmName] 圃場名（必須、最大50文字）
  /// [cultivationMethod] 栽培方法
  /// [cropType] 作物種別
  /// [boundaryPolygon] 境界線データ（必須、最低3点）
  ///   - 形式: [{'lat': 35.0, 'lng': 139.0}, ...]
  Future<Farm> createFarm({
    required String farmName,
    String? cultivationMethod,
    String? cropType,
    required List<Map<String, double>> boundaryPolygon,
  }) async {
    try {
      // Laravel側のモデルに合わせたリクエストデータ
      final requestData = <String, dynamic>{
        'farm_name': farmName,
        'boundary_polygon': boundaryPolygon,
      };
      
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
      print('boundary_polygon type: ${boundaryPolygon.runtimeType}');
      print('boundary_polygon length: ${boundaryPolygon.length}');
      if (boundaryPolygon.isNotEmpty) {
        print('boundary_polygon first item: ${boundaryPolygon.first}');
      }
      
      // JSONエンコーディングを明示的に行い、正しい形式で送信する
      final jsonString = jsonEncode(requestData);
      print('Request data (JSON string): $jsonString');
      
      // JSON文字列をデコードして確認
      final decoded = jsonDecode(jsonString);
      print('Request data (decoded): $decoded');
      print('boundary_polygon in decoded (type): ${decoded['boundary_polygon'].runtimeType}');
      print('boundary_polygon in decoded (is List): ${decoded['boundary_polygon'] is List}');
      
      // JSON文字列として送信（Dioが自動的にJSONエンコードするが、明示的に指定）
      final response = await apiClient.dio.post(
        '/api/v1/farms',
        data: requestData,
        options: Options(
          contentType: Headers.jsonContentType,
        ),
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
  /// [boundaryPolygon] 境界線データ（必須、最低3点）
  ///   - 形式: [{'lat': 35.0, 'lng': 139.0}, ...]
  Future<Farm> updateFarm({
    required int farmId,
    required String farmName,
    String? cultivationMethod,
    String? cropType,
    required List<Map<String, double>> boundaryPolygon,
  }) async {
    try {
      // Laravel側のモデルに合わせたリクエストデータ
      final requestData = <String, dynamic>{
        'farm_name': farmName,
        'boundary_polygon': boundaryPolygon,
      };
      
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
      print('boundary_polygon type: ${boundaryPolygon.runtimeType}');
      print('boundary_polygon length: ${boundaryPolygon.length}');
      if (boundaryPolygon.isNotEmpty) {
        print('boundary_polygon first item: ${boundaryPolygon.first}');
      }
      
      // JSONエンコーディングを明示的に行い、正しい形式で送信する
      final jsonString = jsonEncode(requestData);
      print('Request data (JSON string): $jsonString');
      
      // JSON文字列をデコードして確認
      final decoded = jsonDecode(jsonString);
      print('Request data (decoded): $decoded');
      print('boundary_polygon in decoded (type): ${decoded['boundary_polygon'].runtimeType}');
      print('boundary_polygon in decoded (is List): ${decoded['boundary_polygon'] is List}');
      
      // JSON文字列として送信（Dioが自動的にJSONエンコードするが、明示的に指定）
      final response = await apiClient.dio.put(
        '/api/v1/farms/$farmId',
        data: requestData,
        options: Options(
          contentType: Headers.jsonContentType,
        ),
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

