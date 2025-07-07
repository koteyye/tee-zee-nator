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
      
      // Тестируем соединение простым запросом
      final response = await _dio.post(
        '$_baseUrl/generate',
        data: {
          'model': _model,
          'prompt': 'test',
          'stream': false,
        },
        options: Options(headers: _headers),
      );
      
      if (response.statusCode == 200 && response.data['response'] != null) {
        // Если есть модель в конфигурации, добавляем её в список
        if (_config.llmopsModel != null) {
          _availableModels = [_config.llmopsModel!];
        }
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
      
      // LLMOps может не иметь endpoint для получения списка моделей
      // Возвращаем модель из конфигурации или дефолтную
      if (_config.llmopsModel != null) {
        _availableModels = [_config.llmopsModel!];
      } else {
        _availableModels = ['llama3']; // Дефолтная модель
      }
      
      return _availableModels;
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
      
      // Объединяем системный и пользовательский промты
      final combinedPrompt = '$systemPrompt\n\n$userPrompt';
      
      final response = await _dio.post(
        '$_baseUrl/generate',
        data: {
          'model': model ?? _model,
          'prompt': combinedPrompt,
          'stream': false,
        },
        options: Options(headers: _headers),
      );
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData['response'] != null) {
          return responseData['response'] as String;
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
