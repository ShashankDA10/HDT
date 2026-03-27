import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_wrapper.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService.initialize();
  runApp(const BodyCloneApp());
}

class BodyCloneApp extends StatelessWidget {
  const BodyCloneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Twin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AuthWrapper(),
    );
  }
}
