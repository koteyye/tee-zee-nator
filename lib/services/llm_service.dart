import 'package:flutter/foundation.dart';
import '../models/app_config.dart';
import '../models/output_format.dart';
import '../exceptions/content_processing_exceptions.dart';
import 'llm_provider.dart';
import 'openai_provider.dart';
import 'llmops_provider.dart';
import 'cerebras_provider.dart';
import 'groq_provider.dart';
// import 'llm_streaming_provider.dart'; // kept for future conditional logic (currently unused explicitly)

class LLMService extends ChangeNotifier {
  LLMProvider? _provider;
  AppConfig? _config;
  
  // Системный промт для ревью шаблонов
  static const String templateReviewPrompt = '''
Ты главный методолог требований, тебе нужно провести ревью шаблона и выдать все замечания, вопросы (если они есть) и предложения по оптимизации шаблона.
Обязательно выдели есть ли КРИТИЧЕСКИЕ замечания к шаблону. При наличии критических замечаний введи в ответ текст "[CRITICAL_ALERT]"
''';
  
  LLMProvider? get provider => _provider;
  bool get isLoading => _provider?.isLoading ?? false;
  String? get error => _provider?.error;
  List<String> get availableModels => _provider?.availableModels ?? [];
  bool get hasModels => _provider?.hasModels ?? false;
  
  /// Инициализирует провайдер на основе конфигурации
  void initializeProvider(AppConfig config) {
    _config = config;
    
    print('LLMService: Initializing provider for: ${config.provider}');
    
    switch (config.provider) {
      case 'llmops':
        _provider = LLMOpsProvider(config);
        print('LLMService: Initialized LLMOpsProvider');
        break;
      case 'cerebras':
        _provider = CerebrasProvider(config);
        print('LLMService: Initialized CerebrasProvider with token: ${config.cerebrasToken?.substring(0, 10)}...');
        break;
      case 'groq':
        _provider = GroqProvider(config);
        print('LLMService: Initialized GroqProvider with token: ${config.groqToken?.substring(0, 10)}...');
        break;
      case 'openai':
      default:
        _provider = OpenAIProvider(config);
        print('LLMService: Initialized OpenAIProvider');
        break;
    }
    
    notifyListeners();
  }

  /// Public helper to build prompts (system + user) for streaming generation
  /// without performing the actual provider request. Reuses validation logic.
  /// Returns a map { 'system': ..., 'user': ... }.
  Map<String, String> buildGenerationPrompts({
    required String rawRequirements,
    String? changes,
    String? templateContent,
    OutputFormat format = OutputFormat.markdown,
  bool forStreaming = false,
  }) {
    _validateServiceState();

    final processedRawRequirements = processConfluenceContent(rawRequirements);
    final processedChanges = changes != null ? processConfluenceContent(changes) : null;
    validateGenerationParameters(processedRawRequirements, format, templateContent);

    if (forStreaming) {
      final streamingSystem = _buildStreamingSystemPrompt(
        templateContent: templateContent,
        format: format,
      );
      final streamingUser = _buildStreamingUserPrompt(
        requirements: processedRawRequirements,
        changes: processedChanges,
        format: format,
      );
      return {'system': streamingSystem, 'user': streamingUser};
    } else {
      // Build system prompt (legacy non-stream markers)
      late final String systemPrompt;
      switch (format) {
        case OutputFormat.markdown:
          systemPrompt = _buildMarkdownSystemPrompt(templateContent);
          break;
        case OutputFormat.confluence:
          systemPrompt = _buildConfluenceSystemPrompt(templateContent);
          break;
      }
      final userPrompt = _buildUserPrompt(processedRawRequirements, processedChanges, format);
      return {'system': systemPrompt, 'user': userPrompt};
    }
  }

  /// Streaming system prompt (NDJSON spec, no @@@ markers)
  String _buildStreamingSystemPrompt({
    required String? templateContent,
    required OutputFormat format,
  }) {
    final formatLabel = format == OutputFormat.markdown ? 'Markdown' : 'HTML (Confluence)';
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final templateHint = (templateContent == null || templateContent.trim().isEmpty)
        ? '(нет активного шаблона — структура на усмотрение модели)'
        : templateContent.trim();
    return '''Ты ИИ-помощник по созданию технического задания. Отвечай СТРОГО стримом NDJSON. Каждая строка — одиночный валидный JSON без текста вне JSON.

ФАЗЫ: init → plan → structure → draft_sections → refine → validate → finalize.

ФОРМАТ ВЫВОДА: $formatLabel (структура и заголовки внутри текста чанков).

ПРАВИЛА СТРИМА:
1. Первая строка: {"stream_type":"status","phase":"init","progress":0,"message":"Инициализация","ts":"<ISO8601>"}
2. Вторая строка: пустой контент: {"stream_type":"content","append":""}
3. Используй преимущественно append с небольшими логическими фрагментами. При крупной переработке допускается full.
4. НИКОГДА не используй ключи разделов — только текст.
5. Прогресс растёт монотонно. Финальная строка: {"stream_type":"final","progress":100,"message":"Готово","summary":"..."}
6. Без плейсхолдеров и заглушек.
7. Только один JSON на строку.

КОНТУР ШАБЛОНА (ориентир):
$templateHint

ЗАДАЧА: Постепенно сгенерировать цельное, отредактированное ТЗ высокого качества. Время запроса: $nowIso.''';
  }

  /// Streaming user prompt (no legacy markers)
  String _buildStreamingUserPrompt({
    required String requirements,
    required String? changes,
    required OutputFormat format,
  }) {
    final formatInstr = format == OutputFormat.markdown
        ? 'Форматируй в Markdown без HTML.'
        : 'Форматируй в допустимом Confluence Storage HTML.';
    final b = StringBuffer()
      ..writeln('Требования для ТЗ:\n\n$requirements');
    if (changes != null && changes.isNotEmpty) {
      b..writeln('\nИзменения / уточнения:\n\n$changes');
    }
    b..writeln('\n$formatInstr')
     ..writeln('Начинай поток немедленно, соблюдая протокол фаз.');
    return b.toString();
  }
  
  /// Тестирует соединение с провайдером
  Future<bool> testConnection() async {
    if (_provider == null) return false;
    
    final result = await _provider!.testConnection();
    notifyListeners();
    return result;
  }
  
  /// Получает список доступных моделей
  Future<List<String>> getModels() async {
    if (_provider == null) {
      print('LLMService: getModels called but provider is null');
      return [];
    }
    
    print('LLMService: Getting models for provider: ${_config?.provider}');
    
    final models = await _provider!.getModels();
    
    print('LLMService: Got ${models.length} models: $models');
    
    notifyListeners();
    return models;
  }
  
  /// Генерирует техническое задание
  Future<String> generateTZ({
    required String rawRequirements,
    String? changes,
    String? templateContent,
    OutputFormat format = OutputFormat.markdown,
  }) async {
    // Validate service state
    _validateServiceState();
    
    // Process Confluence content markers before validation
    final processedRawRequirements = processConfluenceContent(rawRequirements);
    final processedChanges = changes != null ? processConfluenceContent(changes) : null;
    
    // Validate input parameters with processed content
    validateGenerationParameters(processedRawRequirements, format, templateContent);
    
    // Generate format-specific system prompt
    String systemPrompt;
    try {
      switch (format) {
        case OutputFormat.markdown:
          systemPrompt = _buildMarkdownSystemPrompt(templateContent);
          break;
        case OutputFormat.confluence:
          systemPrompt = _buildConfluenceSystemPrompt(templateContent);
          break;
      }
    } catch (e) {
      throw LLMResponseValidationException(
        'Ошибка при создании системного промта для формата ${format.displayName}',
        '',
        recoveryAction: 'Проверьте шаблон и попробуйте другой формат',
        technicalDetails: e.toString(),
      );
    }
    
    // Формируем пользовательский промт с обработанным контентом
    String userPrompt;
    try {
      userPrompt = _buildUserPrompt(processedRawRequirements, processedChanges, format);
    } catch (e) {
      throw LLMResponseValidationException(
        'Ошибка при создании пользовательского промта',
        '',
        recoveryAction: 'Проверьте введенные требования и попробуйте снова',
        technicalDetails: e.toString(),
      );
    }
    
    // Send request with error handling
    String result;
    try {
      result = await _provider!.sendRequest(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        model: _config!.defaultModel,
      );
    } catch (e) {
      throw LLMResponseValidationException(
        'Ошибка при отправке запроса к AI провайдеру',
        '',
        recoveryAction: 'Проверьте подключение к интернету и настройки API. Попробуйте повторить запрос',
        technicalDetails: e.toString(),
      );
    }
    
    // Validate LLM response
    _validateLLMResponse(result, format);
    
    notifyListeners();
    return result;
  }
  

  /// Проводит ревью шаблона
  Future<String> reviewTemplate(String templateContent, String? modelId) async {
    if (_provider == null || _config == null) {
      throw Exception('LLM провайдер не инициализирован');
    }
    
    final result = await _provider!.sendRequest(
      systemPrompt: templateReviewPrompt,
      userPrompt: 'Проведи ревью следующего шаблона технического задания:\n\n$templateContent',
      model: modelId ?? _config!.reviewModel ?? _config!.defaultModel,
      temperature: 0.3, // Более низкая температура для аналитических задач
    );
    
    notifyListeners();
    return result;
  }
  
  /// Builds system prompt for Markdown format generation
  String _buildMarkdownSystemPrompt(String? templateContent) {
    if (templateContent == null || templateContent.isEmpty) {
      return '''Senior System Analyst. Генерируй ТЗ в Markdown формате.

Структура:
# Техническое задание
## 1. User Story
## 2. Контроль версионности
## 3. Проблематика
## 4. Критерии приемки

КРИТИЧЕСКИ ВАЖНО:
1. Используй только стандартный Markdown синтаксис
2. НЕ используй HTML теги или Confluence макросы
3. Обязательно оберни весь ответ в маркеры @@@START@@@ и @@@END@@@
4. НЕ добавляй никаких комментариев до, после или между маркерами
5. НЕ пиши ничего после маркера @@@END@@@

Пример формата ответа:
@@@START@@@
# Техническое задание
## 1. User Story
Содержимое в Markdown...
@@@END@@@''';
    }
    
    // Validate template content for Markdown compatibility
    if (templateContent.contains('<') && templateContent.contains('>')) {
      throw ArgumentError('Template content contains HTML tags which are not compatible with Markdown format');
    }
    
    return '''Senior System Analyst. Генерируй ТЗ в Markdown формате.

Шаблон:
$templateContent

КРИТИЧЕСКИ ВАЖНО:
1. Используй только стандартный Markdown синтаксис
2. НЕ используй HTML теги или Confluence макросы
3. Обязательно оберни весь ответ в маркеры @@@START@@@ и @@@END@@@
4. НЕ добавляй никаких комментариев до, после или между маркерами
5. НЕ пиши ничего после маркера @@@END@@@

Пример формата ответа:
@@@START@@@
# Техническое задание
Содержимое в Markdown согласно шаблону...
@@@END@@@''';
  }
  
  /// Builds system prompt for Confluence HTML format generation
  String _buildConfluenceSystemPrompt(String? templateContent) {
    if (templateContent == null || templateContent.isEmpty) {
      return '''Senior System Analyst. Генерируй ТЗ в HTML (Confluence Storage Format).

Структура:
<h1>Техническое задание</h1>
<h2>1. User Story</h2>
<h2>2. Контроль версионности</h2>
<h2>3. Проблематика</h2>
<h2>4. Критерии приемки</h2>

Обязательные теги: <h1>, <h2>, <p>, <ul>, <li>, <strong>, <table>
Макросы: <ac:structured-macro ac:name="info|warning|note|panel">

Ответ = ТОЛЬКО HTML без объяснений.''';
    }
    
    // Validate template content for HTML compatibility
    if (!templateContent.contains('<') || !templateContent.contains('>')) {
      // Template might be in Markdown format, warn but continue
      debugPrint('Warning: Template content appears to be in Markdown format but Confluence HTML format was requested');
    }
    
    return '''Senior System Analyst. Генерируй ТЗ в HTML (Confluence Storage Format).

Шаблон:
$templateContent

Обязательные теги: <h1>, <h2>, <p>, <ul>, <li>, <strong>, <table>
Макросы: <ac:structured-macro ac:name="info|warning|note|panel">

Ответ = ТОЛЬКО HTML без объяснений.''';
  }
  
  /// Builds user prompt based on requirements, changes, and format
  String _buildUserPrompt(String rawRequirements, String? changes, OutputFormat format) {
    if (rawRequirements.isEmpty) {
      throw ArgumentError('Raw requirements cannot be empty');
    }
    
    String formatInstruction;
    String startInstruction;
    
    switch (format) {
      case OutputFormat.markdown:
        formatInstruction = 'Markdown формате';
        startInstruction = 'ВАЖНО: Обязательно начни ответ с @@@START@@@ и закончи @@@END@@@!';
        break;
      case OutputFormat.confluence:
        formatInstruction = 'HTML формате';
        startInstruction = 'ВАЖНО: Верни только HTML-документ в формате Confluence Storage Format. Начинай с <h1>Техническое задание</h1>!';
        break;
    }
    
    String userPrompt = 'Создай техническое задание в $formatInstruction на основе следующих требований:\n\n$rawRequirements';
    
    if (changes != null && changes.isNotEmpty) {
      userPrompt += '\n\nУчти следующие изменения:\n\n$changes';
    }
    
    userPrompt += '\n\n$startInstruction';
    
    return userPrompt;
  }
  
  /// Validates service state before generation
  void _validateServiceState() {
    if (_provider == null || _config == null) {
      throw LLMResponseValidationException(
        'LLM провайдер не инициализирован',
        '',
        recoveryAction: 'Перейдите в настройки и настройте подключение к AI провайдеру',
        technicalDetails: 'LLM provider or config is null',
      );
    }
    
    if (!_provider!.hasModels) {
      throw LLMResponseValidationException(
        'Список моделей AI не загружен',
        '',
        recoveryAction: 'Проверьте подключение к интернету и настройки API, затем перезапустите приложение',
        technicalDetails: 'No models available from provider',
      );
    }
    
    if (_config!.defaultModel?.isEmpty ?? true) {
      throw LLMResponseValidationException(
        'Модель AI по умолчанию не выбрана',
        '',
        recoveryAction: 'Перейдите в настройки и выберите модель AI по умолчанию',
        technicalDetails: 'Default model is empty',
      );
    }
  }
  
  /// Validates generation parameters
  @visibleForTesting
  void validateGenerationParameters(String rawRequirements, OutputFormat format, String? templateContent) {
    if (rawRequirements.isEmpty) {
      throw LLMResponseValidationException(
        'Требования не могут быть пустыми',
        '',
        recoveryAction: 'Введите описание требований для генерации технического задания',
        technicalDetails: 'Raw requirements parameter is empty',
      );
    }
    
    if (rawRequirements.length < 10) {
      throw LLMResponseValidationException(
        'Требования слишком короткие для качественной генерации',
        '',
        recoveryAction: 'Добавьте больше деталей в описание требований (минимум 10 символов)',
        technicalDetails: 'Requirements too short: ${rawRequirements.length} characters',
      );
    }
    
    // Increased limit to account for processed Confluence content
    
    // Validate Confluence content markers are properly processed
    if (rawRequirements.contains('@conf-cnt') && rawRequirements.contains('@')) {
      final unprocessedMarkers = RegExp(r'@conf-cnt\s+.*?@').allMatches(rawRequirements);
      if (unprocessedMarkers.isNotEmpty) {
        throw LLMResponseValidationException(
          'Обнаружены необработанные маркеры Confluence контента',
          '',
          recoveryAction: 'Попробуйте повторить генерацию. Возможно, произошла ошибка при обработке ссылок Confluence',
          technicalDetails: 'Unprocessed @conf-cnt markers found: ${unprocessedMarkers.length}',
        );
      }
    }
    
    if (!OutputFormat.values.contains(format)) {
      throw LLMResponseValidationException(
        'Неподдерживаемый формат вывода: ${format.displayName}',
        '',
        recoveryAction: 'Выберите поддерживаемый формат (Markdown или Confluence)',
        technicalDetails: 'Invalid output format: $format',
      );
    }
    
    // Validate template content if provided
    if (templateContent != null && templateContent.isNotEmpty) {
      
      // Format-specific template validation
      if (format == OutputFormat.markdown && templateContent.contains('<') && templateContent.contains('>')) {
        throw LLMResponseValidationException(
          'Шаблон содержит HTML теги, но выбран формат Markdown',
          '',
          recoveryAction: 'Выберите формат Confluence или используйте шаблон в формате Markdown',
          technicalDetails: 'HTML tags found in template for Markdown format',
        );
      }
    }
  }
  
  /// Validates LLM response based on format
  void _validateLLMResponse(String response, OutputFormat format) {
    if (response.isEmpty) {
      throw LLMResponseValidationException(
        'AI вернул пустой ответ',
        response,
        recoveryAction: 'Попробуйте повторить генерацию с более детальными требованиями',
        technicalDetails: 'Empty response from LLM',
      );
    }
    
    if (response.length < 50) {
      throw LLMResponseValidationException(
        'AI вернул слишком короткий ответ',
        response,
        recoveryAction: 'Попробуйте повторить генерацию с более детальными требованиями или проверьте настройки модели',
        technicalDetails: 'Response too short: ${response.length} characters',
      );
    }
    
    // Format-specific validation
    switch (format) {
      case OutputFormat.markdown:
        _validateMarkdownResponse(response);
        break;
      case OutputFormat.confluence:
        _validateHtmlResponse(response);
        break;
    }
    
    // Check for common AI errors
    _validateResponseForCommonErrors(response);
  }
  
  /// Validates Markdown-specific response format
  void _validateMarkdownResponse(String response) {
    if (!response.contains('@@@START@@@')) {
      throw EscapeMarkerException(
        'Ответ AI не содержит начальный маркер @@@START@@@',
        response,
        hasStartMarker: false,
        hasEndMarker: response.contains('@@@END@@@'),
        hasContent: response.isNotEmpty,
        recoveryAction: 'Попробуйте повторить генерацию. AI не следует инструкциям по форматированию',
        technicalDetails: 'Missing @@@START@@@ marker in Markdown response',
      );
    }
    
    if (!response.contains('@@@END@@@')) {
      throw EscapeMarkerException(
        'Ответ AI не содержит конечный маркер @@@END@@@',
        response,
        hasStartMarker: response.contains('@@@START@@@'),
        hasEndMarker: false,
        hasContent: response.isNotEmpty,
        recoveryAction: 'Попробуйте повторить генерацию. Возможно, ответ был обрезан',
        technicalDetails: 'Missing @@@END@@@ marker in Markdown response',
      );
    }
    
    // Check marker order
    final startIndex = response.indexOf('@@@START@@@');
    final endIndex = response.indexOf('@@@END@@@');
    
    if (startIndex >= endIndex) {
      throw EscapeMarkerException(
        'Маркеры @@@START@@@ и @@@END@@@ расположены в неправильном порядке',
        response,
        hasStartMarker: true,
        hasEndMarker: true,
        hasContent: false,
        recoveryAction: 'Попробуйте повторить генерацию. AI нарушил порядок маркеров',
        technicalDetails: 'Start marker appears after end marker',
      );
    }
    
    // Check for content between markers
    final content = response.substring(startIndex + '@@@START@@@'.length, endIndex).trim();
    if (content.isEmpty) {
      throw EscapeMarkerException(
        'Контент между маркерами @@@START@@@ и @@@END@@@ пуст',
        response,
        hasStartMarker: true,
        hasEndMarker: true,
        hasContent: false,
        recoveryAction: 'Попробуйте повторить генерацию с более детальными требованиями',
        technicalDetails: 'Empty content between escape markers',
      );
    }
    
    // Check for HTML tags in Markdown response
    if (content.contains('<') && content.contains('>')) {
      final htmlTagPattern = RegExp(r'<(?!/?(?:code|pre|em|strong|a|img|br|hr)\b)[^>]+>', caseSensitive: false);
      if (htmlTagPattern.hasMatch(content)) {
        throw ContentFormatException(
          'AI вернул HTML теги в ответе для формата Markdown',
          'Markdown',
          'HTML',
          recoveryAction: 'Попробуйте повторить генерацию или выберите формат Confluence',
          technicalDetails: 'HTML tags found in Markdown response',
        );
      }
    }
  }
  
  /// Validates HTML-specific response format
  void _validateHtmlResponse(String response) {
    if (!response.contains('<') || !response.contains('>')) {
      throw ContentFormatException(
        'AI вернул ответ без HTML разметки для формата Confluence',
        'HTML',
        'Plain text',
        recoveryAction: 'Попробуйте повторить генерацию или выберите формат Markdown',
        technicalDetails: 'No HTML tags found in HTML response',
      );
    }
    
    if (!response.toLowerCase().contains('<h1')) {
      throw HtmlProcessingException(
        'AI не включил заголовок H1 в HTML ответ',
        recoveryAction: 'Попробуйте повторить генерацию. AI должен начинать с заголовка H1',
        technicalDetails: 'No H1 tag found in HTML response',
      );
    }
    
    // Check for Markdown syntax in HTML response
    final markdownPatterns = [
      RegExp(r'^#{1,6}\s+', multiLine: true), // Headers
      RegExp(r'\*\*[^*]+\*\*'), // Bold
      RegExp(r'\*[^*]+\*'), // Italic
      RegExp(r'^[-*+]\s+', multiLine: true), // Lists
      RegExp(r'```'), // Code blocks
    ];
    
    for (final pattern in markdownPatterns) {
      if (pattern.hasMatch(response)) {
        throw ContentFormatException(
          'AI вернул Markdown синтаксис в ответе для формата HTML',
          'HTML',
          'Markdown',
          recoveryAction: 'Попробуйте повторить генерацию или выберите формат Markdown',
          technicalDetails: 'Markdown syntax found in HTML response',
        );
      }
    }
  }
  
  /// Processes Confluence content markers in text
  /// 
  /// Replaces @conf-cnt markers with actual content for LLM processing
  /// Validates content format and prevents malformed requests
  @visibleForTesting
  String processConfluenceContent(String text) {
    if (text.isEmpty) return text;
    
    // Pattern to match @conf-cnt content@ markers
    final confluenceMarkerPattern = RegExp(
      r'@conf-cnt\s+(.*?)@',
      multiLine: true,
      dotAll: true,
    );
    
    // Check if text contains Confluence markers
    if (!confluenceMarkerPattern.hasMatch(text)) {
      return text; // No Confluence content to process
    }
    
    String processedText = text;
    final matches = confluenceMarkerPattern.allMatches(text).toList();
    
    // Process matches in reverse order to maintain string indices
    for (int i = matches.length - 1; i >= 0; i--) {
      final match = matches[i];
      final fullMatch = match.group(0)!;
      final content = match.group(1)?.trim() ?? '';
      
      // Validate content is not empty
      if (content.isEmpty) {
        debugPrint('Warning: Empty Confluence content marker found, removing: $fullMatch');
        processedText = processedText.replaceRange(match.start, match.end, '');
        continue;
      }
      
      // Validate content length to prevent token limit issues
      
      // Replace marker with processed content
      final processedContent = sanitizeConfluenceContent(content);
      processedText = processedText.replaceRange(match.start, match.end, processedContent);
    }
    
    return processedText;
  }
  
  /// Sanitizes Confluence content for safe LLM processing
  /// 
  /// Removes potentially problematic characters and formats content
  @visibleForTesting
  String sanitizeConfluenceContent(String content) {
    if (content.isEmpty) return content;
    
    // Remove any remaining HTML-like tags that might have been missed
    String sanitized = content.replaceAll(RegExp(r'<[^>]*>'), ' ');
    
    // Normalize whitespace
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Remove control characters that might cause issues
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    
    // Escape any remaining @ symbols to prevent marker confusion
    sanitized = sanitized.replaceAll('@', '(at)');
    
    // Add context wrapper to make it clear this is referenced content
    return '\n--- Информация из Confluence ---\n$sanitized\n--- Конец информации из Confluence ---\n';
  }

  /// Validates response for common AI errors
  void _validateResponseForCommonErrors(String response) {
    // Check for common AI refusal patterns
    final refusalPatterns = [
      'I cannot',
      'I\'m unable to',
      'I can\'t',
      'Sorry, I cannot',
      'I\'m not able to',
      'Я не могу',
      'Извините, я не могу',
      'К сожалению, я не могу',
    ];
    
    for (final pattern in refusalPatterns) {
      if (response.toLowerCase().contains(pattern.toLowerCase())) {
        throw LLMResponseValidationException(
          'AI отказался выполнить запрос',
          response,
          recoveryAction: 'Попробуйте переформулировать требования или использовать другую модель AI',
          technicalDetails: 'AI refusal pattern detected: $pattern',
        );
      }
    }
    
    // Check for incomplete responses
    final incompletePatterns = [
      '...',
      '[продолжение следует]',
      '[to be continued]',
      'и так далее',
      'etc.',
    ];
    
    for (final pattern in incompletePatterns) {
      if (response.toLowerCase().contains(pattern.toLowerCase())) {
        throw LLMResponseValidationException(
          'AI вернул неполный ответ',
          response,
          recoveryAction: 'Попробуйте повторить генерацию или увеличьте лимит токенов в настройках',
          technicalDetails: 'Incomplete response pattern detected: $pattern',
        );
      }
    }
    
    // Check for error messages from AI
    final errorPatterns = [
      'error',
      'ошибка',
      'failed',
      'не удалось',
      'exception',
      'исключение',
    ];
    
    for (final pattern in errorPatterns) {
      if (response.toLowerCase().contains(pattern.toLowerCase()) &&
          response.toLowerCase().contains('генерац')) {
        throw LLMResponseValidationException(
          'AI сообщил об ошибке при генерации',
          response,
          recoveryAction: 'Попробуйте повторить генерацию с другими параметрами',
          technicalDetails: 'Error pattern detected in response: $pattern',
        );
      }
    }
  }

}
