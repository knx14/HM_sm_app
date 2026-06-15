import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../domain/farm_result_date.dart';
import '../domain/latest_results.dart';
import '../domain/result_map.dart';
import '../domain/result_map_diff.dart';
import '../domain/timeline_item.dart';
import '../domain/timeseries_result.dart';

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
    return data
        .map((e) => LatestResultFeedItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<FarmWithLatestResult>> fetchFarmsWithLatestResult() async {
    final response = await apiClient.dio.get('/api/farms/with-latest-result');
    final data = response.data as List<dynamic>;
    return data
        .map((e) => FarmWithLatestResult.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<FarmResultDateItem>> fetchFarmResultDates(int farmId) async {
    final response = await apiClient.dio.get(
      '/api/farms/$farmId/results/dates',
    );
    final data = response.data as List<dynamic>;
    return data
        .map((e) => FarmResultDateItem.fromJson(e as Map<String, dynamic>))
        .toList();
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

  Future<void> updateResultPointLocation({
    required int pointId,
    required double lat,
    required double lng,
  }) async {
    await apiClient.dio.patch(
      '/api/v1/results/$pointId/location',
      data: {'latitude': lat, 'longitude': lng},
    );
  }

  Future<void> deleteResultPoint(int pointId) async {
    await apiClient.dio.delete('/api/v1/results/$pointId');
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
      return ResultMapDiffResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      if (status == 404 &&
          body is Map &&
          body['message'] == 'previous_not_found') {
        throw const PreviousNotFoundException();
      }
      rethrow;
    }
  }

  Future<TimeseriesResult> fetchFarmTimeseries({
    required int farmId,
    required String parameter,
  }) async {
    final response = await apiClient.dio.get(
      '/api/farms/$farmId/results/timeseries',
      queryParameters: {'parameter': parameter},
    );
    return TimeseriesResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<TimelineItem>> fetchFarmTimeline(int farmId) async {
    final response = await apiClient.dio.get('/api/farms/$farmId/timeline');
    final body = response.data;
    final data = body is Map
        ? body['items'] as List<dynamic>?
        : body as List<dynamic>?;
    final items = data ?? const <dynamic>[];
    return items
        .map((e) => TimelineItem.fromJson(e as Map<String, dynamic>))
        .where((item) => item is! UnknownTimelineItem)
        .toList(growable: false);
  }
}
