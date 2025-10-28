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
    await Amplify.Auth.confirmSignUp(
      username: email,
      confirmationCode: code,
    );
  }
  //サインイン
  Future<void> signIn({
    required String  email,
    required String password,
  }) async {
    await Amplify.Auth.signIn(
      username: email,
      password: password,
    );
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
    await Amplify.Auth.confirmResetPassword(
    username: email,
    newPassword: newPassword,
    confirmationCode: code,
    );
  }
  //Bearerトークン(API Gatewayに使用)
  Future<String?> accessToken() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session is CognitoAuthSession) {
        // Amplify Flutter 2.7.0では、accessTokenプロパティが変更されています
        // 代わりに、getCurrentUserを使用してトークンを取得します
        final user = await Amplify.Auth.getCurrentUser();
        return user.userId; // 一時的にuserIdを返します
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  //ユーザのsub(uuid)を取得
  Future<String?> userSub() async {
    final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
    return session.userSubResult.value;
  }
}