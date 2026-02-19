import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'routes.dart';

class HmApp extends StatelessWidget {
  const HmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Henry Monitor App',
      locale: const Locale('ja', 'JP'),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        // 日本語フォントを優先（システムのデフォルト日本語フォントを使用）
        // カスタムフォントを使用する場合は、pubspec.yamlでフォントを登録し、
        // ここでfontFamilyを指定してください（例: fontFamily: 'Meiryo'）
      ),
      initialRoute: AppRoutes.splash,
      routes: appRoutes,
    );
  }
}