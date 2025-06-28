import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/config_service.dart';
import '../services/openai_service.dart';
import '../services/file_service.dart';
import '../models/generation_history.dart';
import 'setup_screen.dart';

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _rawRequirementsController = TextEditingController();
  final _changesController = TextEditingController();
  
  String _generatedTz = '';
  List<GenerationHistory> _history = [];
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
      
      // Извлекаем только Markdown-документ из ответа
      final markdownTz = extractMarkdown(rawResponse);
      
      setState(() {
        _generatedTz = markdownTz;
        _history.insert(0, GenerationHistory(
          rawRequirements: _rawRequirementsController.text,
          changes: _changesController.text.isNotEmpty ? _changesController.text : null,
          generatedTz: markdownTz,
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
  
  Future<void> _saveMarkdown() async {
    if (_generatedTz.isEmpty) return;
    
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'TZ_$timestamp';
      
      // Сохраняем уже обработанный Markdown-документ
      final filePath = await FileService.saveMarkdownFile(_generatedTz, filename);
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
      _history.clear();
      _errorMessage = null;
    });
  }

  /// Извлекает Markdown-документ из ответа AI
  /// Ищет первый заголовок (начинающийся с "# ") и возвращает всё с этого места
  String extractMarkdown(String rawAiResponse) {
    final lines = rawAiResponse.split('\n');
    int markdownStartIndex = -1;
    
    // Ищем первую строку, начинающуюся с "# " (заголовок первого уровня)
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('# ')) {
        markdownStartIndex = i;
        break;
      }
    }
    
    // Если заголовок найден, возвращаем всё с этого места
    if (markdownStartIndex >= 0) {
      final markdownLines = lines.sublist(markdownStartIndex);
      
      // Удаляем пустые строки в конце
      while (markdownLines.isNotEmpty && markdownLines.last.trim().isEmpty) {
        markdownLines.removeLast();
      }
      
      return markdownLines.join('\n').trim();
    }
    
    // Если заголовок не найден, пытаемся найти любой заголовок уровня 2
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('## ')) {
        markdownStartIndex = i;
        break;
      }
    }
    
    if (markdownStartIndex >= 0) {
      // Добавляем основной заголовок
      final markdownLines = ['# Техническое задание', '', ...lines.sublist(markdownStartIndex)];
      
      // Удаляем пустые строки в конце
      while (markdownLines.isNotEmpty && markdownLines.last.trim().isEmpty) {
        markdownLines.removeLast();
      }
      
      return markdownLines.join('\n').trim();
    }
    
    // Если никаких заголовков не найдено, возвращаем весь текст с добавлением заголовка
    final cleanedResponse = rawAiResponse.trim();
    if (cleanedResponse.isNotEmpty) {
      return '# Техническое задание\n\n$cleanedResponse';
    }
    
    return rawAiResponse.trim();
  }

  /// Создает виджет для отображения Markdown с улучшенной стилизацией
  Widget renderMarkdown(String markdownText) {
    if (markdownText.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.description_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Сгенерированное ТЗ появится здесь',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Markdown(
        data: markdownText,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          // Стилизация заголовков
          h1: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
          h2: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          h3: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          h4: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          h5: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          h6: Theme.of(context).textTheme.titleSmall,
          
          // Стилизация основного текста
          p: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.5,
          ),
          
          // Стилизация списков
          listBullet: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
          
          // Стилизация кода
          code: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            backgroundColor: Colors.grey.shade100,
          ),
          codeblockDecoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          
          // Стилизация таблиц
          tableHead: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          tableBody: Theme.of(context).textTheme.bodyMedium,
          
          // Отступы
          blockSpacing: 16.0,
          listIndent: 24.0,
        ),
      ),
    );
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
            // Выбор модели
            Consumer2<ConfigService, OpenAIService>(
              builder: (context, configService, openAIService, child) {
                // Всегда показываем карточку с информацией
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Text('Модель: ', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: openAIService.availableModels.isNotEmpty 
                            ? DropdownButton<String>(
                                value: configService.config?.selectedModel,
                                isExpanded: true,
                                items: openAIService.availableModels.map((model) {
                                  return DropdownMenuItem<String>(
                                    value: model.id,
                                    child: Text(model.id),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    configService.updateSelectedModel(newValue);
                                  }
                                },
                              )
                            : Text(
                                openAIService.isLoading 
                                  ? 'Загрузка моделей...' 
                                  : 'Модели не загружены',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                        ),
                        const SizedBox(width: 16),
                        // Кнопка обновления моделей
                        if (configService.config != null)
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 20),
                            onPressed: openAIService.isLoading ? null : () async {
                              await openAIService.getModels(configService.config!);
                            },
                            tooltip: 'Обновить список моделей',
                          ),
                        const SizedBox(width: 8),
                        const Text('Шаблон ТЗ: '),
                        const SizedBox(width: 8),
                        Switch(
                          value: _useBaseTemplate,
                          onChanged: (bool value) {
                            setState(() {
                              _useBaseTemplate = value;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _useBaseTemplate ? 'включен' : 'отключен',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: _useBaseTemplate ? Colors.green[700] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
              
              // Основной контент с адаптивной высотой
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Левая колонка - поля ввода
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Сырые требования
                          const Text(
                            'Сырые требования:',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextField(
                                  controller: _rawRequirementsController,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Введите сырые требования...',
                                    hintStyle: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Поле изменений (показывается после первой генерации)
                          if (_generatedTz.isNotEmpty) ...[
                            const Text(
                              'Изменения и дополнения:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 150, // Фиксированная высота для изменений
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: TextField(
                                  controller: _changesController,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Введите изменения или дополнения...',
                                    hintStyle: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          // Кнопки
                          Row(
                            children: [
                              Consumer<ConfigService>(
                                builder: (context, configService, child) {
                                  final canGenerate = configService.config != null && 
                                                    _rawRequirementsController.text.trim().isNotEmpty &&
                                                    !_isGenerating;
                                  
                                  return ElevatedButton(
                                    onPressed: canGenerate ? _generateTZ : null,
                                    child: _isGenerating 
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Text(_generatedTz.isEmpty ? 'Сгенерировать ТЗ' : 'Обновить ТЗ'),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _clearAll,
                                icon: const Icon(Icons.clear, size: 16),
                                label: const Text('Очистить'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.shade50,
                                  foregroundColor: Colors.orange.shade700,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // История запросов (перенесена в левую колонку)
                          if (_history.isNotEmpty) ...[
                            const Text(
                              'История запросов:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 200, // Фиксированная высота для истории
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.builder(
                                itemCount: _history.length,
                                itemBuilder: (context, index) {
                                  final item = _history[index];
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      '${item.timestamp.day}.${item.timestamp.month}.${item.timestamp.year} ${item.timestamp.hour}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Модель: ${item.model}',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        Text(
                                          item.rawRequirements.length > 50
                                              ? '${item.rawRequirements.substring(0, 50)}...'
                                              : item.rawRequirements,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    onTap: () {
                                      setState(() {
                                        // Убеждаемся, что отображаем обработанный Markdown
                                        _generatedTz = item.generatedTz;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                          
                          // Ошибка
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Правая колонка - результат
                    Expanded(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Заголовок и кнопка сохранения
                          Row(
                            children: [
                              const Text(
                                'Сгенерированное ТЗ:',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              const Spacer(),
                              if (_generatedTz.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: _saveMarkdown,
                                  icon: const Icon(Icons.save, size: 16),
                                  label: const Text('Сохранить .md'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          // Область отображения Markdown (растягивается на всё доступное пространство)
                          Expanded(
                            child: renderMarkdown(_generatedTz),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'TeeZeeNator v1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          'Создано',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Koteyye',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
      ),
    );
  }
}
