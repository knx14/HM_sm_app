import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/data/amplify_auth_service.dart';
import '../../auth/domain/auth_repository.dart';
import '../../../app/routes.dart';
import '../../../providers/user_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> 
 with SingleTickerProviderStateMixin{
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final _repo = AuthRepository(AmplifyAuthService());
  final _authService = AmplifyAuthService();
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(seconds: 1));
    
    try {
      final isSignedIn = await _repo.isSignedIn();
      if (isSignedIn) {
        // ログイン済みの場合、ユーザIDを取得してProviderに設定
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        
        try {
          final userId = await _authService.userSub();
          if (userId != null) {
            userProvider.setUserId(userId);
            Navigator.pushReplacementNamed(context, AppRoutes.main);
          } else {
            userProvider.setError('ユーザIDの取得に失敗しました');
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const _WelcomeView()),
            );
          }
        } catch (e) {
          userProvider.setError('ユーザIDの取得中にエラーが発生しました: $e');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const _WelcomeView()),
          );
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const _WelcomeView()),
        );
      }
    } catch (e) {
      // 認証状態の確認でエラーが発生した場合
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const _WelcomeView()),
      );
    }
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E7D32), // 深緑（自然感）
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.eco, size: 90, color: Colors.white),
              SizedBox(height: 24),
              Text(
                'HenryMonitor',
                style: TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '磁気センサーで、土壌を科学する。',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------
// 🌱 Welcome的UIをSplashの後ろに統合
// --------------------------------------------------------
class _WelcomeView extends StatelessWidget {
  const _WelcomeView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9), // 柔らかい緑背景
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.png', width:60, height: 60),
              const SizedBox(height: 16),
              const Text(
                'ようこそ HenryMonitor へ',
                style: TextStyle(
                  fontSize: 22,
                  color: Color(0xFF1B5E20),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'データで農業を、もっと科学的に。',
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 60),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF66BB6A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(260, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AppRoutes.signUpScreen()),
                ),
                child: const Text('新規登録'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                  minimumSize: const Size(260, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AppRoutes.signInScreen()),
                ),
                child: const Text('ログイン'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}