import 'package:flutter/material.dart';
import '../../auth/data/amplify_auth_service.dart';
import '../../auth/domain/auth_repository.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _jaName = TextEditingController();
  final _code = TextEditingController();
  final _repo = AuthRepository(AmplifyAuthService());

  bool _awaitingCode = false;
  bool _loading = false;
  String? _error;

  Future<void> _signUp() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _repo.signUp(
        email: _email.text.trim(),
        password: _password.text,
        name: _name.text.trim(),
        jaName: _jaName.text.trim(),
      );
      setState(() => _awaitingCode = true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _repo.confirmSignUp(email: _email.text.trim(), code: _code.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign up confirmed!')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _awaitingCode
            ? Column(
                children: [
                  Text('A confirmation code was sent to ${_email.text}.'),
                  TextField(controller: _code, decoration: const InputDecoration(labelText: '認証コード')),
                  const SizedBox(height: 12),
                  if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                  FilledButton(onPressed: _loading ? null : _confirm, child: const Text('認証')),
                ],
              )
            : Column(
                children: [
                  TextField(controller: _email, decoration: const InputDecoration(labelText: 'メールアドレス')),
                  TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'パスワード')),
                  TextField(controller: _name, decoration: const InputDecoration(labelText: 'フルネーム')),
                  TextField(controller: _jaName, decoration: const InputDecoration(labelText: '所属している農業共同組合名')),
                  const SizedBox(height: 12),
                  if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
                  FilledButton(onPressed: _loading ? null : _signUp, child: const Text('新規登録')),
                ],
              ),
      ),
    );
  }
}
