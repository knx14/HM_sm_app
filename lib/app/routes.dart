import 'package:flutter/material.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/auth/presentation/sign_up_screen.dart';
import '../features/farms/presentation/farm_screen.dart';
import '../features/help/presentation/help_screen.dart';
import '../features/measure/presentation/measurement_session_screen.dart';
import '../features/results/presentation/home_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/sync/presentation/sync_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String signIn = '/signin';
  static const String signUp = '/signup';
  static const String main = '/main';
  static const String measurement = '/measurement';
  static const String farms = '/farms';
  static const String sync = '/sync';
  static const String settings = '/settings';
  static const String help = '/help';

  // Widgetを返すメソッドを追加
  static Widget signInScreen() => const SignInScreen();
  static Widget signUpScreen() => const SignUpScreen();
}

final Map<String, WidgetBuilder> appRoutes = {
  AppRoutes.splash: (context) => const SplashScreen(),
  AppRoutes.signIn: (context) => const SignInScreen(),
  AppRoutes.signUp: (context) => const SignUpScreen(),
  AppRoutes.main: (context) => const HomeScreen(),
  AppRoutes.measurement: (context) => const MeasurementSessionScreen(),
  AppRoutes.farms: (context) => const FarmScreen(),
  AppRoutes.sync: (context) => const SyncScreen(),
  AppRoutes.settings: (context) => const SettingsScreen(),
  AppRoutes.help: (context) => const HelpScreen(),
};
