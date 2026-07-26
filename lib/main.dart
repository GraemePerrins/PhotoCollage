import 'package:flutter/material.dart';
import 'services/settings_service.dart';
import 'screens/main_layout.dart';
import 'theme/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the local settings database
  final settings = SettingsService();
  await settings.init();

  runApp(const CollageStudioApp());
}

class CollageStudioApp extends StatelessWidget {
  const CollageStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CollageStudio',
      debugShowCheckedModeBanner: false,
      theme: StitchTheme.darkTheme,
      home: const MainLayout(),
    );
  }
}
