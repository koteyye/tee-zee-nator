import 'package:flutter/foundation.dart';
import '../models/app_config.dart';
import 'llm_provider.dart';
import 'openai_provider.dart';
import 'llmops_provider.dart';

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
    
    switch (config.provider) {
      case 'llmops':
        _provider = LLMOpsProvider(config);
        break;
      case 'openai':
      default:
        _provider = OpenAIProvider(config);
        break;
    }
    
    notifyListeners();
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
    if (_provider == null) return [];
    
    final models = await _provider!.getModels();
    notifyListeners();
    return models;
  }
  
  /// Генерирует техническое задание
  Future<String> generateTZ({
    required String rawRequirements,
    String? changes,
    String? templateContent,
  }) async {
    if (_provider == null || _config == null) {
      throw Exception('LLM провайдер не инициализирован');
    }
    
    // Формируем системный промт для Confluence HTML
    String systemPrompt;
    if (templateContent != null && templateContent.isNotEmpty) {
      // Используем предоставленный шаблон
      systemPrompt = '''Senior System Analyst. Генерируй ТЗ в HTML (Confluence Storage Format).

Шаблон:
$templateContent

Обязательные теги: <h1>, <h2>, <p>, <ul>, <li>, <strong>, <table>
Макросы: <ac:structured-macro ac:name="info|warning|note|panel">

Ответ = ТОЛЬКО HTML без объяснений.''';
    } else {
      systemPrompt = '''Senior System Analyst. Генерируй ТЗ в HTML (Confluence Storage Format).

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
    
    // Формируем пользовательский промт
    String userPrompt = 'Создай техническое задание в HTML формате на основе следующих требований:\n\n$rawRequirements';
    
    if (changes != null && changes.isNotEmpty) {
      userPrompt += '\n\nУчти следующие изменения:\n\n$changes';
    }
    
    userPrompt += '\n\nВАЖНО: Верни только HTML-документ в формате Confluence Storage Format. Начинай с <h1>Техническое задание</h1>!';
    
    final result = await _provider!.sendRequest(
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      model: _config!.defaultModel,
    );
    
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
}
