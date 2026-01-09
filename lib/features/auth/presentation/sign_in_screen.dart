import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/data/amplify_auth_service.dart';
import '../../auth/domain/auth_repository.dart';
import '../../../providers/user_provider.dart';
import '../../../app/routes.dart';
import 'reset_password_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repo = AuthRepository(AmplifyAuthService());
  bool _loading = false;
  Future<void> _signIn() async {
    setState(() {
      _loading = true;
    });
    try {
      await _repo.signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      
      // ログイン成功直後: subをProviderにセット
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final authService = AmplifyAuthService();
      final userId = await authService.userSub();
      if (userId != null) {
        userProvider.setUserId(userId);
      }
      
      // id_tokenも取得して確認（デバッグ用）
      final token = await authService.idToken();
      print('id_token取得: ${token != null ? "成功" : "失敗"}');
      
      // ホーム画面に遷移
      Navigator.pushReplacementNamed(context, AppRoutes.main);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('エラー: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9), // welcomeウィジェットと同じ色調
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F8E9),
        elevation: 0,
        centerTitle: true,
        title: Image.asset(
          'assets/images/logo.png',
          width: 50,
          height: 50,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ログイン',style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(controller: _email, decoration: InputDecoration(labelText: 'メールアドレス')),
            TextField(controller: _password, decoration: InputDecoration(labelText: 'パスワード')),
            const SizedBox(height: 24),
            Center(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF66BB6A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(130, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: _loading ? null : _signIn,
                child: _loading ? const CircularProgressIndicator() : const Text('ログイン'),
              ),
            ),
            Center(child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
                );
              },
              child: const Text('パスワードを忘れた？'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}