import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/gen_api_models.dart';
import '../models/music_generation_session.dart';
import '../exceptions/content_processing_exceptions.dart';
import 'music_generation_interface.dart';

class GenApiService implements IMusicGenerationService {
  static const String _baseUrl = 'https://api.gen-api.ru/api/v1';
  static const String _sunoEndpoint = '/networks/suno';
  static const String _userEndpoint = '/user';
  static const String _requestStatusEndpoint = '/request/get';

  final String apiKey;
  late final http.Client _httpClient;

  GenApiService({required this.apiKey}) {
    _httpClient = http.Client();
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Authorization': 'Bearer $apiKey',
  };

  Future<GenApiUserInfo> getUserInfo() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl$_userEndpoint'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return GenApiUserInfo.fromJson(json);
      } else if (response.statusCode == 401) {
        throw MusicGenerationException('Неверный API ключ для gen-api.ru');
      } else {
        throw MusicGenerationException('Ошибка получения информации о пользователе: ${response.statusCode}');
      }
    } catch (e) {
      if (e is MusicGenerationException) rethrow;
      throw MusicGenerationException('Ошибка соединения с gen-api.ru: $e');
    }
  }

  Future<GenApiResponse> generateMusic({
    required String title,
    required String tags,
    required String prompt,
    String? model,
    bool? translateInput,
  }) async {
    try {
      final request = GenApiRequest(
        title: title,
        tags: tags,
        prompt: prompt,
        model: model,
        translateInput: translateInput,
      );

      final response = await _httpClient.post(
        Uri.parse('$_baseUrl$_sunoEndpoint'),
        headers: _headers,
        body: jsonEncode(request.toJson()),
      );

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 202) {
        try {
          return GenApiResponse.fromJson(json);
        } catch (e) {
          debugPrint('Ошибка парсинга GenApiResponse: $e');
          debugPrint('JSON ответа: $json');
          rethrow;
        }
      } else if (response.statusCode == 402) {
        throw InsufficientFundsException('Недостаточно средств на балансе gen-api.ru');
      } else if (response.statusCode == 401) {
        throw ApiAuthenticationException('Неверный API ключ для gen-api.ru');
      } else if (response.statusCode == 419) {
        throw ApiRateLimitException('Превышен лимит частоты запросов к gen-api.ru');
      } else if (response.statusCode >= 500) {
        throw ApiServerException('Ошибка сервера gen-api.ru', statusCode: response.statusCode);
      } else {
        final error = json['error'] as String? ?? 'Неизвестная ошибка';
        throw MusicGenerationException('Ошибка генерации музыки: $error');
      }
    } catch (e) {
      if (e is MusicGenerationException) rethrow;
      throw MusicGenerationException('Ошибка соединения с gen-api.ru: $e');
    }
  }

  Future<GenApiResponse> getRequestStatus(String requestId) async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl$_requestStatusEndpoint/$requestId'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        try {
          return GenApiResponse.fromJson(json);
        } catch (e) {
          debugPrint('Ошибка парсинга GenApiResponse (getRequestStatus): $e');
          debugPrint('JSON ответа: $json');
          rethrow;
        }
      } else {
        throw MusicGenerationException('Ошибка получения статуса запроса: ${response.statusCode}');
      }
    } catch (e) {
      if (e is MusicGenerationException) rethrow;
      throw MusicGenerationException('Ошибка получения статуса запроса: $e');
    }
  }

  Future<List<String>> downloadMusicFiles({
    required List<String> audioUrls,
    required String sessionId,
  }) async {
    final filePaths = <String>[];

    try {
      final downloadsDir = await getDownloadsDirectory();
      final targetDir = downloadsDir ?? await getApplicationSupportDirectory();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sessionHash = _generateShortHash(sessionId);

      for (int i = 0; i < audioUrls.length; i++) {
        final audioUrl = audioUrls[i];

        try {
          final response = await _httpClient.get(Uri.parse(audioUrl));

          if (response.statusCode != 200) {
            throw MusicDownloadException(
              'Ошибка загрузки аудиофайла ${i + 1}: ${response.statusCode}',
              audioUrl: audioUrl,
            );
          }

          final fileName = 'music_${sessionHash}_${i + 1}_$timestamp.mp3';
          final file = File(path.join(targetDir.path, fileName));
          await file.writeAsBytes(response.bodyBytes);

          filePaths.add(file.path);
        } catch (e) {
          if (e is MusicDownloadException) rethrow;
          throw MusicDownloadException(
            'Ошибка сохранения аудиофайла ${i + 1}: $e',
            audioUrl: audioUrl,
          );
        }
      }

      return filePaths;
    } catch (e) {
      if (e is MusicGenerationException) rethrow;
      throw MusicDownloadException('Ошибка загрузки музыкальных файлов: $e');
    }
  }

  String _generateShortHash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8);
  }

  String generateSessionId(String requirements) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final input = '$requirements$timestamp';
    return _generateShortHash(input);
  }

  String generateRequirementsHash(String requirements) {
    return _generateShortHash(requirements);
  }

  void dispose() {
    _httpClient.close();
  }
}