import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import '../models/openai_model.dart';
import '../models/chat_message.dart';
import '../models/app_config.dart';

class OpenAIService extends ChangeNotifier {
  final Dio _dio = Dio();
  List<OpenAIModel> _availableModels = [];
  bool _isLoading = false;
  String? _error;
  
  List<OpenAIModel> get availableModels => _availableModels;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }
  
  Future<bool> testConnection(String apiUrl, String apiToken) async {
    try {
      _setLoading(true);
      _setError(null);
      
      final response = await _dio.get(
        '$apiUrl/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiToken',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        final modelsResponse = OpenAIModelsResponse.fromJson(response.data);
        
        // Отладочная информация
        print('Всего моделей получено: ${modelsResponse.data.length}');
        for (var model in modelsResponse.data) {
          print('Модель: ${model.id}');
        }
        
        // Берем все доступные модели и сортируем по имени
        _availableModels = modelsResponse.data.toList();
        _availableModels.sort((a, b) => a.id.compareTo(b.id));
        
        print('Доступных моделей: ${_availableModels.length}');
        return true;
      }
      return false;
    } catch (e) {
      print('Ошибка при тестировании соединения: $e');
      _setError('Не удалось подключиться к OpenAI API: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  Future<List<OpenAIModel>> getModels(AppConfig config) async {
    try {
      _setLoading(true);
      _setError(null);
      
      final response = await _dio.get(
        '${config.apiUrl}/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${config.apiToken}',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        final modelsResponse = OpenAIModelsResponse.fromJson(response.data);
        
        // Берем все доступные модели и сортируем по имени
        _availableModels = modelsResponse.data.toList();
        _availableModels.sort((a, b) => a.id.compareTo(b.id));
        
        return _availableModels;
      }
      throw Exception('Failed to fetch models');
    } catch (e) {
      _setError('Ошибка при получении моделей: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }
  
  Future<String> generateTZ({
    required AppConfig config,
    required String rawRequirements,
    String? changes,
    bool useBaseTemplate = true,
  }) async {
    try {
      _setLoading(true);
      _setError(null);
      
      // Всегда используем Confluence HTML формат
      return _generateConfluenceTZ(
        config: config,
        rawRequirements: rawRequirements,
        changes: changes,
        useBaseTemplate: useBaseTemplate,
      );
    } catch (e) {
      _setError('Ошибка при генерации ТЗ: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<String> _generateConfluenceTZ({
    required AppConfig config,
    required String rawRequirements,
    String? changes,
    bool useBaseTemplate = true,
  }) async {
    // Формируем системный промт для Confluence HTML
    String systemPrompt;
    if (useBaseTemplate) {
      // Загружаем HTML шаблон ТЗ
      final template = await rootBundle.loadString('assets/tz_pattern_confluence.html');
      systemPrompt = '''Senior System Analyst. Генерируй ТЗ в HTML (Confluence Storage Format).

Шаблон:
$template

Обязательные теги: <h1>, <h2>, <p>, <ul>, <li>, <strong>, <table>
Макросы: <ac:structured-macro ac:name="info|warning|note|panel">

Структура:
<h1>Техническое задание</h1>
<h2>1. User Story</h2>
<h2>2. Контроль версионности</h2>
<h2>3. Проблематика</h2>
<h2>4. Критерии приемки</h2>

Ответ = ТОЛЬКО HTML без объяснений.''';
    } else {
      systemPrompt = '''Senior System Analyst. Генерируй ТЗ в HTML (Confluence Storage Format).

Обязательные теги: <h1>, <h2>, <p>, <ul>, <li>, <strong>, <table>
Макросы: <ac:structured-macro ac:name="info|warning|note|panel">

Структура:
<h1>Техническое задание</h1>
<h2>1. User Story</h2>
<h2>2. Критерии приемки</h2>
<h2>3. Функциональные требования</h2>

Ответ = ТОЛЬКО HTML без объяснений.''';
    }
    
    // Формируем пользовательский промт
    String userPrompt = 'Создай техническое задание в HTML формате на основе следующих требований:\n\n$rawRequirements';
    
    if (changes != null && changes.isNotEmpty) {
      userPrompt += '\n\nУчти следующие изменения:\n\n$changes';
    }
    
    userPrompt += '\n\nВАЖНО: Верни только HTML-документ в формате Confluence Storage Format. Начинай с <h1>Техническое задание</h1>!';
    
    return _sendChatRequest(config, systemPrompt, userPrompt);
  }

  Future<String> _sendChatRequest(AppConfig config, String systemPrompt, String userPrompt) async {
    final messages = [
      ChatMessage(role: 'system', content: systemPrompt),
      ChatMessage(role: 'user', content: userPrompt),
    ];
    
    print('=== ОТЛАДКА ЗАПРОСА ===');
    print('Формат: Confluence HTML');
    print('Системный промт:');
    print(systemPrompt);
    print('\nПользовательский промт:');
    print(userPrompt);
    print('=== КОНЕЦ ОТЛАДКИ ЗАПРОСА ===');
    
    final request = ChatRequest(
      model: config.selectedModel ?? _availableModels.first.id,
      messages: messages,
      maxTokens: 4000,
      temperature: 0.7,
    );
    
    print('Используемая модель: ${request.model}');
    print('Количество сообщений: ${messages.length}');
    
    final response = await _dio.post(
      '${config.apiUrl}/chat/completions',
      data: request.toJson(),
      options: Options(
        headers: {
          'Authorization': 'Bearer ${config.apiToken}',
          'Content-Type': 'application/json',
        },
      ),
    );
    
    if (response.statusCode == 200) {
      final chatResponse = ChatResponse.fromJson(response.data);
      if (chatResponse.choices.isNotEmpty) {
        final responseContent = chatResponse.choices.first.message.content;
        
        print('=== ОТЛАДКА ОТВЕТА ===');
        print('Статус код: ${response.statusCode}');
        print('Количество вариантов ответа: ${chatResponse.choices.length}');
        print('Ответ модели:');
        print(responseContent);
        print('=== КОНЕЦ ОТЛАДКИ ОТВЕТА ===');
        
        return responseContent;
      }
    }
    
    throw Exception('Пустой ответ от API');
  }
}
