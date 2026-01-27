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

  String _resolveModel(String? model) {
    if (model != null && model.isNotEmpty && model != 'default') {
      return model;
    }
    final cfg = _config.llmopsModel;
    if (cfg != null && cfg.isNotEmpty && cfg != 'default') {
      return cfg;
    }
    if (_availableModels.isNotEmpty) {
      return _availableModels.first;
    }
    return 'llama3';
  }

  String _extractDetails(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic> && error['message'] != null) {
        return error['message'].toString();
      }
      if (data['message'] != null) return data['message'].toString();
    }
    if (data != null) return data.toString();
    return e.message ?? 'DioException';
  }
  
  @override
  List<String> get availableModels => _availableModels;
  
  @override
  bool get hasModels => _availableModels.isNotEmpty;
  
  @override
  bool get isLoading => _isLoading;
  
  @override
  String? get error => _error;
  
  String get _baseUrl => _config.llmopsBaseUrl ?? 'http://localhost:11434';
  
  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    if (_config.llmopsAuthHeader != null && _config.llmopsAuthHeader!.isNotEmpty) {
      String authHeader = _config.llmopsAuthHeader!;
      // Автоматически добавляем префикс "Bearer ", если его нет
      if (!authHeader.trim().startsWith('Bearer ')) {
        authHeader = 'Bearer $authHeader';
      }
      headers['Authorization'] = authHeader;
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
      
      Future<Response> postOnce(int tokens) {
        return _dio.post(
          '$_baseUrl/chat/completions',
          data: {
            'model': _resolveModel(model),
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            'max_tokens': tokens,
            'temperature': temperature ?? 0.7,
            'stream': false,
          },
          options: Options(headers: _headers),
        );
      }

      final initialTokens = maxTokens ?? 2000;
      Response response;
      try {
        response = await postOnce(initialTokens);
      } on DioException catch (e) {
        final details = _extractDetails(e);
        final status = e.response?.statusCode;
        final shouldRetry = status == 400 &&
            details.toLowerCase().contains('reduce the length') &&
            initialTokens > 1024;
        if (!shouldRetry) rethrow;
        response = await postOnce(1024);
      }
      
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
      if (e is DioException) {
        final status = e.response?.statusCode;
        final details = _extractDetails(e);
        _error = 'Ошибка при отправке запроса: ${status ?? 'no-status'} $details';
        throw Exception('LLMOps request failed (${status ?? 'no-status'}): $details');
      }
      _error = 'Ошибка при отправке запроса: $e';
      rethrow;
    } finally {
      _isLoading = false;
    }
  }
}
