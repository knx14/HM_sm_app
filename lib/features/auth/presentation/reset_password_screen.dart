import 'package:flutter/material.dart';
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

  Future<void> _sendCode() async {
    setState(() => _loading = true);
    try {
      await _repo.sendResetCode(email: _email.text.trim());
      setState(() => _codeSent = true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmReset() async {
    setState(() => _loading = true);
    try {
      await _repo.confirmResetPassword(
        email: _email.text.trim(),
        code: _code.text.trim(),
        newPassword: _newPassword.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスワードをリセットしました。')),
      );
      Navigator.pop(context); // SignIn画面に戻る
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(title: const Text('パスワードをリセット')),
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
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
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
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _confirmReset,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('パスワードを更新'),
          ),
        ],
      );
}