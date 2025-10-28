import '../data/amplify_auth_service.dart';

class AuthRepository {
  AuthRepository(this._service);
  final AmplifyAuthService _service;

  Future<bool> isSignedIn() => _service.isSignedIn();

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String jaName,
  }) =>
      _service.singnUp(
        email: email,
        password: password,
        name: name,
        jaName: jaName,
      );

  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) =>
      _service.confirmSignUp(email: email, code: code);

  Future<void> signIn({
    required String email,
    required String password,
  }) =>
      _service.signIn(email: email, password: password);

  Future<void> signOut() => _service.signOut();

  Future<String?> bearerToken() async {
    final token = await _service.accessToken();
    return token == null ? null : 'Bearer $token';
  }
  Future<void> sendResetCode({required String email}) => _service.sendResetCode(email: email);
  Future<void> confirmResetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) => _service.confirmResetPassword(email: email, code: code, newPassword: newPassword);
}
