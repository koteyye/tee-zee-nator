import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import '../models/openai_model.dart';
import '../models/chat_message.dart';
import '../models/app_config.dart';
import '../models/llm_stream_chunk.dart';
import 'llm_provider.dart';
import 'llm_streaming_provider.dart';

class OpenAIProvider implements LLMProvider, LLMStreamingProvider {
  @override
  bool get supportsStreaming => true;
  final Dio _dio = Dio();
  final AppConfig _config;
  
  List<String> _availableModels = [];
  bool _isLoading = false;
  String? _error;
  
  OpenAIProvider(this._config);

  // Returns normalized base URL (no trailing slash, protocol + host/path as given)
  String get _baseUrl {
    var url = _config.apiUrl.trim();
    if (url.endsWith('/')) url = url.substring(0, url.length - 1);
    return url;
  }

  String _endpoint(String path) {
    if (path.startsWith('/')) path = path.substring(1);
    return '$_baseUrl/$path';
  }
  
  // Инициализируем таймауты (во избежание вечной загрузки моделей при сетевых проблемах)
  void _ensureTimeouts() {
    // Устанавливаем только один раз
    if (_dio.options.connectTimeout == null || _dio.options.connectTimeout!.inMilliseconds > 15000) {
      _dio.options = _dio.options.copyWith(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
      );
    }
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
  _ensureTimeouts();
    try {
      _isLoading = true;
      _error = null;
      
      final response = await _dio.get(
        _endpoint('models'),
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
  _ensureTimeouts();
    try {
      _isLoading = true;
      _error = null;
      
      final response = await _dio.get(
        _endpoint('models'),
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
        _endpoint('chat/completions'),
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

  // ---- Streaming implementation -------------------------------------------------

  @override
  Stream<LLMStreamChunk> streamChat({
    required String systemPrompt,
    required String userPrompt,
    String? model,
    int? maxTokens,
    double? temperature,
    CancelToken? cancelToken,
  }) async* {
    // Compose messages like in sendRequest
    final messages = [
      ChatMessage(role: 'system', content: systemPrompt),
      ChatMessage(role: 'user', content: userPrompt),
    ];

    final requestMap = {
      'model': model ?? _config.defaultModel ?? (_availableModels.isNotEmpty ? _availableModels.first : 'gpt-4o'),
      'messages': messages.map((m) => m.toJson()).toList(),
      'temperature': temperature ?? 0.7,
      if (maxTokens != null) 'max_tokens': maxTokens,
      'stream': true,
    };

    Response<ResponseBody> response;
    Future<Response<ResponseBody>> _doStreamCall(String path) {
      return _dio.post<ResponseBody>(
        _endpoint(path),
        data: jsonEncode(requestMap),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_config.apiToken}',
            'Content-Type': 'application/json',
            // Helps some reverse proxies / compatible servers route SSE properly
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
          },
          responseType: ResponseType.stream,
        ),
        cancelToken: cancelToken,
      );
    }
    try {
      response = await _doStreamCall('chat/completions');
    } on DioException catch (e) {
      // Retry heuristics for 404 (common with mis-specified base URL or missing /v1)
      final status = e.response?.statusCode;
      if (status == 404) {
        // Heuristic 1: If base URL already ends with /v1, try without /v1 (some gateways duplicate it)
        if (_baseUrl.endsWith('/v1')) {
          final alt = _baseUrl.substring(0, _baseUrl.length - 3); // remove '/v1'
          try {
            response = await _dio.post<ResponseBody>(
              '$alt/chat/completions',
              data: jsonEncode(requestMap),
              options: Options(
                headers: {
                  'Authorization': 'Bearer ${_config.apiToken}',
                  'Content-Type': 'application/json',
                  'Accept': 'text/event-stream',
                  'Cache-Control': 'no-cache',
                },
                responseType: ResponseType.stream,
              ),
              cancelToken: cancelToken,
            );
          } catch (e2) {
            yield LLMStreamChunkError('HTTP 404 streaming (alt base) : $e2');
            return;
          }
        } else {
          // Heuristic 2: If base missing /v1, try adding it
            try {
              response = await _dio.post<ResponseBody>(
                '${_baseUrl}/v1/chat/completions',
                data: jsonEncode(requestMap),
                options: Options(
                  headers: {
                    'Authorization': 'Bearer ${_config.apiToken}',
                    'Content-Type': 'application/json',
                    'Accept': 'text/event-stream',
                    'Cache-Control': 'no-cache',
                  },
                  responseType: ResponseType.stream,
                ),
                cancelToken: cancelToken,
              );
            } catch (e3) {
              yield LLMStreamChunkError('HTTP 404 streaming (v1 retry) : $e3');
              return;
            }
        }
      } else {
        yield LLMStreamChunkError('HTTP error initiating stream: $e');
        return;
      }
    } catch (e) {
      yield LLMStreamChunkError('HTTP error initiating stream: $e');
      return;
    }

    // The stream is SSE style: lines starting with 'data: '
    final stream = response.data!.stream
        .transform(StreamTransformer<Uint8List, String>.fromHandlers(handleData: (data, sink) {
          sink.add(utf8.decode(data));
        }))
        .transform(const LineSplitter());

    final StringBuffer assembled = StringBuffer();
    await for (final rawLine in stream) {
      final line = rawLine.trim();
      if (line.isEmpty) continue; // keep-alive newline
      if (!line.startsWith('data:')) continue; // ignore any non-data lines
      final data = line.substring(5).trim();
      if (data == '[DONE]') {
        yield LLMStreamChunkFinal(full: assembled.isNotEmpty ? assembled.toString() : null, finishReason: 'stop');
        break;
      }
      try {
        final jsonObj = jsonDecode(data) as Map<String, dynamic>;
        final choices = jsonObj['choices'];
        if (choices is List && choices.isNotEmpty) {
          final first = choices.first as Map<String, dynamic>;
          final delta = first['delta'] as Map<String, dynamic>?;
          final finish = first['finish_reason'];
          if (delta != null && delta.containsKey('content')) {
            final piece = delta['content']?.toString() ?? '';
            if (piece.isNotEmpty) {
              assembled.write(piece);
              yield LLMStreamChunkDelta(piece);
            }
          }
          if (finish != null && finish != 'null') {
            // Some APIs send finish_reason early; close.
            yield LLMStreamChunkFinal(full: assembled.toString(), finishReason: finish.toString());
            break;
          }
        }
      } catch (e) {
        yield LLMStreamChunkError('Stream parse error: $e');
        break;
      }
    }
  }
}
