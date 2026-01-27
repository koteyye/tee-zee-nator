import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:process_run/shell.dart';
import 'package:uuid/uuid.dart';

import '../models/music_generation_session.dart';
import '../models/spec_music_config.dart';
import '../services/gen_api_service.dart';
import '../services/mock_gen_api_service.dart';
import '../services/music_generation_interface.dart';
import '../services/notification_service.dart';
import '../services/llm_service.dart';
import '../exceptions/content_processing_exceptions.dart';

class MusicGenerationService extends ChangeNotifier {
  IMusicGenerationService? _genApiService;
  LLMService? _llmService;
  MusicGenerationSession? _currentSession;
  Timer? _pollingTimer;
  String? _currentBalance;
  BuildContext? _context;

  MusicGenerationSession? get currentSession => _currentSession;
  String? get currentBalance => _currentBalance;
  bool get hasActiveSession => _currentSession != null &&
      _currentSession!.status != MusicGenerationStatus.idle &&
      _currentSession!.status != MusicGenerationStatus.completed &&
      _currentSession!.status != MusicGenerationStatus.failed;

  void setContext(BuildContext context) {
    _context = context;
  }

  void configure(SpecMusicConfig config, {LLMService? llmService}) {
    if (_genApiService != null) {
      _genApiService!.dispose();
    }

    _llmService = llmService;

    if (config.enabled) {
      if (kDebugMode && config.useMock) {
        // В debug режиме с включенным моком используем мок-сервис
        _genApiService = MockGenApiService(apiKey: 'mock_key_for_debug');
      } else if (config.apiKey != null) {
        // В обычном режиме используем реальный сервис
        _genApiService = GenApiService(apiKey: config.apiKey!);
      } else {
        _genApiService = null;
      }
    } else {
      _genApiService = null;
    }
    notifyListeners();
  }

  Future<void> refreshBalance() async {
    if (_genApiService == null) return;

    try {
      final userInfo = await _genApiService!.getUserInfo();
      _currentBalance = userInfo.balance;
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка получения баланса: $e');
    }
  }

  Future<bool> validateApiKey() async {
    if (_genApiService == null) return false;

    try {
      await _genApiService!.getUserInfo();
      return true;
    } catch (e) {
      return false;
    }
  }

  static const String _lyricsGenerationPrompt = '''
Ты - эксперт по созданию lyrics в стиле Russian Gangsta Rap на основе технических заданий.

ЗАДАЧА:
Преобразуй техническое задание в текст песни (lyrics) для Suno в стиле Russian Gangsta Rap, где все требования, функционал и критерии зачитываются как рэп.

СТРУКТУРА LYRICS:
1. [Intro] - вступление с упоминанием User Story, версии документа, согласователей
2. [Verse 1] - проблематика и критерии приемки в рэп-форме
3. [Hook] - запоминающийся припев с ключевыми моментами проекта (повторяется 2-3 раза)
4. [Verse 2] - сценарии использования, описание флоу
5. [Verse 3] - функциональные требования Front-end
6. [Bridge] - переход к Back-end, можно добавить технический флоу
7. [Verse 4] - функциональные требования Back-end (API, база данных, безопасность)
8. [Verse 5] - нефункциональные требования (производительность, надёжность, масштабируемость)
9. [Outro/DoD] - критерии готовности (Definition of Done) как финальный речитатив
10. [Финал] - эффектное завершение про успешное выполнение проекта

СТИЛИСТИКА:
- Используй сленг Russian Gangsta Rap: "брат", "пацан", "движуха", "замутить", "на районе", "в деле"
- Добавляй технический сленг: "флоу", "пэйшн", "фрэш", "фидбак", "юзер"
- Сохраняй технические термины на английском там, где это уместно (API, POST, GET, CRUD, OAuth2)
- Используй рифмы и ритм, характерные для гангста-рэпа
- Добавляй ad-libs в скобках: (эй!), (yo!), (check it!), (ага!), (в деле!)
- Превращай цифры и метрики в рэп-строки
- Делай текст энергичным, дерзким, но сохраняй все технические детали

ТЕХНИЧЕСКИЕ ДЕТАЛИ (свободнее):
- Песня должна быть ОБ этих требованиях, но не повторять ТЗ дословно
- Достаточно упомянуть ключевые идеи/блоки, без полного перечисления всех пунктов
- Сохраняй общий смысл и структуру, но допускай творческие отклонения
- Таблицы, версии, статусы, согласователи и метрики — по желанию, только если органично

ФОРМАТ ВЫВОДА:
- Заголовок песни на основе названия проекта/фичи
- Разметка куплетов: [Intro], [Verse], [Hook], [Bridge], [Outro]
- В конце указать стиль: "Стиль: Russian Gangsta Rap"
- Общая длина текста — на трек до 5 минут (короче лучше, без лишней воды)

ПРИМЕР СТРОК:
❌ Плохо: "Нужно сделать API для отправки сообщений"
✅ Хорошо: "POST запрос на сервер мой, JSON летит стрелой"

❌ Плохо: "Производительность 200мс"
✅ Хорошо: "Двести миллисекунд держать - это мой стандарт, браза"

Начинай генерацию lyrics сразу после получения ТЗ, без дополнительных пояснений.
Не переписывай ТЗ целиком: это художественная интерпретация требований.
''';

  Future<String> _generateLyrics(String requirements) async {
    if (_llmService == null || _llmService!.provider == null) {
      throw MusicGenerationException(
        'LLM сервис не настроен. Невозможно сгенерировать Lyrics',
        recoveryAction: 'Настройте LLM провайдер в настройках приложения',
      );
    }

    try {
      final lyrics = await _llmService!.provider!.sendRequest(
        systemPrompt: _lyricsGenerationPrompt,
        userPrompt: requirements,
        temperature: 0.8, // Более креативная генерация
      );

      if (lyrics.trim().isEmpty) {
        throw MusicGenerationException('LLM вернул пустой Lyrics');
      }

      return lyrics.trim();
    } catch (e) {
      if (e is MusicGenerationException) rethrow;
      throw MusicGenerationException(
        'Ошибка генерации Lyrics: $e',
        recoveryAction: 'Проверьте соединение с LLM провайдером',
      );
    }
  }

  Future<void> startMusicGeneration(String requirements) async {
    if (_genApiService == null) {
      throw MusicGenerationException('Музикация не настроена');
    }

    if (hasActiveSession) {
      throw MusicGenerationException('Уже выполняется генерация музыки');
    }

    final sessionId = _genApiService!.generateSessionId(requirements);
    final requirementsHash = _genApiService!.generateRequirementsHash(requirements);

    _currentSession = MusicGenerationSession(
      sessionId: sessionId,
      requirementsHash: requirementsHash,
      status: MusicGenerationStatus.starting,
      createdAt: DateTime.now(),
      progressMessage: 'Генерируем Lyrics...',
    );
    notifyListeners();

    try {
      // Шаг 1: Генерируем Lyrics из требований
      final lyrics = await _generateLyrics(requirements);

      // Шаг 2: Генерируем UUID для title
      final title = const Uuid().v4();

      // Шаг 3: Обновляем статус перед отправкой
      _currentSession = _currentSession!.copyWith(
        progressMessage: 'Отправляем запрос на генерацию музыки...',
      );
      notifyListeners();

      // Шаг 4: Отправляем запрос в GenAPI с новыми параметрами
      final response = await _genApiService!.generateMusic(
        title: title,
        tags: 'russian gansta rap',
        prompt: lyrics,
        model: 'v5', // версия API GenAPI
        translateInput: null, // null = не переводить
      );

      if (response.requestId != null) {
        _currentSession = _currentSession!.copyWith(
          requestId: response.requestId,
          status: MusicGenerationStatus.generating,
          progressMessage: 'Трекаем требования...',
        );
        notifyListeners();

        _startPolling(response.requestId!);
      } else {
        throw MusicGenerationException('Не получен ID запроса');
      }
    } on InsufficientFundsException catch (e) {
      _currentSession = _currentSession!.copyWith(
        status: MusicGenerationStatus.insufficientFunds,
        errorMessage: e.message,
        progressMessage: 'Закончились бабосики для музикации',
      );
      notifyListeners();

      // Через 3 секунды сброс в idle
      Timer(const Duration(seconds: 3), () {
        _resetSession();
      });
    } catch (e) {
      _handleError(e.toString(), exception: e is Exception ? e : null);
    }
  }

  void _startPolling(String requestId) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final response = await _genApiService!.getRequestStatus(requestId);

        switch (response.status.toLowerCase()) {
          case 'waiting':
            _currentSession = _currentSession!.copyWith(
              progressMessage: 'В очереди на обработку...',
            );
            notifyListeners();
            break;

          case 'progress':
            // Обновляем прогресс, если доступен
            final progress = response.progress ?? 0;
            _currentSession = _currentSession!.copyWith(
              progressMessage: 'Генерируем ваш трек... ($progress%)',
            );
            notifyListeners();
            break;

          case 'success':
            // Проверяем, что прогресс достиг 100%
            final progress = response.progress ?? 0;
            if (progress >= 100 && response.audioUrls.isNotEmpty) {
              timer.cancel();
              await _downloadAndComplete(response.audioUrls);
            } else if (progress < 100) {
              // Генерация еще не завершена
              _currentSession = _currentSession!.copyWith(
                progressMessage: 'Генерация $progress%...',
              );
              notifyListeners();
            } else {
              timer.cancel();
              _handleError('Успешная генерация, но нет ссылок на файлы');
            }
            break;

          case 'error':
            timer.cancel();
            _handleError(response.error ?? 'Неизвестная ошибка генерации');
            break;

          default:
            _currentSession = _currentSession!.copyWith(
              progressMessage: 'Статус: ${response.status}',
            );
            notifyListeners();
        }
      } catch (e) {
        timer.cancel();
        _handleError('Ошибка получения статуса: $e');
      }
    });

    // Таймаут через 5 минут
    Timer(const Duration(minutes: 5), () {
      if (_pollingTimer?.isActive == true) {
        _pollingTimer!.cancel();
        _handleError('Таймаут ожидания генерации');
      }
    });
  }

  Future<void> _downloadAndComplete(List<String> audioUrls) async {
    try {
      _currentSession = _currentSession!.copyWith(
        status: MusicGenerationStatus.downloading,
        progressMessage: 'Скачиваем ${audioUrls.length} ${audioUrls.length == 1 ? "вариант" : "варианта"} композиции...',
      );
      notifyListeners();

      final filePaths = await _genApiService!.downloadMusicFiles(
        audioUrls: audioUrls,
        sessionId: _currentSession!.sessionId,
      );

      _currentSession = _currentSession!.copyWith(
        status: MusicGenerationStatus.completed,
        filePaths: filePaths,
        completedAt: DateTime.now(),
        progressMessage: 'Музикация выполнена (${filePaths.length} ${filePaths.length == 1 ? "файл" : "файла"})',
      );
      notifyListeners();
    } catch (e) {
      _handleError('Ошибка загрузки файла: $e', exception: e is Exception ? e : null);
    }
  }

  void _handleError(String error, {Exception? exception}) {
    _currentSession = _currentSession?.copyWith(
      status: MusicGenerationStatus.failed,
      errorMessage: error,
      progressMessage: 'Ошибка генерации',
    );
    notifyListeners();

    // Показываем уведомление, если доступен контекст
    if (_context != null && _context!.mounted) {
      final userFriendlyMessage = _getUserFriendlyErrorMessage(error, exception);
      NotificationService.showError(
        _context!,
        userFriendlyMessage,
        technicalDetails: error,
      );
    }
  }

  /// Преобразует техническую ошибку в понятное пользователю сообщение
  String _getUserFriendlyErrorMessage(String error, Exception? exception) {
    if (exception is ApiAuthenticationException) {
      return 'Неверный API ключ. Проверьте настройки музикации';
    } else if (exception is ApiRateLimitException) {
      return 'Превышен лимит запросов. Попробуйте через несколько секунд';
    } else if (exception is ApiServerException) {
      if (exception.statusCode == 503) {
        return 'Системная ошибка GenAPI. Попробуйте позже';
      } else if (exception.statusCode == 404) {
        return 'Сервис Suno недоступен';
      }
      return 'Ошибка сервера GenAPI (${exception.statusCode})';
    } else if (exception is MusicGenerationTimeoutException) {
      return 'Превышено время ожидания генерации (${exception.timeout.inMinutes} мин)';
    } else if (exception is MusicDownloadException) {
      return 'Ошибка загрузки музыкального файла';
    } else if (exception is MusicGenerationException) {
      return exception.message;
    }

    // Парсинг по тексту ошибки
    if (error.contains('request_id') || error.contains('ID запроса')) {
      return 'Не получен ID запроса от сервера';
    } else if (error.contains('ссылка') || error.contains('файл')) {
      return 'Успешная генерация, но нет ссылки на файл';
    } else if (error.contains('Таймаут') || error.contains('timeout')) {
      return 'Превышено время ожидания генерации';
    } else if (error.contains('статус') || error.contains('status')) {
      return 'Ошибка получения статуса генерации';
    } else if (error.contains('настроена') || error.contains('configured')) {
      return 'Музикация не настроена. Добавьте API ключ в настройках';
    }

    return error; // Возвращаем как есть, если не распознали
  }

  Future<void> openFileInFolder() async {
    if (_currentSession?.filePath == null) return;

    try {
      final file = File(_currentSession!.filePath!);
      if (!await file.exists()) {
        throw MusicGenerationException('Файл не найден');
      }

      if (Platform.isWindows) {
        await Shell().run('explorer /select,"${_currentSession!.filePath}"');
      } else if (Platform.isMacOS) {
        await Shell().run('open -R "${_currentSession!.filePath}"');
      } else {
        // Linux и другие платформы - открываем папку
        final directory = file.parent.path;
        await Shell().run('xdg-open "$directory"');
      }
    } catch (e) {
      throw MusicGenerationException('Ошибка открытия папки: $e');
    }
  }

  void cancelGeneration() {
    _pollingTimer?.cancel();
    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(
        status: MusicGenerationStatus.cancelled,
        progressMessage: 'Генерация отменена',
      );
      notifyListeners();
    }
  }

  void _resetSession() {
    _currentSession = null;
    _pollingTimer?.cancel();
    notifyListeners();
  }

  void clearSession() {
    _resetSession();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _genApiService?.dispose();
    super.dispose();
  }
}