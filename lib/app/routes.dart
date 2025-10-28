import 'package:flutter/material.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/main_scaffold.dart';

class AppRoutes {
  static final String splash = '/';
  static final String signIn = '/signin';
  static final String signUp = '/signup';
  static const String main = '/main';
  
  // Widgetを返すメソッドを追加
  static Widget signInScreen() => const SignInScreen();
  static Widget signUpScreen() => const SignUpScreen();
}

final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.splash: (context) => const SplashScreen(),
  AppRoutes.signIn: (context) => const SignInScreen(),
  AppRoutes.signUp: (context) => const SignUpScreen(),
  AppRoutes.main: (context) => const MainScaffold(),
};