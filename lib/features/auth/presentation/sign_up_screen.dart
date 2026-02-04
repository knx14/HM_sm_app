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

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _jaName.dispose();
    _code.dispose();
    super.dispose();
  }

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
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('invalidpasswordexception')) {
        setState(() => _error = 'パスワードは8文字以上で、数字・特殊文字・大文字・小文字をそれぞれ1つ以上含む必要があります。');
      } else if (errorMessage.contains('invalidparameterexception')) {
        if (errorMessage.contains('ja_name')) {
          setState(() => _error = '所属している農業共同組合名の入力に問題があります。正しい名前を入力してください。');
        } else {
          setState(() => _error = '入力された情報に問題があります。すべての項目を正しく入力してください。');
        }
      } else {
        setState(() => _error = e.toString());
      }
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
    final content = _awaitingCode
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '確認コードが ${_email.text}\nへ送信されました。',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                decoration: const InputDecoration(labelText: '認証コード'),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
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
                  onPressed: _loading ? null : _confirm,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('認証'),
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '新規登録',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'メールアドレス'),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'パスワード'),
              ),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'フルネーム'),
              ),
              TextField(
                controller: _jaName,
                decoration: const InputDecoration(labelText: '所属している農業共同組合名'),
              ),
              const SizedBox(height: 24),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
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
                  onPressed: _loading ? null : _signUp,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('新規登録'),
                ),
              ),
            ],
          );

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF1F8E9),
        elevation: 0,
        centerTitle: true,
        title: Image.asset(alignment: Alignment.centerLeft, 'assets/images/logo.png', width: 50, height: 50),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomInset = MediaQuery.of(context).viewInsets.bottom;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(child: content),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}