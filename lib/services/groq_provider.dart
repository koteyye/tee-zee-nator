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
      
      final messages = [
        ChatMessage(role: 'system', content: systemPrompt),
        ChatMessage(role: 'user', content: userPrompt),
      ];
      
      final request = ChatRequest(
        model: model ?? _config.defaultModel ?? _availableModels.first,
        messages: messages,
        maxTokens: maxTokens ?? 4000,
        temperature: temperature ?? 0.7,
      );
      
      final response = await _dio.post(
        '$_baseUrl/chat/completions',
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_config.groqToken}',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        final chatResponse = ChatResponse.fromJson(response.data);
        if (chatResponse.choices.isNotEmpty) {
          return chatResponse.choices.first.message.content;
        }
      }
      
      throw Exception('Пустой ответ от Groq');
    } catch (e) {
      _error = 'Ошибка при отправке запроса: $e';
      rethrow;
    } finally {
      _isLoading = false;
    }
  }
}