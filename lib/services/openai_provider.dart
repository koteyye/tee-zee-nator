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
    try {
      response = await _dio.post<ResponseBody>(
        '${_config.apiUrl}/chat/completions',
        data: jsonEncode(requestMap),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_config.apiToken}',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.stream,
        ),
        cancelToken: cancelToken,
      );
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
