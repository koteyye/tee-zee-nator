import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../models/gen_api_models.dart';
import '../exceptions/content_processing_exceptions.dart';
import 'music_generation_interface.dart';

class MockGenApiService implements IMusicGenerationService {
  final String apiKey;
  final Map<String, GenApiResponse> _mockRequests = {};
  final Random _random = Random();

  MockGenApiService({required this.apiKey});

  @override
  Future<GenApiUserInfo> getUserInfo() async {
    // Симулируем небольшую задержку
    await Future.delayed(const Duration(milliseconds: 300));

    // Если API ключ пустой или неправильный, кидаем ошибку
    if (apiKey.isEmpty || apiKey.length < 10) {
      throw MusicGenerationException('Неверный API ключ для gen-api.ru');
    }

    return const GenApiUserInfo(
      balance: '999.99',
      currency: 'RUB',
      status: 'active',
    );
  }

  @override
  Future<GenApiResponse> generateMusic({
    required String title,
    required String tags,
    required String prompt,
    String? model,
    bool? translateInput,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final requestId = 'mock_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}';

    // Создаем мок-ответ для будущих запросов статуса
    _mockRequests[requestId] = GenApiResponse(
      requestId: requestId,
      status: 'waiting',
      progress: 0,
      input: {
        'title': title,
        'tags': tags,
        'prompt': prompt,
        'model': model,
        'translate_input': translateInput,
      },
    );

    // Симулируем процесс генерации через 3 секунды
    Timer(const Duration(seconds: 3), () {
      _mockRequests[requestId] = GenApiResponse(
        requestId: requestId,
        status: 'success',
        progress: 100,
        result: [
          {'audio_url': 'mock://test_track_1.mp3'},
          {'audio_url': 'mock://test_track_2.mp3'},
        ],
        input: {
          'title': title,
          'tags': tags,
          'prompt': prompt,
        },
      );
    });

    return GenApiResponse(
      requestId: requestId,
      status: 'waiting',
      progress: 0,
      input: {
        'title': title,
        'tags': tags,
        'prompt': prompt,
      },
    );
  }

  @override
  Future<GenApiResponse> getRequestStatus(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final response = _mockRequests[requestId];
    if (response == null) {
      throw MusicGenerationException('Запрос не найден: $requestId');
    }

    return response;
  }

  @override
  Future<List<String>> downloadMusicFiles({
    required List<String> audioUrls,
    required String sessionId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final filePaths = <String>[];

    for (int i = 0; i < audioUrls.length; i++) {
      final audioUrl = audioUrls[i];

      // Для мока копируем тестовый файл
      if (audioUrl.startsWith('mock://test_track_')) {
        try {
          // Путь к исходному мок-файлу
          final mockFile = File('.mock_data/test_track.mp3');
          if (!await mockFile.exists()) {
            throw MusicDownloadException(
              'Мок-файл не найден: .mock_data/test_track.mp3',
              audioUrl: audioUrl,
            );
          }

          // Копируем в папку загрузок
          final downloadsDir = await getDownloadsDirectory();
          final targetDir = downloadsDir ?? await getApplicationSupportDirectory();

          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final sessionHash = _generateShortHash(sessionId);
          final fileName = 'mock_music_${sessionHash}_${i + 1}_$timestamp.mp3';

          final targetFile = File(path.join(targetDir.path, fileName));
          await mockFile.copy(targetFile.path);

          filePaths.add(targetFile.path);
        } catch (e) {
          if (e is MusicDownloadException) rethrow;
          throw MusicDownloadException(
            'Ошибка копирования мок-файла: $e',
            audioUrl: audioUrl,
          );
        }
      } else {
        throw MusicDownloadException(
          'Неизвестный мок URL: $audioUrl',
          audioUrl: audioUrl,
        );
      }
    }

    return filePaths;
  }

  @override
  String generateSessionId(String requirements) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final input = '$requirements$timestamp';
    return _generateShortHash(input);
  }

  @override
  String generateRequirementsHash(String requirements) {
    return _generateShortHash(requirements);
  }

  String _generateShortHash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8);
  }

  @override
  void dispose() {
    _mockRequests.clear();
  }
}