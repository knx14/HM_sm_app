import 'package:flutter/material.dart';
import '../features/auth/presentation/splash_screen.dart';

class HmApp extends StatelessWidget {
  const HmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Henry Monitor App',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors. green,
      ),
      home: const SplashScreen(),
    );
  }
}