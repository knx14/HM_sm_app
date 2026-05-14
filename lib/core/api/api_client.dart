import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../features/auth/data/amplify_auth_service.dart';

class ApiClient {
  final Dio dio;
  final AmplifyAuthService authService;
  final String baseUrl;

  ApiClient({
    required this.baseUrl,
    required this.authService,
  }) : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          followRedirects: false, // 302リダイレクトを自動追従しない
          validateStatus: (status) {
            // 302をエラーとして扱う
            return status! < 300;
          },
        )) {
    // リクエストインターセプター: Bearerトークンを自動付与
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await authService.accessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        options.headers['Content-Type'] = 'application/json';
        options.headers['Accept'] = 'application/json';
        _debugLog('API request: ${options.method} ${options.uri}');
        handler.next(options);
      },
      onResponse: (response, handler) {
        _debugLog('API response: ${response.statusCode} ${response.requestOptions.uri}');
        handler.next(response);
      },
      onError: (error, handler) {
        _debugLog(
          'API error: ${error.requestOptions.method} ${error.requestOptions.uri} '
          'status=${error.response?.statusCode} type=${error.type}',
        );
        handler.next(error);
      },
    ));
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }
}

