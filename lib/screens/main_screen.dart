import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import '../services/llm_service.dart';
import '../services/template_service.dart';
import '../services/file_service.dart';
import '../models/generation_history.dart';
import '../models/output_format.dart';
import '../widgets/main_screen/main_screen_widgets.dart';
import '../widgets/main_screen/markdown_processor.dart';
import '../widgets/main_screen/html_processor.dart';
import '../widgets/main_screen/content_processor.dart';
import 'setup_screen.dart';
import 'template_management_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _rawRequirementsController = TextEditingController();
  final _changesController = TextEditingController();
  
  String _generatedTz = '';
  String _originalContent = ''; // Оригинальный контент для экспорта
  final List<GenerationHistory> _history = [];
  bool _isGenerating = false;
  String? _errorMessage;
  OutputFormat _selectedFormat = OutputFormat.markdown; // Default to Markdown
  
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
    final llmService = Provider.of<LLMService>(context, listen: false);
    final templateService = Provider.of<TemplateService>(context, listen: false);
    
    // Инициализируем конфигурацию, если она не загружена
    if (configService.config == null) {
      await configService.init();
    }
    
    if (configService.config != null) {
      // Load format preference from config
      setState(() {
        _selectedFormat = configService.config!.preferredFormat;
      });
      
      // Инициализируем провайдера
      llmService.initializeProvider(configService.config!);
      
      // Загружаем модели
      try {
        await llmService.getModels();
      } catch (e) {
        print('Ошибка при загрузке моделей: $e');
      }
      
      // Инициализируем шаблоны, если они еще не инициализированы
      if (!templateService.isInitialized) {
        try {
          await templateService.init();
        } catch (e) {
          print('Ошибка при инициализации шаблонов: $e');
        }
      }
    }
  }
  
  /// Handles format selection changes and persists preference
  Future<void> _onFormatChanged(OutputFormat format) async {
    if (format == _selectedFormat) return;
    
    setState(() {
      _selectedFormat = format;
    });
    
    // Persist format preference to config
    final configService = Provider.of<ConfigService>(context, listen: false);
    try {
      await configService.updatePreferredFormat(format);
    } catch (e) {
      print('Ошибка при сохранении предпочтения формата: $e');
      // Show error to user but don't revert the UI change
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось сохранить предпочтение формата: $e'),
          backgroundColor: Colors.orange.shade600,
        ),
      );
    }
  }
  
  /// Returns appropriate content processor for the given format
  ContentProcessor _getProcessorForFormat(OutputFormat format) {
    switch (format) {
      case OutputFormat.markdown:
        return MarkdownProcessor();
      case OutputFormat.confluence:
        return HtmlProcessor();
    }
  }
  
  Future<void> _generateTZ() async {
    if (_rawRequirementsController.text.trim().isEmpty) return;
    
    final configService = Provider.of<ConfigService>(context, listen: false);
    final llmService = Provider.of<LLMService>(context, listen: false);
    
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
      // Получаем активный шаблон
      final templateService = Provider.of<TemplateService>(context, listen: false);
      final activeTemplate = await templateService.getActiveTemplate();
      
      // Generate content using selected format
      final rawResponse = await llmService.generateTZ(
        rawRequirements: _rawRequirementsController.text,
        changes: _changesController.text.isNotEmpty ? _changesController.text : null,
        templateContent: activeTemplate?.content,
        format: _selectedFormat, // Pass selected format
      );
      
      // Use appropriate processor based on selected format
      final processor = _getProcessorForFormat(_selectedFormat);
      final extractedContent = processor.extractContent(rawResponse);
      
      setState(() {
        _originalContent = extractedContent; // Сохраняем оригинальный контент
        _generatedTz = extractedContent; // Для отображения используем тот же контент
        _history.insert(0, GenerationHistory(
          rawRequirements: _rawRequirementsController.text,
          changes: _changesController.text.isNotEmpty ? _changesController.text : null,
          generatedTz: extractedContent,
          timestamp: DateTime.now(),
          model: configService.config!.defaultModel ?? 'unknown',
          format: _selectedFormat,
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
    if (_originalContent.isEmpty) return;
    
    try {
      // Use the enhanced file service with format-specific handling and validation
      final filePath = await FileService.saveFileWithFormat(
        content: _originalContent,
        format: _selectedFormat,
      );
      
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
  
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SetupScreen()),
    );
  }

  void _openTemplateManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TemplateManagementScreen()),
    );
  }
  
  void _clearAll() {
    setState(() {
      _rawRequirementsController.clear();
      _changesController.clear();
      _generatedTz = '';
      _originalContent = '';
      _history.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConfigService>(
      builder: (context, configService, child) {
        // Если конфиг не загружен, перенаправляем на экран настроек
        if (configService.config == null) {
          return const SetupScreen();
        }
        
        // Обновляем выбранный формат из конфигурации
        if (_selectedFormat != configService.config!.preferredFormat) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _selectedFormat = configService.config!.preferredFormat;
            });
          });
        }
        
        return Scaffold(
          appBar: AppBar(
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.description, size: 20),
                label: const Text('Шаблоны ТЗ'),
                onPressed: _openTemplateManagement,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
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
            const ModelSettingsCard(),
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
                      onHistoryItemTap: (historyItem) {
                        setState(() {
                          _generatedTz = historyItem.generatedTz;
                          _originalContent = historyItem.generatedTz; // Также обновляем оригинальный контент
                          _selectedFormat = historyItem.format; // Restore format context
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
      },
    );
  }
}
