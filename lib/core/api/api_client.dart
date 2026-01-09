import 'dart:convert';
import 'package:dio/dio.dart';
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
        // access_tokenを取得（Laravel APIは通常access_tokenを使用）
        final token = await authService.accessToken();
        print('=== APIリクエスト ===');
        print('URL: ${options.uri}');
        print('Method: ${options.method}');
        if (token != null) {
          final authHeader = 'Bearer $token';
          options.headers['Authorization'] = authHeader;
          print('認証トークン (access_token): あり (${token.substring(0, token.length > 20 ? 20 : token.length)}...)');
          print('トークン全体の長さ: ${token.length}');
          print('Authorizationヘッダー: ${authHeader.substring(0, authHeader.length > 50 ? 50 : authHeader.length)}...');
          
          // JWTトークンをデコードして内容を確認
          try {
            final parts = token.split('.');
            if (parts.length == 3) {
              // Base64デコード（パディングを追加）
              String payloadBase64 = parts[1];
              // Base64URLデコード用にパディングを追加
              switch (payloadBase64.length % 4) {
                case 1:
                  payloadBase64 += '===';
                  break;
                case 2:
                  payloadBase64 += '==';
                  break;
                case 3:
                  payloadBase64 += '=';
                  break;
              }
              // Base64URLの文字をBase64に変換
              payloadBase64 = payloadBase64.replaceAll('-', '+').replaceAll('_', '/');
              
              // Base64デコード
              final payloadBytes = base64Decode(payloadBase64);
              final payloadString = utf8.decode(payloadBytes);
              final payloadJson = jsonDecode(payloadString) as Map<String, dynamic>;
              print('JWT Payload (access_token): $payloadString');
              print('Token Use: ${payloadJson['token_use']}');
              print('Issuer (iss): ${payloadJson['iss']}');
              print('Client ID: ${payloadJson['client_id']}');
              print('Expiration (exp): ${payloadJson['exp']}');
              print('Issued At (iat): ${payloadJson['iat']}');
              
              // 有効期限を確認
              final exp = payloadJson['exp'] as int;
              final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
              print('現在時刻 (Unix timestamp): $now');
              print('有効期限まで: ${exp - now}秒');
              if (now > exp) {
                print('警告: トークンが期限切れです！');
              } else {
                print('トークンは有効期限内です');
              }
            }
          } catch (e) {
            print('JWTデコードエラー: $e');
          }
        } else {
          print('認証トークン: なし');
        }
        options.headers['Content-Type'] = 'application/json';
        options.headers['Accept'] = 'application/json';
        print('リクエストヘッダー: ${options.headers}');
        if (options.data != null) {
          print('リクエストボディ: ${options.data}');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        print('=== APIレスポンス ===');
        print('URL: ${response.requestOptions.uri}');
        print('ステータスコード: ${response.statusCode}');
        handler.next(response);
      },
      onError: (error, handler) {
        print('=== APIエラー ===');
        print('URL: ${error.requestOptions.uri}');
        print('Method: ${error.requestOptions.method}');
        print('リクエストボディ: ${error.requestOptions.data}');
        if (error.response != null) {
          print('ステータスコード: ${error.response?.statusCode}');
          print('レスポンスヘッダー: ${error.response?.headers}');
          print('レスポンスデータ: ${error.response?.data}');
          
          // 302リダイレクトエラーの場合
          if (error.response?.statusCode == 302) {
            final location = error.response?.headers.value('location');
            print('リダイレクト先: $location');
            print('警告: 302リダイレクトが発生しました。');
            print('考えられる原因:');
            print('1. ルーティングの不一致（末尾スラッシュの問題など）');
            print('2. バリデーションエラーによるリダイレクト');
            print('3. 認証ミドルウェアの問題');
            print('4. リクエストデータの形式の問題');
          }
        } else {
          print('エラータイプ: ${error.type}');
          print('エラーメッセージ: ${error.message}');
        }
        // 401エラーの場合は再ログインを促すなど
        if (error.response?.statusCode == 401) {
          // ログアウト処理やエラーハンドリング
          print('認証エラー: トークンが無効です');
        }
        handler.next(error);
      },
    ));
  }
}

