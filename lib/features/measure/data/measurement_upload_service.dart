import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

enum UploadPhase {
  idle,
  saving,
  initCalling,
  uploading,
  completing,
  done,
  error,
}

class UploadInitResponse {
  final int uploadId;
  final String csvPutUrl;
  final String s3Key;

  UploadInitResponse({
    required this.uploadId,
    required this.csvPutUrl,
    required this.s3Key,
  });

  factory UploadInitResponse.fromJson(Map<String, dynamic> json) {
    return UploadInitResponse(
      uploadId: (json['upload_id'] as num).toInt(),
      csvPutUrl: json['csv_put_url'] as String,
      s3Key: json['s3_key'] as String,
    );
  }
}

class UploadResult {
  final int uploadId;
  final String s3Key;

  UploadResult({required this.uploadId, required this.s3Key});
}

class MeasurementUploadException implements Exception {
  final UploadPhase phase;
  final String message;
  final int? statusCode;

  MeasurementUploadException({
    required this.phase,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() {
    final sc = statusCode != null ? ' (status=$statusCode)' : '';
    return 'MeasurementUploadException[$phase]$sc: $message';
  }
}

class MeasurementUploadService {
  final Dio _apiDio;
  final Dio _putDio;

  MeasurementUploadService({
    Dio? apiDio,
    Dio? putDio,
  })  : _apiDio = apiDio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.measurementUploadApiBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
                contentType: Headers.jsonContentType,
                responseType: ResponseType.json,
                validateStatus: (status) => status != null && status >= 200 && status < 300,
              ),
            ),
        _putDio = putDio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 60),
                followRedirects: false,
                validateStatus: (status) => status != null, // 後で200/204判定する
                responseType: ResponseType.plain,
              ),
            );

  Future<UploadInitResponse> initUpload({
    required int farmId,
    required Map<String, dynamic> measurementParameters,
    String? measurementDate,
    String? note1,
    String? note2,
    String? cultivationType,
  }) async {
    final body = <String, dynamic>{
      'farm_id': farmId,
      'measurement_date': measurementDate,
      'note1': note1,
      'note2': note2,
      'cultivation_type': cultivationType,
      'measurement_parameters': measurementParameters,
    };

    final resp = await _apiDio.post(
      AppConstants.measurementUploadInitPath,
      data: body,
    );

    final data = resp.data;
    final Map<String, dynamic> json =
        data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);
    return UploadInitResponse.fromJson(json);
  }

  Future<void> putCsvToPresignedUrl({
    required String presignedUrl,
    required File csvFile,
  }) async {
    final bytes = await csvFile.readAsBytes();
    final resp = await _putDio.put(
      presignedUrl,
      // NOTE: presigned PUT to S3 can fail with 501 NotImplemented when the client uses
      // Transfer-Encoding: chunked. Send bytes directly so Content-Length can be set.
      data: bytes,
      options: Options(
        headers: {
          'Content-Type': 'text/csv',
          // Avoid chunked transfer; S3 presigned PUT typically expects a fixed length.
          'Content-Length': bytes.length.toString(),
        },
      ),
    );

    final status = resp.statusCode;
    if (status != 200 && status != 204) {
      final body = resp.data;
      final bodyStr = body == null
          ? ''
          : body is String
              ? body
              : jsonEncode(body);
      throw DioException(
        requestOptions: resp.requestOptions,
        response: resp,
        type: DioExceptionType.badResponse,
        error: [
          'Unexpected PUT status: $status',
          if (bodyStr.trim().isNotEmpty) 'body=$bodyStr',
        ].join(' | '),
      );
    }
  }

  Future<void> completeUpload({
    required int uploadId,
    required String s3Key,
  }) async {
    await _apiDio.post(
      AppConstants.measurementUploadCompletePath(uploadId),
      data: {'s3_key': s3Key},
    );
  }

  Future<UploadResult> uploadCsvWithInitComplete({
    required int farmId,
    required File csvFile,
    required Map<String, dynamic> measurementParameters,
    String? measurementDate,
    String? note1,
    String? note2,
    String? cultivationType,
    void Function(UploadPhase phase)? onPhase,
    void Function(String message)? onLog,
  }) async {
    void phase(UploadPhase p) => onPhase?.call(p);
    void log(String m) => onLog?.call(m);

    try {
      phase(UploadPhase.initCalling);
      log('init: POST ${AppConstants.measurementUploadInitPath}');
      final initResp = await initUpload(
        farmId: farmId,
        measurementParameters: measurementParameters,
        measurementDate: measurementDate,
        note1: note1,
        note2: note2,
        cultivationType: cultivationType,
      );
      log('init: ok upload_id=${initResp.uploadId}');

      phase(UploadPhase.uploading);
      log('put: uploading csv (Content-Type: text/csv)');
      await putCsvToPresignedUrl(
        presignedUrl: initResp.csvPutUrl,
        csvFile: csvFile,
      );
      log('put: ok');

      phase(UploadPhase.completing);
      log('complete: POST ${AppConstants.measurementUploadCompletePath(initResp.uploadId)}');
      await completeUpload(
        uploadId: initResp.uploadId,
        s3Key: initResp.s3Key,
      );
      log('complete: ok');

      phase(UploadPhase.done);
      return UploadResult(uploadId: initResp.uploadId, s3Key: initResp.s3Key);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final bodyStr = body == null
          ? ''
          : body is String
              ? body
              : jsonEncode(body);
      final isDuplicateFilePath = (status == 500) &&
          bodyStr.contains('Duplicate entry') &&
          bodyStr.contains('uploads_file_path_unique');
      final msg = [
        if (isDuplicateFilePath)
          'サーバ側で前回のアップロード行（同一file_path）が残っている可能性があります。uploadsの重複を解消するか、initを冪等にする必要があります',
        e.message,
        if (status != null) 'status=$status',
        if (bodyStr.isNotEmpty) 'body=$bodyStr',
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' | ');
      phase(UploadPhase.error);
      throw MeasurementUploadException(
        phase: _guessPhaseFromRequest(e),
        message: msg.isEmpty ? e.toString() : msg,
        statusCode: status,
      );
    } catch (e) {
      phase(UploadPhase.error);
      throw MeasurementUploadException(
        phase: UploadPhase.error,
        message: e.toString(),
      );
    }
  }

  UploadPhase _guessPhaseFromRequest(DioException e) {
    final path = e.requestOptions.path;
    if (path.contains(AppConstants.measurementUploadInitPath)) {
      return UploadPhase.initCalling;
    }
    if (path.contains('/uploads/') && path.endsWith('/complete')) {
      return UploadPhase.completing;
    }
    // PUTはフルURLのため path が長い/不定だが、methodで概ね判定
    if (e.requestOptions.method.toUpperCase() == 'PUT') {
      return UploadPhase.uploading;
    }
    return UploadPhase.error;
  }
}

