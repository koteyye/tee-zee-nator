import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import '../services/openai_service.dart';
import '../services/file_service.dart';
import '../models/generation_history.dart';
import '../widgets/main_screen/main_screen_widgets.dart';
import 'setup_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _rawRequirementsController = TextEditingController();
  final _changesController = TextEditingController();
  
  String _generatedTz = '';
  String _originalHtml = ''; // Оригинальный HTML для экспорта
  final List<GenerationHistory> _history = [];
  bool _isGenerating = false;
  String? _errorMessage;
  bool _useBaseTemplate = true; // Новое состояние для переключателя
  
  @override
  void initState() {
    super.initState();
    
    _loadModels();
    
    // Добавляем слушателей для обновления состояния кнопки
    _rawRequirementsController.addListener(() {
      setState(() {});
    });
    _changesController.addListener(() {
      setState(() {});
    });
  }
  
  @override
  void dispose() {
    _rawRequirementsController.dispose();
    _changesController.dispose();
    super.dispose();
  }
  
  Future<void> _loadModels() async {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final openAIService = Provider.of<OpenAIService>(context, listen: false);
    
    // Инициализируем конфигурацию, если она не загружена
    if (configService.config == null) {
      await configService.init();
    }
    
    if (configService.config != null) {
      await openAIService.getModels(configService.config!);
    }
  }
  
  Future<void> _generateTZ() async {
    if (_rawRequirementsController.text.trim().isEmpty) return;
    
    final configService = Provider.of<ConfigService>(context, listen: false);
    final openAIService = Provider.of<OpenAIService>(context, listen: false);
    
    // Проверяем наличие конфигурации
    if (configService.config == null) {
      setState(() {
        _errorMessage = 'Конфигурация не найдена. Перейдите в настройки.';
      });
      return;
    }
    
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });
    
    try {
      final rawResponse = await openAIService.generateTZ(
        config: configService.config!,
        rawRequirements: _rawRequirementsController.text,
        changes: _changesController.text.isNotEmpty ? _changesController.text : null,
        useBaseTemplate: _useBaseTemplate,
      );
      
      // Извлекаем HTML-документ из ответа
      final extractedContent = HtmlProcessor.extractHtml(rawResponse);
      
      setState(() {
        _originalHtml = extractedContent; // Сохраняем оригинальный HTML
        _generatedTz = extractedContent; // Для отображения используем тот же HTML
        _history.insert(0, GenerationHistory(
          rawRequirements: _rawRequirementsController.text,
          changes: _changesController.text.isNotEmpty ? _changesController.text : null,
          generatedTz: extractedContent,
          timestamp: DateTime.now(),
          model: configService.config!.selectedModel ?? 'unknown',
        ));
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }
  
  Future<void> _saveFile() async {
    if (_originalHtml.isEmpty) return;
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'TZ_$timestamp';
      
      // Сохраняем оригинальный HTML документ (без преобразований)
      final filePath = await FileService.saveFile(_originalHtml, filename);
      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Файл сохранен: $filePath'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка сохранения: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }
  
  void _openSettings() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => SetupScreen()),
    );
    
    // Если пользователь вернулся из настроек, перезагружаем модели
    if (result != null || mounted) {
      await _loadModels();
    }
  }
  
  void _clearAll() {
    setState(() {
      _rawRequirementsController.clear();
      _changesController.clear();
      _generatedTz = '';
      _originalHtml = '';
      _history.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.settings, size: 20),
            label: const Text('Настройки'),
            onPressed: _openSettings,
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Настройки модели
            ModelSettingsCard(
              useBaseTemplate: _useBaseTemplate,
              onTemplateToggle: (value) {
                setState(() {
                  _useBaseTemplate = value;
                });
              },
            ),
            const SizedBox(height: 16),
              
            // Основной контент
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Левая панель - ввод
                  Expanded(
                    flex: 1,
                    child: InputPanel(
                      rawRequirementsController: _rawRequirementsController,
                      changesController: _changesController,
                      generatedTz: _generatedTz,
                      history: _history,
                      isGenerating: _isGenerating,
                      errorMessage: _errorMessage,
                      onGenerate: _generateTZ,
                      onClear: _clearAll,
                      onHistoryItemTap: (generatedTz) {
                        setState(() {
                          _generatedTz = generatedTz;
                          _originalHtml = generatedTz; // Также обновляем оригинальный HTML
                        });
                      },
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Правая панель - результат
                  Expanded(
                    flex: 1,
                    child: ResultPanel(
                      generatedTz: _generatedTz,
                      onSave: _saveFile,
                    ),
                  ),
                ],
              ),
            ),
              
            const SizedBox(height: 16),
            
            // Footer
            const AppFooter(),
          ],
        ),
      ),
    );
  }
}
