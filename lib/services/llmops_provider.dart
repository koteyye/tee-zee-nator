import 'package:dio/dio.dart';
import '../models/app_config.dart';
import 'llm_provider.dart';

class LLMOpsProvider implements LLMProvider {
  final Dio _dio = Dio();
  final AppConfig _config;
  
  List<String> _availableModels = [];
  bool _isLoading = false;
  String? _error;
  
  LLMOpsProvider(this._config);
  
  @override
  List<String> get availableModels => _availableModels;
  
  @override
  bool get hasModels => _availableModels.isNotEmpty;
  
  @override
  bool get isLoading => _isLoading;
  
  @override
  String? get error => _error;
  
  String get _baseUrl => _config.llmopsBaseUrl ?? 'http://localhost:11434';
  
  String get _model => _config.llmopsModel ?? 'llama3';
  
  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (_config.llmopsAuthHeader != null && _config.llmopsAuthHeader!.isNotEmpty) {
      headers['Authorization'] = _config.llmopsAuthHeader!;
    }
    
    return headers;
  }
  
  @override
  Future<bool> testConnection() async {
    try {
      _isLoading = true;
      _error = null;
      
      // Тестируем соединение через /models endpoint
      final response = await _dio.get(
        '$_baseUrl/models',
        options: Options(headers: _headers),
      );
      
      if (response.statusCode == 200) {
        // Загружаем доступные модели
        await getModels();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Не удалось подключиться к LLMOps: $e';
      return false;
    } finally {
      _isLoading = false;
    }
  }
  
  @override
  Future<List<String>> getModels() async {
    try {
      _isLoading = true;
      _error = null;
      
      // Используем endpoint /models
      final response = await _dio.get(
        '$_baseUrl/models',
        options: Options(headers: _headers),
      );
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['data'] != null) {
          // Парсим список моделей в OpenAI формате
          final models = (responseData['data'] as List)
              .map((model) => model['id'] as String)
              .toList();
          _availableModels = models;
          return models;
        }
      }
      
      // Если эндпоинт недоступен, используем модель из конфигурации
      if (_config.llmopsModel != null) {
        _availableModels = [_config.llmopsModel!];
      } else {
        _availableModels = ['llama3']; // Дефолтная модель
      }
      
      return _availableModels;
    } catch (e) {
      print('Ошибка при получении моделей: $e');
      // Fallback к модели из конфигурации
      if (_config.llmopsModel != null) {
        _availableModels = [_config.llmopsModel!];
      } else {
        _availableModels = ['llama3'];
      }
      return _availableModels;
    } finally {
      _isLoading = false;
    }
  }
  
  @override
  Future<String> sendRequest({
    required String systemPrompt,
    required String userPrompt,
    String? model,
    int? maxTokens,
    double? temperature,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      
      // Используем endpoint /chat/completions
      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        data: {
          'model': model ?? _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'max_tokens': maxTokens ?? 2000,
          'temperature': temperature ?? 0.7,
          'stream': false,
        },
        options: Options(headers: _headers),
      );
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['choices'] != null && 
            responseData['choices'].isNotEmpty &&
            responseData['choices'][0]['message'] != null) {
          return responseData['choices'][0]['message']['content'] as String;
        }
      }
      
      throw Exception('Пустой ответ от LLMOps API');
    } catch (e) {
      _error = 'Ошибка при отправке запроса: $e';
      rethrow;
    } finally {
      _isLoading = false;
    }
  }
}
