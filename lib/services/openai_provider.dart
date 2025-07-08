import 'package:dio/dio.dart';
import '../models/openai_model.dart';
import '../models/chat_message.dart';
import '../models/app_config.dart';
import 'llm_provider.dart';

class OpenAIProvider implements LLMProvider {
  final Dio _dio = Dio();
  final AppConfig _config;
  
  List<String> _availableModels = [];
  bool _isLoading = false;
  String? _error;
  
  OpenAIProvider(this._config);
  
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
      
      final response = await _dio.get(
        '${_config.apiUrl}/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_config.apiToken}',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        final modelsResponse = OpenAIModelsResponse.fromJson(response.data);
        _availableModels = modelsResponse.data.map((model) => model.id).toList();
        _availableModels.sort();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Не удалось подключиться к OpenAI API: $e';
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
      
      final response = await _dio.get(
        '${_config.apiUrl}/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_config.apiToken}',
            'Content-Type': 'application/json',
          },
        ),
      );
      
      if (response.statusCode == 200) {
        final modelsResponse = OpenAIModelsResponse.fromJson(response.data);
        _availableModels = modelsResponse.data.map((model) => model.id).toList();
        _availableModels.sort();
        return _availableModels;
      }
      throw Exception('Failed to fetch models');
    } catch (e) {
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
        '${_config.apiUrl}/chat/completions',
        data: request.toJson(),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_config.apiToken}',
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
      
      throw Exception('Пустой ответ от OpenAI API');
    } catch (e) {
      _error = 'Ошибка при отправке запроса: $e';
      rethrow;
    } finally {
      _isLoading = false;
    }
  }
}
