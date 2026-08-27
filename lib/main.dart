import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'amplifyconfiguration.dart';
import 'app/app.dart';
import 'features/measure/presentation/measurement_session_screen.dart';
import 'providers/user_provider.dart';

Future<void> _configureAmplify() async {
  try {
    if (!Amplify.isConfigured) {
      await Amplify.addPlugins([AmplifyAuthCognito()]);
      await Amplify.configure(amplifyconfiguration);
    }
  } on Exception catch (e) {
    debugPrint('Error configuring Amplify: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureAmplify();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => MeasurementStateProvider()),
      ],
      child: const HmApp(),
    ),
  );
}
