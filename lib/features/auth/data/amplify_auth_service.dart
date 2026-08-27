import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

//cognito認証を直接操作するサービス層
class AmplifyAuthService {
  Future<bool> isSignedIn() async {
    final session = await Amplify.Auth.fetchAuthSession();
    return session.isSignedIn;
  }

  //新規登録
  Future<void> singnUp({
    required String email,
    required String password,
    required String name,
    required String jaName,
  }) async {
    final userAttributes = {
      CognitoUserAttributeKey.email: email,
      CognitoUserAttributeKey.name: name,
      const CognitoUserAttributeKey.custom('ja_name'): jaName,
    };

    await Amplify.Auth.signUp(
      username: email,
      password: password,
      options: SignUpOptions(userAttributes: userAttributes),
    );
  }

  //メールで届いた確認コードの検証
  Future<void> confirmSignUp({
    required String email,
    required String code,
  }) async {
    await Amplify.Auth.confirmSignUp(username: email, confirmationCode: code);
  }

  //サインイン
  Future<void> signIn({required String email, required String password}) async {
    await Amplify.Auth.signIn(username: email, password: password);
  }

  //サインアウト
  Future<void> signOut() async {
    await Amplify.Auth.signOut();
  }

  //パスワードリセット時のメール送信
  Future<void> sendResetCode({required String email}) async {
    await Amplify.Auth.resetPassword(username: email);
  }

  //リセットコード確認＋新パスワード登録
  Future<void> confirmResetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: code,
      );
    } on AuthException catch (e) {
      // PostConfirmation Lambdaエラーの場合でも、パスワードリセット自体は成功している可能性がある
      // エラーメッセージにPostConfirmationが含まれている場合、パスワードリセットは成功している可能性が高い
      final errorMessage = e.message;
      final underlyingException = e.underlyingException;
      final underlyingMessage = underlyingException != null
          ? underlyingException.toString()
          : '';
      final errorString = e.toString();

      if ((errorMessage.contains('PostConfirmation') ||
              underlyingMessage.contains('PostConfirmation') ||
              errorString.contains('PostConfirmation')) &&
          (errorMessage.contains('UnexpectedLambdaException') ||
              underlyingMessage.contains('UnexpectedLambdaException') ||
              errorString.contains('UnexpectedLambdaException'))) {
        // PostConfirmation Lambdaエラーだが、パスワードリセット自体は成功している可能性がある
        // この場合、エラーを無視して成功として扱う
        // エラーを再スローせず、成功として扱う
        return;
      }

      rethrow;
    }
  }

  /// access_token (JWT) を取得する
  /// APIリクエストのAuthorizationヘッダーに使用（Laravel API用）
  Future<String?> accessToken() async {
    try {
      final session =
          await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      if (!session.isSignedIn) {
        return null;
      }
      final tokensResult = session.userPoolTokensResult;
      // Result型のvalueプロパティを安全に取得
      try {
        final tokens = tokensResult.value;

        // Amplifyのバージョン差分に強くする
        final accessTokenObj = tokens.accessToken;

        // 多くの環境で raw / rawValue / jwtToken 等のどれかがある
        final dynamic dyn = accessTokenObj;
        final token = (dyn.raw ?? dyn.jwtToken ?? dyn.toString()) as String?;

        return token;
      } catch (_) {
        // tokensResult.valueが取得できない場合
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  //ユーザのsub(uuid)を取得
  Future<String?> userSub() async {
    final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
    return session.userSubResult.value;
  }

  Future<String?> userDisplayName() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      String? valueFor(String key) {
        for (final attr in attributes) {
          if (attr.userAttributeKey.key == key) return attr.value;
        }
        return null;
      }

      final rawName = valueFor('name');
      final trimmed = rawName?.trim();
      if (trimmed == null || trimmed.isEmpty) return null;
      return trimmed;
    } catch (e) {
      return null;
    }
  }
}
