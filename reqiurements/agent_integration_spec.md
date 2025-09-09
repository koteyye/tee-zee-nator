
# Спецификация интеграции агентского подхода в tee-zee-nator

## 1. Обзор

Данная спецификация описывает интеграцию агентского подхода к генерации технических заданий в существующее приложение tee-zee-nator. Основная идея - структурированный JSON ответ от LLM с действиями (actions) и пошаговой генерацией контента в `ResultPanel`.

## 2. Миграция с классического на агентский подход

### 2.1 Текущая архитектура (заменяется)
- **LLMService**: Генерирует простой текст (Markdown/HTML) с маркерами `@@@START@@@` и `@@@END@@@`
- **ResultPanel**: Статическое отображение сгенерированного контента
- **MainScreen**: Управляет состоянием генерации
- **Простые модели**: `ChatMessage` для API запросов

### 2.2 Новая агентская архитектура (заменяет классическую)
- **LLM возвращает структурированный JSON** с действиями и обновлениями
- **ResultPanel становится интерактивной** - показывает прогресс генерации в реальном времени
- **Пошаговое выполнение действий** - валидация, генерация разделов, улучшения
- **Богатые модели данных** - `AgentAction`, `TechnicalSpecification`, `AgentResponse`
- **Полная замена** существующих методов генерации

## 3. Новые модели данных

### 3.1 lib/models/agent_response.dart
```dart
import 'package:json_annotation/json_annotation.dart';
import 'agent_action.dart';

part 'agent_response.g.dart';

@JsonSerializable()
class AgentResponse {
  @JsonKey(name: 'user_message')
  final String userMessage;
  
  final List<AgentAction>? actions;
  
  @JsonKey(name: 'template_update')
  final Map<String, String>? templateUpdate;
  
  @JsonKey(name: 'specification_sections')
  final Map<String, String>? specificationSections;

  const AgentResponse({
    required this.userMessage,
    this.actions,
    this.templateUpdate,
    this.specificationSections,
  });

  factory AgentResponse.fromJson(Map<String, dynamic> json) =>
      _$AgentResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AgentResponseToJson(this);
}
```

### 3.2 lib/models/agent_action.dart
```dart
import 'package:json_annotation/json_annotation.dart';

part 'agent_action.g.dart';

enum AgentActionType {
  @JsonValue('generate_content')
  generateContent,
  @JsonValue('validate_requirements')
  validateRequirements,
  @JsonValue('suggest_improvements')
  suggestImprovements,
  @JsonValue('create_structure')
  createStructure,
  @JsonValue('update_section')
  updateSection,
}

@JsonSerializable()
class AgentAction {
  final AgentActionType type;
  final String? section;
  final String? content;
  final List<String>? suggestions;
  final Map<String, dynamic>? metadata;
  @JsonKey(name: 'progress_message')
  final String? progressMessage;

  const AgentAction({
    required this.type,
    this.section,
    this.content,
    this.suggestions,
    this.metadata,
    this.progressMessage,
  });

  factory AgentAction.fromJson(Map<String, dynamic> json) =>
      _$AgentActionFromJson(json);

  Map<String, dynamic> toJson() => _$AgentActionToJson(this);
}
```

### 3.3 lib/models/technical_specification.dart
```dart
import 'package:json_annotation/json_annotation.dart';

part 'technical_specification.g.dart';

enum SpecStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('generating')
  generating,
  @JsonValue('review')
  review,
  @JsonValue('completed')
  completed,
}

@JsonSerializable()
class SpecMetadata {
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  
  final String version;
  final SpecStatus status;
  @JsonKey(name: 'progress_percentage')
  final double progressPercentage;

  const SpecMetadata({
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.status,
    this.progressPercentage = 0.0,
  });

  factory SpecMetadata.fromJson(Map<String, dynamic> json) =>
      _$SpecMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$SpecMetadataToJson(this);

  SpecMetadata copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    String? version,
    SpecStatus? status,
    double? progressPercentage,
  }) {
    return SpecMetadata(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      status: status ?? this.status,
      progressPercentage: progressPercentage ?? this.progressPercentage,
    );
  }
}

@JsonSerializable()
class TechnicalSpecification {
  final String title;
  final Map<String, String> sections;
  final SpecMetadata metadata;
  @JsonKey(name: 'generation_steps')
  final List<String> generationSteps;

  const TechnicalSpecification({
    required this.title,
    required this.sections,
    required this.metadata,
    this.generationSteps = const [],
  });

  factory TechnicalSpecification.fromJson(Map<String, dynamic> json) =>
      _$TechnicalSpecificationFromJson(json);

  Map<String, dynamic> toJson() => _$TechnicalSpecificationToJson(this);

  TechnicalSpecification copyWith({
    String? title,
    Map<String, String>? sections,
    SpecMetadata? metadata,
    List<String>? generationSteps,
  }) {
    return TechnicalSpecification(
      title: title ?? this.title,
      sections: sections ?? Map<String, String>.from(this.sections),
      metadata: metadata ?? this.metadata,
      generationSteps: generationSteps ?? List<String>.from(this.generationSteps),
    );
  }

  factory TechnicalSpecification.empty() {
    final now = DateTime.now();
    return TechnicalSpecification(
      title: 'Новое техническое задание',
      sections: {},
      metadata: SpecMetadata(
        createdAt: now,
        updatedAt: now,
        version: '1.0.0',
        status: SpecStatus.draft,
        progressPercentage: 0.0,
      ),
      generationSteps: [],
    );
  }
}
```

## 4. Модификация LLMService

### 4.1 Замена метода generateTZ на агентский подход
```dart
/// Генерирует техническое задание с использованием агентского подхода
/// ЗАМЕНЯЕТ существующий метод generateTZ()
Future<AgentResponse> generateTZ({
  required String rawRequirements,
  String? changes,
  String? templateContent,
  OutputFormat format = OutputFormat.markdown,
  Function(String)? onProgress,
}) async {
  // Validate service state
  _validateServiceState();
  
  // Process Confluence content markers
  final processedRawRequirements = processConfluenceContent(rawRequirements);
  final processedChanges = changes != null ? processConfluenceContent(changes) : null;
  
  // Generate agent system prompt
  String systemPrompt = _buildAgentSystemPrompt(templateContent, format);
  
  // Build user prompt
  String userPrompt = _buildAgentUserPrompt(processedRawRequirements, processedChanges, format);
  
  // Send request
  final rawResponse = await _provider!.sendRequest(
    systemPrompt: systemPrompt,
    userPrompt: userPrompt,
    model: _config!.defaultModel,
    temperature: 0.7,
  );
  
  // Parse agent response
  final agentResponse = _parseAgentResponse(rawResponse);
  
  notifyListeners();
  return agentResponse;
}
```

### 4.2 Новый системный промпт для агентов
```dart
String _buildAgentSystemPrompt(String? templateContent, OutputFormat format) {
  final formatName = format == OutputFormat.markdown ? 'Markdown' : 'HTML (Confluence)';
  final formatRules = format == OutputFormat.markdown 
    ? 'Используй только стандартный Markdown синтаксис без HTML тегов'
    : 'Используй HTML теги: <h1>, <h2>, <p>, <ul>, <li>, <strong>, <table> и Confluence макросы';

  return '''Ты ИИ-агент для создания технических заданий. Работаешь пошагово, генерируя структурированные ответы.

ФОРМАТ ВЫВОДА: Строго JSON со следующей структурой:

{
  "user_message": "дружелюбное сообщение пользователю о текущем шаге",
  "actions": [
    {
      "type": "generate_content",
      "section": "название_раздела",
      "content": "сгенерированный контент в формате $formatName",
      "progress_message": "Генерирую раздел 'название_раздела'..."
    }
  ],
  "specification_sections": {
    "section_name": "обновленный контент раздела",
    "another_section": "другой контент"
  }
}

ТИПЫ ДЕЙСТВИЙ:
- "generate_content" - генерация контента для конкретного раздела ТЗ
- "validate_requirements" - валидация требований
- "suggest_improvements" - предложение улучшений  
- "create_structure" - создание структуры документа
- "update_section" - обновление существующего раздела

ПРАВИЛА ГЕНЕРАЦИИ:
1. $formatRules
2. Работай пошагово - генерируй по 1-2 раздела за раз
3. В user_message объясняй что делаешь
4. В progress_message указывай текущий прогресс
5. ВСЕГДА возвращай валидный JSON без дополнительного текста

${templateContent != null ? 'ШАБЛОН:\n$templateContent\n' : ''}''';
}
```

## 5. Модификация ResultPanel

### 5.1 Новое состояние ResultPanel
```dart
class ResultPanel extends StatefulWidget {
  final String generatedTz;
  final TechnicalSpecification? specification;
  final bool isGenerating;
  final double? progress;
  final String? currentStep;
  final VoidCallback onSave;

  const ResultPanel({
    super.key,
    required this.generatedTz,
    this.specification,
    this.isGenerating = false,
    this.progress,
    this.currentStep,
    required this.onSave,
  });

  @override
  State<ResultPanel> createState() => _ResultPanelState();
}
```

### 5.2 Виджет прогресса генерации
```dart
Widget _buildGenerationProgress() {
  if (!widget.isGenerating) return const SizedBox.shrink();
  
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      border: Border.all(color: Colors.blue.shade200),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Агент генерирует ТЗ...',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        if (widget.progress != null) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: widget.progress! / 100,
            backgroundColor: Colors.blue.shade100,
            valueColor: AlwaysStoppedAnimation(Colors.blue.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.progress!.toInt()}% завершено',
            style: TextStyle(
              fontSize: 12,
              color: Colors.blue.shade700,
            ),
          ),
        ],
        if (widget.currentStep != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.currentStep!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    ),
  );
}
```

## 6. Сервис выполнения действий агента

### 6.1 lib/services/agent_executor.dart
```dart
import 'package:flutter/foundation.dart';
import '../models/agent_action.dart';
import '../models/technical_specification.dart';

class AgentExecutor extends ChangeNotifier {
  TechnicalSpecification _currentSpec;
  double _progress = 0.0;
  String? _currentStep;
  
  AgentExecutor(this._currentSpec);

  TechnicalSpecification get currentSpec => _currentSpec;
  double get progress => _progress;
  String? get currentStep => _currentStep;

  Future<String> executeAction(AgentAction action) async {
    _currentStep = action.progressMessage ?? 'Выполняю действие...';
    notifyListeners();
    
    String result;
    
    switch (action.type) {
      case AgentActionType.generateContent:
        result = await _generateContent(action);
        break;
      case AgentActionType.validateRequirements:
        result = await _validateRequirements(action);
        break;
      case AgentActionType.suggestImprovements:
        result = await _suggestImprovements(action);
        break;
      case AgentActionType.createStructure:
        result = await _createStructure(action);
        break;
      case AgentActionType.updateSection:
        result = await _updateSection(action);
        break;
    }
    
    _updateProgress();
    notifyListeners();
    
    return result;
  }

  Future<String> _generateContent(AgentAction action) async {
    if (action.section == null || action.content == null) {
      throw Exception('Для generate_content требуются поля section и content');
    }

    // Добавляем шаг генерации
    final steps = List<String>.from(_currentSpec.generationSteps);
    steps.add('Сгенерирован раздел: ${action.section}');

    // Обновляем секцию в текущем ТЗ
    final updatedSections = Map<String, String>.from(_currentSpec.sections);

    updatedSections[action.section!] = action.content!;

    _currentSpec = _currentSpec.copyWith(
      sections: updatedSections,
      generationSteps: steps,
      metadata: _currentSpec.metadata.copyWith(
        updatedAt: DateTime.now(),
        status: SpecStatus.generating,
      ),
    );

    return 'Раздел "${action.section}" успешно сгенерирован';
  }

  Future<String> _validateRequirements(AgentAction action) async {
    final issues = <String>[];
    
    // Проверяем обязательные разделы
    const requiredSections = [
      'overview', 'requirements', 'acceptance_criteria'
    ];
    
    for (final section in requiredSections) {
      if (!_currentSpec.sections.containsKey(section) ||
          _currentSpec.sections[section]?.trim().isEmpty == true) {
        issues.add('Отсутствует раздел: $section');
      }
    }

    final steps = List<String>.from(_currentSpec.generationSteps);
    if (issues.isEmpty) {
      steps.add('Валидация пройдена успешно');
      return 'Все требования корректны';
    } else {
      steps.add('Найдены проблемы валидации: ${issues.length}');
      return 'Найдены проблемы: ${issues.join(', ')}';
    }
  }

  Future<String> _suggestImprovements(AgentAction action) async {
    final suggestions = action.suggestions ?? [];
    
    final steps = List<String>.from(_currentSpec.generationSteps);
    steps.add('Предложены улучшения: ${suggestions.length}');
    
    _currentSpec = _currentSpec.copyWith(generationSteps: steps);
    
    return 'Предложения по улучшению: ${suggestions.join('; ')}';
  }

  Future<String> _createStructure(AgentAction action) async {
    const defaultSections = {
      'overview': 'Описание проекта',
      'goals': 'Цели и задачи',
      'requirements': 'Функциональные требования',
      'technical_requirements': 'Технические требования',
      'acceptance_criteria': 'Критерии приемки',
      'timeline': 'Временные рамки',
      'resources': 'Ресурсы',
    };

    // Объединяем с существующими секциями
    final updatedSections = <String, String>{
      ...defaultSections,
      ..._currentSpec.sections,
    };

    final steps = List<String>.from(_currentSpec.generationSteps);
    steps.add('Создана базовая структура ТЗ');

    _currentSpec = _currentSpec.copyWith(
      sections: updatedSections,
      generationSteps: steps,
      metadata: _currentSpec.metadata.copyWith(
        updatedAt: DateTime.now(),
        status: SpecStatus.generating,
      ),
    );

    return 'Структура технического задания создана';
  }

  Future<String> _updateSection(AgentAction action) async {
    if (action.section == null || action.content == null) {
      throw Exception('Для update_section требуются поля section и content');
    }

    final updatedSections = Map<String, String>.from(_currentSpec.sections);
    updatedSections[action.section!] = action.content!;

    final steps = List<String>.from(_currentSpec.generationSteps);
    steps.add('Обновлен раздел: ${action.section}');

    _currentSpec = _currentSpec.copyWith(
      sections: updatedSections,
      generationSteps: steps,
      metadata: _currentSpec.metadata.copyWith(
        updatedAt: DateTime.now(),
      ),
    );

    return 'Раздел "${action.section}" обновлен';
  }

  void applyTemplateUpdates(Map<String, String> updates) {
    final updatedSections = Map<String, String>.from(_currentSpec.sections);
    updatedSections.addAll(updates);

    final steps = List<String>.from(_currentSpec.generationSteps);
    steps.add('Применены обновления шаблона: ${updates.keys.length}');

    _currentSpec = _currentSpec.copyWith(
      sections: updatedSections,
      generationSteps: steps,
      metadata: _currentSpec.metadata.copyWith(
        updatedAt: DateTime.now(),
      ),
    );
  }

  void _updateProgress() {
    // Простая логика расчета прогресса
    final totalSections = 7; // Предполагаемое количество разделов
    final completedSections = _currentSpec.sections.length;
    _progress = (completedSections / totalSections * 100).clamp(0.0, 100.0);
    
    // Если все разделы заполнены, помечаем как завершенное
    if (_progress >= 90.0) {
      _currentSpec = _currentSpec.copyWith(
        metadata: _currentSpec.metadata.copyWith(
          status: SpecStatus.completed,
          progressPercentage: 100.0,
        ),
      );
      _currentStep = 'Генерация завершена';
    }
  }

  void updateSpec(TechnicalSpecification newSpec) {
    _currentSpec = newSpec;
    notifyListeners();
  }

  void resetProgress() {
    _progress = 0.0;
    _currentStep = null;
    notifyListeners();
  }
}
```

## 7. Контроллер агентской генерации

### 7.1 lib/services/agent_controller.dart
```dart
import 'package:flutter/foundation.dart';
import '../models/agent_response.dart';
import '../models/technical_specification.dart';
import '../services/llm_service.dart';
import '../services/agent_executor.dart';
import '../models/output_format.dart';

class AgentController extends ChangeNotifier {
  final LLMService _llmService;
  late AgentExecutor _executor;
  bool _isProcessing = false;
  String? _error;
  String? _currentUserMessage;

  AgentController({required LLMService llmService}) 
      : _llmService = llmService {
    _executor = AgentExecutor(TechnicalSpecification.empty());
  }

  // Геттеры
  TechnicalSpecification get currentSpec => _executor.currentSpec;
  bool get isProcessing => _isProcessing;
  String? get error => _error;
  double get progress => _executor.progress;
  String? get currentStep => _executor.currentStep;
  String? get currentUserMessage => _currentUserMessage;

  Future<void> handleAgentRequest({
    required String rawRequirements,
    String? changes,
    String? templateContent,
    OutputFormat format = OutputFormat.markdown,
  }) async {
    if (rawRequirements.trim().isEmpty || _isProcessing) return;

    _setProcessing(true);
    _clearError();
    _executor.resetProgress();

    try {
      // Отправляем запрос к агенту
      final agentResponse = await _llmService.generateAgentTZ(
        rawRequirements: rawRequirements,
        changes: changes,
        templateContent: templateContent,
        format: format,
      );

      // Обрабатываем ответ агента
      await _processAgentResponse(agentResponse);

    } catch (e) {
      _setError('Произошла ошибка: $e');
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> _processAgentResponse(AgentResponse response) async {
    // Сохраняем сообщение для пользователя
    _currentUserMessage = response.userMessage;
    notifyListeners();

    // Выполняем действия если есть
    if (response.actions != null) {
      for (final action in response.actions!) {
        try {
          final result = await _executor.executeAction(action);
          debugPrint('Действие ${action.type.name}: $result');
        } catch (e) {
          debugPrint('Ошибка выполнения действия ${action.type.name}: $e');
        }
      }
    }

    // Применяем обновления спецификации
    if (response.specificationSections != null) {
      _executor.applyTemplateUpdates(response.specificationSections!);
    }

    notifyListeners();
  }

  String formatSpecForOutput() {
    final spec = currentSpec;
    final buffer = StringBuffer();
    
    buffer.writeln('# ${spec.title}\n');
    
    for (final entry in spec.sections.entries) {
      if (entry.value.trim().isNotEmpty) {
        buffer.writeln('## ${_formatSectionName(entry.key)}\n');
        buffer.writeln('${entry.value}\n');
      }
    }
    
    buffer.writeln('---');
    buffer.writeln('*Версия: ${spec.metadata.version} | '
        'Статус: ${spec.metadata.status.name} | '
        'Прогресс: ${spec.metadata.progressPercentage.toInt()}% | '
        'Обновлено: ${_formatDateTime(spec.metadata.updatedAt)}*');
        
    if (spec.generationSteps.isNotEmpty) {
      buffer.writeln('\n### История генерации:');
      for (int i = 0; i < spec.generationSteps.length; i++) {
        buffer.writeln('${i + 1}. ${spec.generationSteps[i]}');
      }
    }
    
    return buffer.toString();
  }

  void resetSpecification() {
    _executor.updateSpec(TechnicalSpecification.empty());
    _currentUserMessage = null;
    _clearError();
    notifyListeners();
  }

  // Приватные методы
  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  String _formatSectionName(String name) {
    return name
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year} '
           '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
```

## 8. Новый AgentResultPanel

### 8.1 lib/widgets/main_screen/agent_result_panel.dart
```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/technical_specification.dart';

class AgentResultPanel extends StatelessWidget {
  final TechnicalSpecification specification;
  final bool isGenerating;
  final double? progress;
  final String? currentStep;
  final String? userMessage;
  final String? error;
  final VoidCallback onSave;

  const AgentResultPanel({
    super.key,
    required this.specification,
    this.isGenerating = false,
    this.progress,
    this.currentStep,
    this.userMessage,
    this.error,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Заголовок
        Row(
          children: [
            const Icon(Icons.smart_toy, size: 20, color: Colors.blue),
            const SizedBox(width: 8),
            const Text(
              'ИИ-агент генерирует ТЗ:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (!isGenerating && specification.sections.isNotEmpty)
              ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Сохранить'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Сообщение пользователю
        if (userMessage != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border.all(color: Colors.blue.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline, 
                     size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    userMessage!,
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Прогресс генерации
        if (isGenerating) ...[
          _buildGenerationProgress(),
          const SizedBox(height: 12),
        ],
        
        // Ошибка
        if (error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              border: Border.all(color: Colors.red.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, 
                     size: 16, color: Colors.red.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    error!,
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        // Основной контент
        Expanded(child: _buildSpecificationContent()),
      ],
    );
  }

  Widget _buildGenerationProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Агент работает...',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],

          ],
          if (progress != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress! / 100,
              backgroundColor: Colors.green.shade100,
              valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              '${progress!.toInt()}% завершено',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade700,
              ),
            ),
          ],
          if (currentStep != null) ...[
            const SizedBox(height: 8),
            Text(
              currentStep!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecificationContent() {
    if (specification.sections.isEmpty && !isGenerating) {
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
                Icons.smart_toy_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'ИИ-агент сгенерирует ТЗ пошагово',
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
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Метаданные спецификации
          _buildSpecificationHeader(),
          
          // Контент спецификации
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildSpecificationSections(),
            ),
          ),
          
          // История генерации
          if (specification.generationSteps.isNotEmpty)
            _buildGenerationHistory(),
        ],
      ),
    );
  }

  Widget _buildSpecificationHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  specification.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Статус: ${_getStatusDisplayName(specification.metadata.status)} | '
                  'Версия: ${specification.metadata.version}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (specification.metadata.progressPercentage > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getProgressColor(specification.metadata.progressPercentage),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${specification.metadata.progressPercentage.toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecificationSections() {
    if (specification.sections.isEmpty) {
      return const Text(
        'Разделы будут появляться по мере генерации...',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.grey,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: specification.sections.entries.map((entry) {
        return _buildSection(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget _buildSection(String key, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(6),
        color: Colors.grey.shade25,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.article_outlined,
                size: 16,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                _formatSectionName(key),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () => Clipboard.setData(ClipboardData(text: content)),
                tooltip: 'Копировать раздел',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'История генерации',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...specification.generationSteps.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _formatSectionName(String name) {
    return name
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _getStatusDisplayName(SpecStatus status) {
    switch (status) {
      case SpecStatus.draft:
        return 'Черновик';
      case SpecStatus.generating:
        return 'Генерируется';
      case SpecStatus.review:
        return 'На ревью';
      case SpecStatus.completed:
        return 'Завершено';
    }
  }

  Color _getProgressColor(double progress) {
    if (progress < 30) return Colors.red.shade400;
    if (progress < 70) return Colors.orange.shade400;
    return Colors.green.shade400;
  }
}
```

## 9. Обновления в LLMService

### 9.1 Новый метод parseAgentResponse
```dart
/// Парсит ответ агента из JSON
AgentResponse _parseAgentResponse(String rawResponse) {
  try {
    // Очищаем ответ от возможного мусора
    final cleanedResponse = _cleanJsonResponse(rawResponse);
    
    // Парсим JSON
    final Map<String, dynamic> jsonData = jsonDecode(cleanedResponse);
    
    // Валидируем обязательные поля агентского ответа
    _validateAgentResponse(jsonData);
    
    return AgentResponse.fromJson(jsonData);
  } catch (e) {
    throw Exception('Ошибка парсинга ответа агента: $e');
  }
}

/// Валидирует ответ агента
void _validateAgentResponse(Map<String, dynamic> response) {
  if (!response.containsKey('user_message') || 
      response['user_message'] is! String) {
    throw Exception('Отсутствует обязательное поле user_message');
  }

  if (response.containsKey('actions') && response['actions'] is! List) {
    throw Exception('Поле actions должно быть массивом');
  }

  if (response.containsKey('specification_sections') && 
      response['specification_sections'] is! Map) {
    throw Exception('Поле specification_sections должно быть объектом');
  }
}
```

## 10. Замена MainScreen на агентский режим

### 10.1 Полная замена логики MainScreen
```dart
class MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  // Существующие поля (частично сохраняются)
  final _rawRequirementsController = TextEditingController();
  final _changesController = TextEditingController();
  final List<GenerationHistory> _history = [];
  String? _errorMessage;
  OutputFormat _selectedFormat = OutputFormat.markdown;
  
  // ЗАМЕНЯЕМ классические поля на агентские
  late AgentController _agentController; // ОСНОВНОЙ контроллер
  // УДАЛЯЕМ: String _generatedTz, String _originalContent, bool _isGenerating

  @override
  void initState() {
    super.initState();
    
    // Существующий код...
    WidgetsBinding.instance.addObserver(this);
    _loadModels();
    
    // Инициализация агентского контроллера
    final llmService = Provider.of<LLMService>(context, listen: false);
    _agentController = AgentController(llmService: llmService);
    
    _rawRequirementsController.addListener(() {
      setState(() {});
    });
    _changesController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    // Существующий код...
    WidgetsBinding.instance.removeObserver(this);
    final sessionManager = ConfluenceSessionManager();
    sessionManager.triggerCleanup(fullCleanup: true);
    
    _rawRequirementsController.dispose();
    _changesController.dispose();
    _agentController.dispose();
    super.dispose();
  }

  // ЗАМЕНЯЕМ метод генерации на агентский
  Future<void> _generateTZ() async {
    if (_rawRequirementsController.text.trim().isEmpty) return;
    
    // ТОЛЬКО агентская генерация - классический режим УДАЛЕН
    await _generateAgentTZ();
  }

  // Основной метод агентской генерации (заменяет классический)
  Future<void> _generateAgentTZ() async {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final templateService = Provider.of<TemplateService>(context, listen: false);
    
    if (configService.config == null) {
      setState(() {
        _errorMessage = 'Конфигурация не найдена. Перейдите в настройки.';
      });
      return;
    }
    
    try {
      final activeTemplate = await templateService.getActiveTemplate();
      
      await _agentController.handleAgentRequest(
        rawRequirements: _rawRequirementsController.text,
        changes: _changesController.text.isNotEmpty ? _changesController.text : null,
        templateContent: activeTemplate?.content,
        format: _selectedFormat,
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  // УДАЛЯЕМ классический метод - больше не нужен
  
  // Основной метод сохранения (заменяет _saveFile)
  Future<void> _saveAgentFile() async {
    final content = _agentController.formatSpecForOutput();
    if (content.isEmpty) return;
    
    try {
      final filePath = await FileService.saveFileWithFormat(
        content: content,
        format: _selectedFormat,
      );
      
      if (filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Агентское ТЗ сохранено: $filePath'),
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

  // В build методе добавляем переключатель режима
  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        // Существующие shortcuts...
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          // Существующие actions...
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (ActivateIntent intent) {
              if (!
              if (!((_isGenerating && !_useAgentMode) || 
                    (_agentController.isProcessing && _useAgentMode)) && 
                  _rawRequirementsController.text.trim().isNotEmpty) {
                _generateTZ();
              }
              return null;
            },
          ),
          // Остальные actions...
        },
        child: Consumer<ConfigService>(
          builder: (context, configService, child) {
            if (configService.config == null) {
              return const SetupScreen();
            }
            
            return Consumer<LLMService>(
              builder: (context, llmService, child) {
                return ChangeNotifierProvider.value(
                  value: _agentController,
                  child: Scaffold(
                    appBar: AppBar(
                      // Существующий AppBar код...
                    ),
                    body: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Настройки модели
                          const ModelSettingsCard(),
                          const SizedBox(height: 16),
                          
                          // User guidance (теперь всегда для агентского режима)
                          if (_showGuidance && _agentController.currentSpec.sections.isEmpty) ...[
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
                                    generatedTz: _agentController.formatSpecForOutput(),
                                    history: _history,
                                    isGenerating: _agentController.isProcessing,
                                    errorMessage: _agentController.error,
                                    onGenerate: _generateTZ,
                                    onClear: _clearAll,
                                    onHistoryItemTap: (historyItem) {
                                      // История теперь восстанавливает агентскую спецификацию
                                      // TODO: Реализовать восстановление TechnicalSpecification из истории
                                    },
                                  ),
                                ),
                                
                                const SizedBox(width: 16),
                                
                                // Правая панель - только агентский результат
                                Expanded(
                                  flex: 1,
                                  child: _buildAgentResultPanel(),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          const AppFooter(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  // УДАЛЯЕМ переключатель режима - больше не нужен
  
  Widget _buildAgentResultPanel() {
    return Consumer<AgentController>(
      builder: (context, controller, child) {
        return AgentResultPanel(
          specification: controller.currentSpec,
          isGenerating: controller.isProcessing,
          progress: controller.progress,
          currentStep: controller.currentStep,
          userMessage: controller.currentUserMessage,
          error: controller.error,
          onSave: _saveAgentFile,
        );
      },
    );
  }

  // УДАЛЯЕМ классический результат панель - заменен на агентский
}
```

## 11. Дополнения к pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  # Существующие зависимости...
  provider: ^6.1.1
  http: ^1.1.0
  json_annotation: ^4.8.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  # Существующие dev_dependencies...
  build_runner: ^2.4.7
  json_serializable: ^6.7.1
```

## 12. План поэтапного внедрения

### 12.1 Этап 1: Создание моделей
1. Создать `lib/models/agent_response.dart`
2. Создать `lib/models/agent_action.dart`  
3. Обновить `lib/models/technical_specification.dart`
4. Запустить `dart run build_runner build`

### 12.2 Этап 2: Сервисы агента
1. Создать `lib/services/agent_executor.dart`
2. Создать `lib/services/agent_controller.dart`
3. Добавить методы в `LLMService`

### 12.3 Этап 3: UI компоненты
1. Создать `lib/widgets/main_screen/agent_result_panel.dart`
2. Обновить `MainScreen` с переключателем режимов
3. Интегрировать `AgentController`

### 12.4 Этап 4: Тестирование
1. Протестировать парсинг JSON ответов
2. Протестировать выполнение действий
3. Протестировать UI взаимодействия

## 13. Ключевые преимущества агентского подхода

### 13.1 Для пользователя
- **Интерактивность**: Видит процесс генерации в реальном времени
- **Прозрачность**: Понимает что делает ИИ на каждом шаге  
- **Контроль**: Может следить за прогрессом и качеством
- **Структурированность**: Получает хорошо организованное ТЗ

### 13.2 Для разработки
- **Модульность**: Четкое разделение действий и логики
- **Расширяемость**: Легко добавлять новые типы действий
- **Отладка**: Простое логирование каждого шага
- **Повторное использование**: Агент может работать с разными шаблонами

## 14. Обновление системного промпта

### 14.1 Ключевые изменения в промпте
1. **Структурированный JSON ответ** вместо простого текста
2. **Пошаговая генерация** вместо одного большого блока
3. **Метаинформация** о прогрессе и действиях
4. **Гибкость форматов** - поддержка Markdown и HTML

### 14.2 Пример агентского промпта
```
Ты ИИ-агент для создания технических заданий. Работаешь пошагово.

ОБЯЗАТЕЛЬНО возвращай ТОЛЬКО валидный JSON:
{
  "user_message": "Начинаю создание структуры ТЗ...",
  "actions": [
    {
      "type": "create_structure", 
      "progress_message": "Создаю базовую структуру разделов"
    }
  ],
  "specification_sections": {
    "overview": "Описание проекта...",
    "requirements": "Функциональные требования..."
  }
}
```

## 15. Заключение

Данная спецификация описывает **полную замену** классического подхода на агентский в приложении tee-zee-nator. 

### Ключевые изменения:
- **ПОЛНАЯ ЗАМЕНА** метода `generateTZ()` на агентский подход
- **ЗАМЕНА ResultPanel** на интерактивный `AgentResultPanel`
- **УДАЛЕНИЕ** переключателя режимов - только агентский режим
- **ЗАМЕНА** простого текстового вывода на структурированную `TechnicalSpecification`

### Основные преимущества нового подхода:
- **Пошаговая генерация** с показом прогресса в реальном времени
- **Структурированные данные** с метаинформацией
- **Интерактивный интерфейс** с историей действий агента
- **Расширяемая система действий** для будущих улучшений
- **Лучший UX** - пользователь видит что происходит

### План миграции:
1. **Этап 1**: Создание новых моделей данных
2. **Этап 2**: Замена LLMService методов  
3. **Этап 3**: Замена UI компонентов
4. **Этап 4**: Тестирование и отладка
5. **Этап 5**: Удаление старого кода

**ВАЖНО**: Старый классический подход будет **полностью удален** после успешного внедрения агентского.