import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_client_factory.dart';
import '../domain/work_log_entry.dart';
import 'work_log_queue.dart';

class WorkLogSaveResult {
  const WorkLogSaveResult({required this.queued, this.serverId});

  final bool queued;
  final int? serverId;
}

class WorkLogRepository {
  WorkLogRepository({ApiClient? apiClient, WorkLogQueue? queue})
    : _apiClient = apiClient ?? buildApiClient(),
      _queue = queue ?? WorkLogQueue();

  final ApiClient _apiClient;
  final WorkLogQueue _queue;

  Future<WorkLogSaveResult> create({
    required int farmId,
    required WorkLogEntry entry,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/api/v1/farms/$farmId/work-logs',
        data: entry.toJson(),
      );
      return WorkLogSaveResult(
        queued: false,
        serverId: _extractServerId(response.data),
      );
    } on DioException catch (e) {
      if (_isOfflineError(e)) {
        await _queue.enqueue(farmId, entry);
        return const WorkLogSaveResult(queued: true);
      }
      rethrow;
    }
  }

  Future<void> update({
    required int workLogId,
    required WorkLogEntry entry,
  }) async {
    await _apiClient.dio.patch(
      '/api/v1/work-logs/$workLogId',
      data: entry.toJson(),
    );
  }

  Future<void> delete(int workLogId) async {
    await _apiClient.dio.delete('/api/v1/work-logs/$workLogId');
  }

  Future<List<Map<String, dynamic>>> listByFarm(int farmId) async {
    final response = await _apiClient.dio.get(
      '/api/v1/farms/$farmId/work-logs',
    );
    final body = response.data;
    final data = body is Map ? body['data'] : body;
    final list = data is List ? data : const <dynamic>[];
    return list
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<WorkLogFlushResult> flushQueue() async {
    final items = await _queue.listItems();
    var success = 0;
    var failed = 0;

    for (final item in items) {
      try {
        await _apiClient.dio.post(
          '/api/v1/farms/${item.farmId}/work-logs',
          data: item.entry.toJson(),
        );
        await _queue.removeByLocalId(item.localId);
        success++;
      } on DioException catch (e) {
        failed++;
        if (_isOfflineError(e)) break;
      } catch (_) {
        failed++;
      }
    }

    return WorkLogFlushResult(success: success, failed: failed);
  }

  Future<int> pendingCount() => _queue.count();

  int? _extractServerId(dynamic data) {
    if (data is Map) {
      final directId = data['id'];
      if (directId is num) return directId.toInt();
      final nested = data['data'];
      if (nested is Map && nested['id'] is num) {
        return (nested['id'] as num).toInt();
      }
    }
    return null;
  }

  bool _isOfflineError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.unknown;
  }
}

class WorkLogFlushResult {
  const WorkLogFlushResult({required this.success, required this.failed});

  final int success;
  final int failed;
}
