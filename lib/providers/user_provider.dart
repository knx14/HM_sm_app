import 'package:flutter/foundation.dart';

/// ユーザID（Cognitoのsub）をグローバルに管理するProvider
class UserProvider extends ChangeNotifier {
  String? _userId;
  bool _isLoading = false;
  String? _error;

  /// 現在のユーザID
  String? get userId => _userId;

  /// ローディング状態
  bool get isLoading => _isLoading;

  /// エラーメッセージ
  String? get error => _error;

  /// ユーザIDが設定されているかどうか
  bool get isAuthenticated => _userId != null;

  /// ユーザIDを設定
  void setUserId(String userId) {
    _userId = userId;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// ローディング状態を設定
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// エラーを設定
  void setError(String error) {
    _error = error;
    _isLoading = false;
    notifyListeners();
  }

  /// ユーザIDをクリア（ログアウト時）
  void clearUserId() {
    _userId = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  /// エラーをクリア
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
