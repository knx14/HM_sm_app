import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_factory.dart';

class ManualResultBoundaryRequiredException implements Exception {
  const ManualResultBoundaryRequiredException();
}

class ManualResultDateAlreadyExistsException implements Exception {
  const ManualResultDateAlreadyExistsException();
}

class ManualResultRepository {
  ManualResultRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? buildApiClient();

  final ApiClient _apiClient;

  Future<void> create({
    required int farmId,
    required String measurementDate,
    required Map<String, double> values,
  }) async {
    try {
      await _apiClient.dio.post(
        '/api/manual-results',
        data: {
          'farm_id': farmId,
          'measurement_date': measurementDate,
          'values': values,
        },
      );
    } on DioException catch (e) {
      throw _mapException(e);
    }
  }

  Exception _mapException(DioException e) {
    final data = e.response?.data;
    final errorCode = _extractErrorCode(data);
    if (errorCode == 'farm_boundary_required') {
      return const ManualResultBoundaryRequiredException();
    }
    if (errorCode == 'measurement_date_already_exists') {
      return const ManualResultDateAlreadyExistsException();
    }
    return e;
  }

  String? _extractErrorCode(dynamic data) {
    if (data is! Map) return null;
    final direct = data['error'] ?? data['code'];
    if (direct is String) return direct;
    final message = data['message'];
    if (message == 'farm_boundary_required' ||
        message == 'measurement_date_already_exists') {
      return message as String;
    }
    return null;
  }
}
