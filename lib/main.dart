import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'amplifyconfiguration.dart';
import 'app/app.dart';
import 'providers/user_provider.dart';

Future<void> _configureAmplify() async {
  try {
    if (!Amplify.isConfigured) {
      await Amplify.addPlugins([AmplifyAuthCognito()]);
      await Amplify.configure(amplifyconfiguration);
      debugPrint('Amplify configured');//デバッグ用。本番はloggerを使用
    }
  } on Exception catch (e) {
    debugPrint('Error configuring Amplify: $e');//デバッグ用。本番はloggerを使用
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureAmplify();
  runApp(
    ChangeNotifierProvider(
      create: (context) => UserProvider(),
      child: const HmApp(),
    ),
  );
}