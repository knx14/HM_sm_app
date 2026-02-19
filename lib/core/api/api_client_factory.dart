import '../../features/auth/data/amplify_auth_service.dart';
import 'api_client.dart';

ApiClient buildApiClient() {
  final authService = AmplifyAuthService();
  final baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.hm-admin.com',
  );
  return ApiClient(baseUrl: baseUrl, authService: authService);
}

