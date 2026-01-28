import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../domain/farm_result_date.dart';
import '../domain/latest_results.dart';
import '../domain/result_map.dart';
import '../domain/result_map_diff.dart';

class PreviousNotFoundException implements Exception {
  const PreviousNotFoundException();

  @override
  String toString() => 'PreviousNotFoundException';
}

class ResultsRepository {
  final ApiClient apiClient;
  ResultsRepository(this.apiClient);

  Future<List<LatestResultFeedItem>> fetchLatestResults() async {
    final response = await apiClient.dio.get('/api/results/latest');
    final data = response.data as List<dynamic>;
    return data.map((e) => LatestResultFeedItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<FarmWithLatestResult>> fetchFarmsWithLatestResult() async {
    final response = await apiClient.dio.get('/api/farms/with-latest-result');
    final data = response.data as List<dynamic>;
    return data.map((e) => FarmWithLatestResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<FarmResultDateItem>> fetchFarmResultDates(int farmId) async {
    final response = await apiClient.dio.get('/api/farms/$farmId/results/dates');
    final data = response.data as List<dynamic>;
    return data.map((e) => FarmResultDateItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ResultMapResponse> fetchFarmResultMap({
    required int farmId,
    required String dateIso,
  }) async {
    final response = await apiClient.dio.get(
      '/api/farms/$farmId/results/map',
      queryParameters: {'date': dateIso},
    );
    return ResultMapResponse.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ResultMapDiffResponse> fetchFarmResultMapDiff({
    required int farmId,
    required String dateIso,
  }) async {
    try {
      final response = await apiClient.dio.get(
        '/api/farms/$farmId/results/map-diff',
        queryParameters: {'date': dateIso},
      );
      return ResultMapDiffResponse.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      if (status == 404 && body is Map && body['message'] == 'previous_not_found') {
        throw const PreviousNotFoundException();
      }
      rethrow;
    }
  }
}

