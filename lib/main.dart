import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/app_config.dart';
import 'services/openai_service.dart';
import 'services/config_service.dart';
import 'screens/setup_screen.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализируем Hive
  await Hive.initFlutter();
  Hive.registerAdapter(AppConfigAdapter());
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConfigService()),
        ChangeNotifierProvider(create: (_) => OpenAIService()),
      ],
      child: MaterialApp(
        title: 'TeeZeeNator',
        theme: AppTheme.light,
        home: FutureBuilder<bool>(
          future: _checkConfiguration(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            final hasConfig = snapshot.data ?? false;
            return hasConfig ? MainScreen() : SetupScreen();
          },
        ),
      ),
    );
  }
  
  Future<bool> _checkConfiguration() async {
    final configService = ConfigService();
    return await configService.hasValidConfiguration();
  }
}
