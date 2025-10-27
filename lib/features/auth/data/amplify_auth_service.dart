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
      userAttributes: userAttributes,
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
  //Bearerトークン(API Gatewayに使用)
  Future<String?> accessToken() async {
    final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
    return session.tokens.accessToken;
  }
  //ユーザのsub(uuid)を取得
  Future<String?> userSub() async {
    final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
    return session.userSubResult?.value;
  }
}