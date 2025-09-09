import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/config_service.dart';
import '../services/llm_service.dart';
import '../services/template_service.dart';
import '../services/file_service.dart';
import '../services/confluence_session_manager.dart';
import '../models/generation_history.dart';
import '../models/output_format.dart';
import '../widgets/main_screen/main_screen_widgets.dart';
import '../widgets/main_screen/markdown_processor.dart';
import '../widgets/main_screen/content_processor.dart';
import '../widgets/main_screen/confluence_publish_modal.dart';
import '../widgets/common/user_guidance_widget.dart';
import '../widgets/common/enhanced_tooltip.dart';
import 'setup_screen.dart';
import 'template_management_screen.dart';

// Custom intents for keyboard shortcuts
class SaveIntent extends Intent {
  const SaveIntent();
}
class CopyIntent extends Intent {
  const CopyIntent();
}
class PublishIntent extends Intent {
  const PublishIntent();
}
class ClearIntent extends Intent {
  const ClearIntent();
}
class HelpIntent extends Intent {
  const HelpIntent();
}
class TemplateIntent extends Intent {
  const TemplateIntent();
}
class SettingsIntent extends Intent {
  const SettingsIntent();
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  MainScreenState createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final _rawRequirementsController = TextEditingController();
  final _changesController = TextEditingController();
  
  String _generatedTz = '';
  String _originalContent = ''; // Оригинальный контент для экспорта
  final List<GenerationHistory> _history = [];
  bool _isGenerating = false;
  String? _errorMessage;
  OutputFormat _selectedFormat = OutputFormat.markdown; // Default to Markdown
  final bool _showGuidance = true;
  
  @override
  void initState() {
    super.initState();
    
    // Register for app lifecycle events
    WidgetsBinding.instance.addObserver(this);
    
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
    // Unregister from app lifecycle events
    WidgetsBinding.instance.removeObserver(this);
    
    // Trigger cleanup on application shutdown
    final sessionManager = ConfluenceSessionManager();
    sessionManager.triggerCleanup(fullCleanup: true);
    
    _rawRequirementsController.dispose();
    _changesController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Forward lifecycle events to session manager
    final sessionManager = ConfluenceSessionManager();
    sessionManager.handleLifecycleChange(state);
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

  void _copyToClipboard() {
    if (_generatedTz.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _generatedTz));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ТЗ скопировано в буфер обмена'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showConfluencePublishModal() {
    // Получаем заголовок из первой строки сгенерированного ТЗ, если он есть
    String? suggestedTitle;
    if (_generatedTz.isNotEmpty) {
      final firstLine = _generatedTz.split('\n').first.trim();
      if (firstLine.startsWith('#')) {
        // Если первая строка - заголовок в формате Markdown, удаляем символы #
        suggestedTitle = firstLine.replaceAll(RegExp(r'^#+\s*'), '');
      } else {
        // Иначе используем первую строку как есть, если она не слишком длинная
        suggestedTitle = firstLine.length > 100 ? '${firstLine.substring(0, 97)}...' : firstLine;
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => ConfluencePublishModal(
        content: _generatedTz,
        suggestedTitle: suggestedTitle,
      ),
    );
  }

  void _showKeyboardShortcuts() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.keyboard,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Keyboard Shortcuts',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close (Esc)',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Speed up your workflow with these shortcuts:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              _buildShortcutItem(
                'Ctrl+Enter',
                'Generate/Update specification',
                Icons.play_arrow,
                Colors.green,
              ),
              _buildShortcutItem(
                'Ctrl+S',
                'Save specification to file',
                Icons.save,
                Colors.blue,
              ),
              _buildShortcutItem(
                'Ctrl+C',
                'Copy specification to clipboard',
                Icons.copy,
                Colors.orange,
              ),
              _buildShortcutItem(
                'Ctrl+P',
                'Publish to Confluence (if enabled)',
                Icons.publish,
                Colors.purple,
              ),
              _buildShortcutItem(
                'Ctrl+R',
                'Clear all fields',
                Icons.clear,
                Colors.red,
              ),
              _buildShortcutItem(
                'F1',
                'Show this help',
                Icons.help,
                Colors.grey,
              ),
              _buildShortcutItem(
                'Esc',
                'Close dialogs',
                Icons.close,
                Colors.grey,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutItem(String shortcut, String description, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              shortcut,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const SaveIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC): const CopyIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyP): const PublishIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR): const ClearIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyT): const TemplateIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.comma): const SettingsIntent(),
        LogicalKeySet(LogicalKeyboardKey.f1): const HelpIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              if (!_isGenerating && _rawRequirementsController.text.trim().isNotEmpty) {
                _generateTZ();
              }
              return null;
            },
          ),
          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (SaveIntent intent) {
              if (_generatedTz.isNotEmpty) {
                _saveFile();
              }
              return null;
            },
          ),
          CopyIntent: CallbackAction<CopyIntent>(
            onInvoke: (CopyIntent intent) {
              if (_generatedTz.isNotEmpty) {
                _copyToClipboard();
              }
              return null;
            },
          ),
          PublishIntent: CallbackAction<PublishIntent>(
            onInvoke: (PublishIntent intent) {
              final configService = Provider.of<ConfigService>(context, listen: false);
              if (_generatedTz.isNotEmpty && 
                  configService.isConfluenceEnabled()) {
                _showConfluencePublishModal();
              }
              return null;
            },
          ),
          ClearIntent: CallbackAction<ClearIntent>(
            onInvoke: (ClearIntent intent) {
              _clearAll();
              return null;
            },
          ),
          HelpIntent: CallbackAction<HelpIntent>(
            onInvoke: (HelpIntent intent) {
              _showKeyboardShortcuts();
              return null;
            },
          ),
          TemplateIntent: CallbackAction<TemplateIntent>(
            onInvoke: (TemplateIntent intent) {
              _openTemplateManagement();
              return null;
            },
          ),
          SettingsIntent: CallbackAction<SettingsIntent>(
            onInvoke: (SettingsIntent intent) {
              _openSettings();
              return null;
            },
          ),
        },
        child: Consumer<ConfigService>(
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
        
        return Consumer<LLMService>(
          builder: (context, llmService, child) {
            return Scaffold(
              appBar: AppBar(
                actions: [
                  EnhancedTooltip(
                    message: 'Manage specification templates',
                    keyboardShortcut: 'Ctrl+T',
                    child: TextButton.icon(
                      icon: const Icon(Icons.description, size: 20),
                      label: const Text('Шаблоны ТЗ'),
                      onPressed: _openTemplateManagement,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  EnhancedTooltip(
                    message: 'Open application settings',
                    keyboardShortcut: 'Ctrl+,',
                    child: TextButton.icon(
                      icon: const Icon(Icons.settings, size: 20),
                      label: const Text('Настройки'),
                      onPressed: _openSettings,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  EnhancedTooltip(
                    message: 'Show keyboard shortcuts',
                    keyboardShortcut: 'F1',
                    child: IconButton(
                      icon: const Icon(Icons.help_outline, size: 20),
                      onPressed: _showKeyboardShortcuts,
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.black87,
                      ),
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
                
                // User guidance (show for first-time users or when helpful)
                if (_showGuidance && _generatedTz.isEmpty) ...[
                  Consumer<ConfigService>(
                    builder: (context, configService, child) {
                      return ConfluenceGuidanceWidget(
                        isConfluenceEnabled: configService.isConfluenceEnabled(),
                        hasValidConnection: configService.getConfluenceConfig()?.isValid ?? false,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                  
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
          }
        );
          },
        ),
      ),
    );
  }
}
