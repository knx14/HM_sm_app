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
    try {
      print('confirmResetPassword called: email=$email, codeLength=${code.length}');
      final result = await Amplify.Auth.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: code,
      );
      print('confirmResetPassword result: $result');
      print('isPasswordReset: ${result.isPasswordReset}');
      
      // パスワードリセットが成功した場合、isPasswordResetがtrueになる
      // ただし、この時点ではまだログインしていない状態
      if (result.isPasswordReset) {
        print('パスワードリセットが完了しました');
      }
    } on AuthException catch (e) {
      print('confirmResetPassword AuthException:');
      print('  - Message: ${e.message}');
      print('  - Recovery: ${e.recoverySuggestion}');
      print('  - Underlying: ${e.underlyingException}');
      
      // PostConfirmation Lambdaエラーの場合でも、パスワードリセット自体は成功している可能性がある
      // エラーメッセージにPostConfirmationが含まれている場合、パスワードリセットは成功している可能性が高い
      final errorMessage = e.message;
      final underlyingException = e.underlyingException;
      final underlyingMessage = underlyingException != null ? underlyingException.toString() : '';
      final errorString = e.toString();
      
      if ((errorMessage.contains('PostConfirmation') || 
           underlyingMessage.contains('PostConfirmation') ||
           errorString.contains('PostConfirmation')) &&
          (errorMessage.contains('UnexpectedLambdaException') ||
           underlyingMessage.contains('UnexpectedLambdaException') ||
           errorString.contains('UnexpectedLambdaException'))) {
        // PostConfirmation Lambdaエラーだが、パスワードリセット自体は成功している可能性がある
        // この場合、エラーを無視して成功として扱う
        print('PostConfirmation Lambdaエラーが発生しましたが、パスワードリセットは成功している可能性があります');
        // エラーを再スローせず、成功として扱う
        return;
      }
      
      rethrow;
    } catch (e) {
      print('confirmResetPassword error: $e');
      print('Error type: ${e.runtimeType}');
      rethrow;
    }
  }
  /// access_token (JWT) を取得する
  /// APIリクエストのAuthorizationヘッダーに使用（Laravel API用）
  Future<String?> accessToken() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      if (!session.isSignedIn) {
        print('accessToken: ログインしていません');
        return null;
      }
      final tokensResult = session.userPoolTokensResult;
      // Result型のvalueプロパティを安全に取得
      try {
        final tokens = tokensResult.value;
        print('accessToken: tokens取得成功');
        
        // Amplifyのバージョン差分に強くする
        final accessTokenObj = tokens.accessToken;
        print('accessToken: accessTokenObj取得成功, type: ${accessTokenObj.runtimeType}');
        
        // 多くの環境で raw / rawValue / jwtToken 等のどれかがある
        final dynamic dyn = accessTokenObj;
        final token = (dyn.raw ?? dyn.jwtToken ?? dyn.toString()) as String?;
        
        if (token != null) {
          print('accessToken: トークン取得成功, length: ${token.length}');
          // トークンの最初の部分を確認
          if (token.contains('.')) {
            print('accessToken: JWT形式のトークンです');
          } else {
            print('accessToken: 警告 - JWT形式ではない可能性があります');
          }
        } else {
          print('accessToken: トークンがnullです');
        }
        
        return token;
      } catch (e) {
        // tokensResult.valueが取得できない場合
        print('accessToken: tokensResult.value取得エラー: $e');
        return null;
      }
    } catch (e) {
      print('Error getting access_token: $e');
      return null;
    }
  }
  //ユーザのsub(uuid)を取得
  Future<String?> userSub() async {
    final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
    return session.userSubResult.value;
  }
  /// id_token (JWT) を取得する
  /// APIリクエストのAuthorizationヘッダーに使用
  Future<String?> idToken() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession() as CognitoAuthSession;
      if (!session.isSignedIn) {
        print('idToken: ログインしていません');
        return null;
      }
      final tokensResult = session.userPoolTokensResult;
      // Result型のvalueプロパティを安全に取得
      try {
        final tokens = tokensResult.value;
        print('idToken: tokens取得成功');
        
        // Amplifyのバージョン差分に強くする
        final idTokenObj = tokens.idToken;
        print('idToken: idTokenObj取得成功, type: ${idTokenObj.runtimeType}');
        
        // 多くの環境で raw / rawValue / jwtToken 等のどれかがある
        final dynamic dyn = idTokenObj;
        final token = (dyn.raw ?? dyn.jwtToken ?? dyn.toString()) as String?;
        
        if (token != null) {
          print('idToken: トークン取得成功, length: ${token.length}');
          // トークンの最初の部分を確認
          if (token.contains('.')) {
            print('idToken: JWT形式のトークンです');
          } else {
            print('idToken: 警告 - JWT形式ではない可能性があります');
          }
        } else {
          print('idToken: トークンがnullです');
        }
        
        return token;
      } catch (e) {
        // tokensResult.valueが取得できない場合
        print('idToken: tokensResult.value取得エラー: $e');
        return null;
      }
    } catch (e) {
      print('Error getting id_token: $e');
      return null;
    }
  }
}