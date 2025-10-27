import 'dart:async';

import 'package:flutter/material.dart';
import '../../auth/data/amplify_auth_service.dart';
import '../../auth/domain/auth_repository.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repo = AuthRepository(AmplifyAuthService());
  bool loading = false;
  String? _error;
  Future<void> _signIn() async {
    setState(() {
      loading = true;
      _error = null;
    });
    try {
      await _repo.signIn(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインしました')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppBar(title: const Test('サインイン')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFiled(controller: _email, decoration: InputDecoration(labelText: 'メールアドレス')),
            TextFiled(controller: _password, decoration: InputDecoration(labelText: 'パスワード')),
            const SizedBox(height: 12),
            FilledButton(
              onPressd: _loading ? null : _signIn,
              child: _loading ? const CircularProgressIndicator() : const Text('サインイン'),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignUpScreen()),
              ),
              child: const Text('新規登録'),
            ),
          ],
        ),
      ),
    );
  }
}