import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'models/app_config.dart';
import 'models/template.dart';
import 'models/output_format.dart';
import 'models/confluence_config.dart';
import 'models/spec_music_config.dart';
import 'services/config_service.dart';
import 'services/template_service.dart';
import 'services/llm_service.dart';
import 'services/streaming_llm_service.dart';
import 'services/confluence_service.dart';
import 'services/app_info_service.dart';
import 'services/project_service.dart';
import 'services/file_explorer_service.dart';
import 'services/file_modification_service.dart';
import 'services/ai_chat_service.dart';
import 'services/content_renderer_service.dart';
import 'screens/setup_screen.dart';
import 'screens/ide_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  // Глобальная обработка ошибок, чтобы не оставлять «черный экран» без логов на desktop
  FlutterError.onError = (details) {
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
    debugPrint(details.stack?.toString());
  };

  // Инициализация в защищенной зоне — любые необработанные исключения логируем
  runZonedGuarded(() async {
  // Перенесено внутрь зоны, чтобы избежать предупреждения Zone mismatch
  WidgetsFlutterBinding.ensureInitialized();
    try {
      await Hive.initFlutter();
    } catch (e, st) {
      debugPrint('[main] Hive.initFlutter error: $e');
      debugPrint(st.toString());
    }

  // (Dev wipe removed) — данные Hive больше не очищаются принудительно при старте

    // Регистрируем адаптеры с сохранением generic-типа (иначе Hive регистрирует для dynamic и ломается маппинг типов)
    void safeRegister<T>(TypeAdapter<T> adapter, String name) {
      try {
        Hive.registerAdapter<T>(adapter);
      } catch (e) {
        debugPrint('[main] Adapter $name register skipped: $e');
      }
    }
  // ВАЖНО: сначала регистрируем все enum/простые адаптеры, затем составные модели
  safeRegister<TemplateFormat>(TemplateFormatAdapter(), 'TemplateFormatAdapter');
  safeRegister<OutputFormat>(OutputFormatAdapter(), 'OutputFormatAdapter');
  safeRegister<AppConfig>(AppConfigAdapter(), 'AppConfigAdapter');
  safeRegister<ConfluenceConfig>(ConfluenceConfigAdapter(), 'ConfluenceConfigAdapter');
  safeRegister<SpecMusicConfig>(SpecMusicConfigAdapter(), 'SpecMusicConfigAdapter');
  safeRegister<Template>(TemplateAdapter(), 'TemplateAdapter');

    // Инициализируем AppInfoService
    final appInfoService = AppInfoService();
    try {
      await appInfoService.init();
    } catch (e, st) {
      debugPrint('[main] AppInfoService.init error: $e');
      debugPrint(st.toString());
    }

    // НЕ блокируем первый кадр await-ом init(). Инициализация пройдет уже внутри FutureBuilder.
    final preConfigService = ConfigService();
    runApp(MyApp(
      preInitialized: preConfigService,
      appInfoService: appInfoService,
    ));
  }, (error, stack) {
    debugPrint('[ZoneError] $error');
    debugPrint(stack.toString());
  });
}

class MyApp extends StatefulWidget {
  final ConfigService preInitialized;
  final AppInfoService appInfoService;
  const MyApp({
    super.key,
    required this.preInitialized,
    required this.appInfoService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _reloadToken = 0; // меняем для перезапуска FutureBuilder

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Основные сервисы
        ChangeNotifierProvider(create: (_) => widget.preInitialized),
        ChangeNotifierProvider(create: (_) => TemplateService()),
        ChangeNotifierProvider(create: (_) => LLMService()),
        ChangeNotifierProvider(create: (_) => ConfluenceService()),
        Provider<AppInfoService>.value(value: widget.appInfoService),
        
        // StreamingLLMService (не ChangeNotifier, простой Provider)
        ProxyProvider<LLMService, StreamingLLMService>(
          update: (context, llm, previous) => StreamingLLMService(llmService: llm),
        ),
        
        // Новые сервисы для IDE (с зависимостями)
        ChangeNotifierProvider(create: (_) => ProjectService()),
        ChangeNotifierProvider(create: (_) => FileExplorerService()),
        Provider(create: (_) => ContentRendererService()),
        ChangeNotifierProxyProvider<ProjectService, FileModificationService>(
          create: (context) => FileModificationService(
            context.read<ProjectService>(),
          ),
          update: (context, projectService, previous) =>
              previous ?? FileModificationService(projectService),
        ),
        ChangeNotifierProxyProvider4<
          StreamingLLMService,
          ConfluenceService,
          FileModificationService,
          ProjectService,
          AIChatService
        >(
          create: (context) => AIChatService(
            llmService: context.read<StreamingLLMService>(),
            confluenceService: context.read<ConfluenceService>(),
            fileModificationService: context.read<FileModificationService>(),
            projectService: context.read<ProjectService>(),
          ),
          update: (context, llm, confluence, fileMod, project, previous) =>
              previous ?? AIChatService(
                llmService: llm,
                confluenceService: confluence,
                fileModificationService: fileMod,
                projectService: project,
              ),
        ),
      ],
      child: Builder(
        builder: (innerContext) => MaterialApp(
          title: 'TeeZeeNator',
          theme: AppTheme.light,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('ru'),
            Locale('en'),
          ],
          locale: const Locale('ru'),
          home: FutureBuilder<bool>(
            key: ValueKey(_reloadToken),
            // Первая инициализация сервисов с таймаутом, чтобы не зависнуть навсегда при проблемах с файловой системой / Hive
            future: _initializeServices(innerContext)
                .timeout(const Duration(seconds: 8), onTimeout: () {
              debugPrint('[MyApp] _initializeServices timeout — fallback to SetupScreen');
              return false; // Покажем экран настройки как безопасный fallback
            }),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Инициализация...')
                      ],
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                debugPrint('[MyApp] init error: ${snapshot.error}');
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        const Text('Проблема инициализации'),
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() { _reloadToken++; }); // Перезапустить FutureBuilder
                          },
                          child: const Text('Повторить'),
                        )
                      ],
                    ),
                  ),
                );
              }
              final hasConfig = snapshot.data ?? false;
              
              if (!hasConfig) {
                return const SetupScreen();
              }
              
              // Возвращаем новый IDE-интерфейс
              // TODO: Добавить переключатель в AppConfig при необходимости
              return const IDEScreen();
            },
          ),
        ),
      ),
    );
  }
  
  Future<bool> _initializeServices(BuildContext context) async {
    try {
      // Get service instances from Provider context
      final configService = Provider.of<ConfigService>(context, listen: false);
      final templateService = Provider.of<TemplateService>(context, listen: false);
      // Ensure config is initialized (early preInit may already have done this)
      await configService.init();
      
      // Initialize TemplateService
      await templateService.init();
      
      // Check configuration
      return await configService.hasValidConfiguration();
    } catch (e) {
      print('Error initializing services: $e');
      return false;
    }
  }
}
