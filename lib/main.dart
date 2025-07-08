import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/app_config.dart';
import 'models/template.dart';
import 'services/config_service.dart';
import 'services/template_service.dart';
import 'services/llm_service.dart';
import 'screens/setup_screen.dart';
import 'screens/main_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализируем Hive
  await Hive.initFlutter();
  
  // Регистрируем только новые адаптеры (legacy адаптеры временно отключены)
  // Hive.registerAdapter(LegacyAppConfigAdapter()); // typeId = 1 (старая версия)
  // Hive.registerAdapter(LegacyAppConfigV2Adapter()); // typeId = 2 (промежуточная версия)
  Hive.registerAdapter(AppConfigAdapter()); // typeId = 10 (новая версия)
  Hive.registerAdapter(TemplateAdapter()); // typeId = 3
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConfigService()),
        ChangeNotifierProvider(create: (_) => TemplateService()),
        ChangeNotifierProvider(create: (_) => LLMService()),
      ],
      child: MaterialApp(
        title: 'TeeZeeNator',
        theme: AppTheme.light,
        home: FutureBuilder<bool>(
          future: _initializeServices(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            final hasConfig = snapshot.data ?? false;
            return hasConfig ? const MainScreen() : const SetupScreen();
          },
        ),
      ),
    );
  }
  
  Future<bool> _initializeServices() async {
    final configService = ConfigService();
    final templateService = TemplateService();
    
    try {
      // Инициализируем TemplateService
      await templateService.init();
      
      // Проверяем конфигурацию
      return await configService.hasValidConfiguration();
    } catch (e) {
      print('Error initializing services: $e');
      return false;
    }
  }
}
