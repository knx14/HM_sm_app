import 'package:flutter/material.dart';
import 'routes.dart';

class HmApp extends StatelessWidget {
  const HmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Henry Monitor App',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
      ),
      initialRoute: AppRoutes.splash,
      routes: appRoutes,
    );
  }
}