import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import '../../auth/data/amplify_auth_service.dart';
import '../../auth/domain/auth_repository.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _repo = AuthRepository(AmplifyAuthService());

  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  String _parseError(dynamic error) {
    final errorString = error.toString();
    
    // Lambda設定エラーの場合
    if (errorString.contains('UnexpectedLambdaException') ||
        errorString.contains('PostConfirmation')) {
      return 'サーバー設定エラーが発生しました。管理者にお問い合わせください。';
    }
    
    // コード関連のエラー
    if (errorString.contains('CodeMismatchException') ||
        errorString.contains('InvalidParameterException')) {
      if (errorString.contains('code') || errorString.contains('Code')) {
        return '確認コードが正しくありません。もう一度確認してください。';
      }
    }
    
    // パスワード関連のエラー
    if (errorString.contains('InvalidPasswordException') ||
        errorString.contains('InvalidParameterException')) {
      if (errorString.contains('password') || errorString.contains('Password')) {
        return 'パスワードは8文字以上で、数字・特殊文字（^ \$ * . [ ] { } ( ) ? - " ! @ # % & / \\ , > < \' : ; | _ ~ ` + =）・大文字・小文字をそれぞれ1つ以上含む必要があります。';
      }
    }
    
    // ユーザーが見つからない場合
    if (errorString.contains('UserNotFoundException') ||
        errorString.contains('User does not exist')) {
      return 'このメールアドレスは登録されていません。';
    }
    
    // コードの有効期限切れ
    if (errorString.contains('ExpiredCodeException')) {
      return '確認コードの有効期限が切れています。新しいコードを取得してください。';
    }
    
    // その他のエラー
    return 'エラーが発生しました。もう一度お試しください。';
  }

  Future<void> _sendCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _repo.sendResetCode(email: _email.text.trim());
      if (!mounted) return;
      setState(() => _codeSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('リセットコードを送信しました。メールをご確認ください。')),
      );
    } catch (e) {
      setState(() => _error = _parseError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _confirmReset() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 詳細なエラーログを出力
      print('=== パスワードリセット開始 ===');
      print('Email: ${_email.text.trim()}');
      print('Code length: ${_code.text.trim().length}');
      print('Password length: ${_newPassword.text.length}');
      
      await _repo.confirmResetPassword(
        email: _email.text.trim(),
        code: _code.text.trim(),
        newPassword: _newPassword.text,
      );
      
      print('=== パスワードリセット成功 ===');
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスワードをリセットしました。')),
      );
      Navigator.pop(context); // SignIn画面に戻る
    } catch (e, stackTrace) {
      // 詳細なエラー情報をログに出力
      print('=== パスワードリセットエラー ===');
      print('Error type: ${e.runtimeType}');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      
      // Amplifyのエラータイプを確認
      if (e is AuthException) {
        print('AuthException details:');
        print('  - Message: ${e.message}');
        print('  - Recovery suggestion: ${e.recoverySuggestion}');
        print('  - Underlying exception: ${e.underlyingException}');
      }
      
      setState(() => _error = _parseError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F8E9),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: const Text(
                    'パスワードをリセット',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // 右側のバランス調整
              ],
            ),
            Container(
              width: double.infinity,
              height: 2,
              color: Colors.grey,
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _codeSent ? _buildConfirmForm() : _buildEmailForm(),
      ),
    );
  }

  Widget _buildEmailForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('登録済みのメールアドレスを入力してください'),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'メールアドレス'),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Center(child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF66BB6A),
              foregroundColor: Colors.white,
              minimumSize: const Size(130, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: _loading ? null : _sendCode,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('リセットコードを送信'),
          ),)
        ],
      );

  Widget _buildConfirmForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('受信したコードと新しいパスワードを入力してください'),
          const SizedBox(height: 12),
          TextField(controller: _code, decoration: const InputDecoration(labelText: '確認コード')),
          TextField(controller: _newPassword, decoration: const InputDecoration(labelText: '新しいパスワード'), obscureText: true),
          const SizedBox(height: 16),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF66BB6A),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: _loading ? null : _confirmReset,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('パスワードを更新'),
          ),
        ],
      );
}