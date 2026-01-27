import 'package:dio/dio.dart';
import '../models/openai_model.dart';
import '../models/chat_message.dart';
import '../models/app_config.dart';
import 'llm_provider.dart';

class GroqProvider implements LLMProvider {
  final Dio _dio = Dio();
  final AppConfig _config;
  
  // Fixed base URL for Groq
  static const String _baseUrl = 'https://api.groq.com/openai/v1';
  
  List<String> _availableModels = [];
  bool _isLoading = false;
  String? _error;
  
  GroqProvider(this._config);

  String _resolveModel(String? model) {
    if (model != null && model.isNotEmpty && model != 'default') {
      return model;
    }
    final cfg = _config.defaultModel;
    if (cfg != null && cfg.isNotEmpty && cfg != 'default') {
      return cfg;
    }
    if (_availableModels.isNotEmpty) {
      return _availableModels.first;
    }
    throw Exception('No available models for Groq');
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
  
  @override
  Future<bool> testConnection() async {
    try {
      _isLoading = true;
      _error = null;
      
      // Проверяем наличие токена
      if (_config.groqToken == null || _config.groqToken!.isEmpty) {
        _error = 'Groq token is not configured';
        print('Groq: Token is null or empty');
        return false;
      }
      
      print('Groq: Testing connection to $_baseUrl with token: ${_config.groqToken!.substring(0, 10)}...');
      
      final response = await _dio.get(
        '$_baseUrl/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_config.groqToken}',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      print('Groq: Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final modelsResponse = OpenAIModelsResponse.fromJson(response.data);
        _availableModels = modelsResponse.data.map((model) => model.id).toList();
        _availableModels.sort();
        print('Groq: Loaded ${_availableModels.length} models: $_availableModels');
        return true;
      }
      return false;
    } catch (e) {
      print('Groq: Connection error: $e');
      _error = 'Не удалось подключиться к Groq: $e';
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
      
      // Проверяем наличие токена
      if (_config.groqToken == null || _config.groqToken!.isEmpty) {
        _error = 'Groq token is not configured';
        print('Groq: getModels - Token is null or empty');
        return [];
      }
      
      print('Groq: Getting models from $_baseUrl with token: ${_config.groqToken!.substring(0, 10)}...');
      
      final response = await _dio.get(
        '$_baseUrl/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_config.groqToken}',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      print('Groq: getModels response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final modelsResponse = OpenAIModelsResponse.fromJson(response.data);
        _availableModels = modelsResponse.data.map((model) => model.id).toList();
        _availableModels.sort();
        print('Groq: getModels loaded ${_availableModels.length} models: $_availableModels');
        return _availableModels;
      }
      throw Exception('Failed to fetch models');
    } catch (e) {
      print('Groq: getModels error: $e');
      _error = 'Ошибка при получении моделей: $e';
      return [];
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

      if (_config.groqToken == null || _config.groqToken!.isEmpty) {
        _error = 'Groq token is not configured';
        throw Exception('Groq token is not configured');
      }
      
      final messages = [
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'user', content: userPrompt),
      ];

      Future<Response> postOnce(int tokens) {
        final request = ChatRequest(
          model: _resolveModel(model),
          messages: messages,
          maxTokens: tokens,
          temperature: temperature ?? 0.7,
        );
        return _dio.post(
          '$_baseUrl/chat/completions',
          data: request.toJson(),
          options: Options(
            headers: {
              'Authorization': 'Bearer ${_config.groqToken}',
              'Content-Type': 'application/json',
            },
          ),
        );
      }

      final initialTokens = maxTokens ?? 4000;
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
        final chatResponse = ChatResponse.fromJson(response.data);
        if (chatResponse.choices.isNotEmpty) {
          return chatResponse.choices.first.message.content;
        }
      }
      
      throw Exception('Пустой ответ от Groq');
    } catch (e) {
      if (e is DioException) {
        final status = e.response?.statusCode;
        final details = _extractDetails(e);
        _error = 'Ошибка при отправке запроса: ${status ?? 'no-status'} $details';
        throw Exception('Groq request failed (${status ?? 'no-status'}): $details');
      }
      _error = 'Ошибка при отправке запроса: $e';
      rethrow;
    } finally {
      _isLoading = false;
    }
  }
}