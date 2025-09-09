import 'package:dio/dio.dart';
import '../models/openai_model.dart';
import '../models/chat_message.dart';
import '../models/app_config.dart';
import 'llm_provider.dart';

class CerebrasProvider implements LLMProvider {
  final Dio _dio = Dio();
  final AppConfig _config;
  
  // Fixed base URL for Cerebras AI
  static const String _baseUrl = 'https://api.cerebras.ai/v1';
  
  List<String> _availableModels = [];
  bool _isLoading = false;
  String? _error;
  
  CerebrasProvider(this._config);
  
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
      if (_config.cerebrasToken == null || _config.cerebrasToken!.isEmpty) {
        _error = 'Cerebras AI token is not configured';
        print('Cerebras: Token is null or empty');
        return false;
      }
      
      print('Cerebras: Testing connection to $_baseUrl with token: ${_config.cerebrasToken!.substring(0, 10)}...');
      
      final response = await _dio.get(
        '$_baseUrl/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_config.cerebrasToken}',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      print('Cerebras: Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final modelsResponse = OpenAIModelsResponse.fromJson(response.data);
        _availableModels = modelsResponse.data.map((model) => model.id).toList();
        _availableModels.sort();
        print('Cerebras: Loaded ${_availableModels.length} models: $_availableModels');
        return true;
      }
      return false;
    } catch (e) {
      print('Cerebras: Connection error: $e');
      _error = 'Не удалось подключиться к Cerebras AI: $e';
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
      if (_config.cerebrasToken == null || _config.cerebrasToken!.isEmpty) {
        _error = 'Cerebras AI token is not configured';
        print('Cerebras: getModels - Token is null or empty');
        return [];
      }
      
      print('Cerebras: Getting models from $_baseUrl with token: ${_config.cerebrasToken!.substring(0, 10)}...');
      
      final response = await _dio.get(
        '$_baseUrl/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_config.cerebrasToken}',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      print('Cerebras: getModels response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final modelsResponse = OpenAIModelsResponse.fromJson(response.data);
        _availableModels = modelsResponse.data.map((model) => model.id).toList();
        _availableModels.sort();
        print('Cerebras: getModels loaded ${_availableModels.length} models: $_availableModels');
        return _availableModels;
      }
      throw Exception('Failed to fetch models');
    } catch (e) {
      print('Cerebras: getModels error: $e');
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
            'Authorization': 'Bearer ${_config.cerebrasToken}',
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
      
      throw Exception('Пустой ответ от Cerebras AI');
    } catch (e) {
      _error = 'Ошибка при отправке запроса: $e';
      rethrow;
    } finally {
      _isLoading = false;
    }
  }
}