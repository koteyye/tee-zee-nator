import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_session.dart';
import '../models/chat_message.dart';
import '../models/ai_response.dart';
import '../models/file_change.dart';
import '../models/ai_generated_content.dart';
import '../models/project_error.dart';
import 'streaming_llm_service.dart';
import 'confluence_service.dart';
import 'file_modification_service.dart';
import 'project_service.dart';

/// Сервис для работы с AI-чатом
class AIChatService extends ChangeNotifier {
  AIChatSession? _currentSession;
  final List<AIChatSession> _sessions = [];
  final StreamingLLMService _llmService;
  final ConfluenceService _confluenceService;
  final FileModificationService _fileModificationService;
  final ProjectService _projectService;

  List<FileChange>? _pendingFileChanges;
  int _currentFileChangeIndex = 0;

  AIChatService({
    required StreamingLLMService llmService,
    required ConfluenceService confluenceService,
    required FileModificationService fileModificationService,
    required ProjectService projectService,
  })  : _llmService = llmService,
        _confluenceService = confluenceService,
        _fileModificationService = fileModificationService,
        _projectService = projectService;

  /// Текущая сессия
  AIChatSession? get currentSession => _currentSession;

  /// Все сессии
  List<AIChatSession> get sessions => _sessions;

  /// Pending контент
  AIGeneratedContent? get pendingContent => _currentSession?.pendingContent;

  /// Pending изменения файлов
  List<FileChange>? get pendingFileChanges => _pendingFileChanges;

  /// Индекс текущего файла для одобрения
  int get currentFileChangeIndex => _currentFileChangeIndex;

  /// Начать новую сессию
  Future<void> startSession(ChatMode mode, {String? contextFileId}) async {
    try {
      final session = AIChatSession(
        id: const Uuid().v4(),
        mode: mode,
        messages: [],
        createdAt: DateTime.now(),
        contextFileId: contextFileId,
      );

      _currentSession = session;
      _sessions.add(session);

      notifyListeners();
      debugPrint('[AIChatService] Started session: ${session.id}, mode: $mode');
    } catch (e) {
      debugPrint('[AIChatService] Error starting session: $e');
      rethrow;
    }
  }

  /// Отправить сообщение в чат (streaming)
  Stream<AIResponse> sendMessageStream(String message) async* {
    if (_currentSession == null) {
      throw Exception('Нет активной сессии чата');
    }

    try {
      // Добавляем сообщение пользователя
      _currentSession!.addUserMessage(message);
      notifyListeners();

      // Обрабатываем Confluence ссылки
      final processedMessage = await processConfluenceLinks(message);

      // Подготавливаем контекст
      String prompt = processedMessage;

      // Добавляем контекст файла если есть
      if (_currentSession!.contextFileId != null) {
        final file = _projectService.getFileById(_currentSession!.contextFileId!);
        if (file != null && file.cachedContent != null) {
          prompt = 'Контекст файла ${file.name}:\n\n${file.cachedContent}\n\n$processedMessage';
        }
      }

      // Отправляем в LLM
      // TODO: Использовать правильный streaming метод когда будет готов
      final streamController = StreamController<AIResponse>();

      // Временная заглушка - используем обычный ответ
      // В будущем здесь будет настоящий streaming
      Future.delayed(Duration.zero, () async {
        try {
          // Создаем простой ответ
          final response = AIResponse(
            userMessage: 'Ответ от AI на: $prompt',
          );
          streamController.add(response);
          streamController.close();
        } on SocketException catch (e) {
          // Обработка сетевых ошибок
          debugPrint('[AIChatService] Network error: $e');
          streamController.addError(ProjectError.aiNetworkError(e));
          streamController.close();
        } on TimeoutException catch (e) {
          // Обработка таймаутов
          debugPrint('[AIChatService] Timeout error: $e');
          streamController.addError(ProjectError.aiTimeout());
          streamController.close();
        } catch (e) {
          streamController.addError(e);
          streamController.close();
        }
      });

      await for (final response in streamController.stream) {
        // Добавляем сообщение ассистента
        _currentSession!.addAssistantMessage(response.userMessage);

        // Если есть контент для файла, создаем pending content
        if (response.hasSingleFileContent && _currentSession!.contextFileId != null) {
          final content = AIGeneratedContent(
            fileContent: response.fileContent!,
            userMessage: response.userMessage,
            targetFileId: _currentSession!.contextFileId!,
            generatedAt: DateTime.now(),
          );
          _currentSession!.setPendingContent(content);
        }

        // Если есть множественные изменения
        if (response.hasMultipleFileChanges) {
          _pendingFileChanges = response.fileChanges;
          _currentFileChangeIndex = 0;
        }

        notifyListeners();
        yield response;
      }
    } on ProjectError {
      rethrow;
    } on SocketException catch (e) {
      debugPrint('[AIChatService] Network error in stream: $e');
      throw ProjectError.aiNetworkError(e);
    } on TimeoutException catch (e) {
      debugPrint('[AIChatService] Timeout error in stream: $e');
      throw ProjectError.aiTimeout();
    } catch (e) {
      debugPrint('[AIChatService] Error sending message: $e');
      throw ProjectError.generic('Failed to send message to AI', e);
    }
  }

  /// Парсить ответ от AI
  AIResponse _parseAIResponse(String chunk) {
    try {
      // Пытаемся распарсить как JSON
      final json = jsonDecode(chunk);
      return AIResponse.fromJson(json);
    } on FormatException catch (e) {
      // Если невалидный JSON, выбрасываем специфичную ошибку
      debugPrint('[AIChatService] Invalid JSON response: $e');
      throw ProjectError.aiInvalidResponse(e.toString());
    } catch (e) {
      // Если не JSON, возвращаем как простое сообщение
      return AIResponse(userMessage: chunk);
    }
  }

  /// Принять сгенерированный контент
  Future<void> acceptGeneratedContent(AIGeneratedContent content) async {
    try {
      final file = _projectService.getFileById(content.targetFileId);
      if (file == null) {
        throw Exception('Файл не найден: ${content.targetFileId}');
      }

      // Применяем контент через FileModificationService
      _fileModificationService.applyPendingContent(file, content.fileContent);

      // Обновляем статус
      content.accept();

      // Очищаем pending контент
      _currentSession?.clearPendingContent();

      notifyListeners();
      debugPrint('[AIChatService] Accepted content for ${file.name}');
    } catch (e) {
      debugPrint('[AIChatService] Error accepting content: $e');
      rethrow;
    }
  }

  /// Принять изменение файла (из множественных)
  Future<void> acceptFileChange(FileChange change, int index) async {
    try {
      // Находим файл по имени
      final file = _projectService.getFileByPath(change.targetFile);
      if (file == null) {
        throw Exception('Файл не найден: ${change.targetFile}');
      }

      // Применяем изменение
      _fileModificationService.applyPendingContent(file, change.content);

      // Переходим к следующему файлу
      _currentFileChangeIndex++;

      notifyListeners();
      debugPrint('[AIChatService] Accepted change for ${change.targetFile}');
    } catch (e) {
      debugPrint('[AIChatService] Error accepting file change: $e');
      rethrow;
    }
  }

  /// Отклонить сгенерированный контент
  void rejectGeneratedContent(AIGeneratedContent content) {
    content.reject();
    _currentSession?.clearPendingContent();
    notifyListeners();
    debugPrint('[AIChatService] Rejected content');
  }

  /// Отклонить изменение файла
  void rejectFileChange(int index) {
    _currentFileChangeIndex++;
    notifyListeners();
    debugPrint('[AIChatService] Rejected file change at index $index');
  }

  /// Прикрепить файл как контекст
  void attachFileContext(String fileId) {
    if (_currentSession != null) {
      _currentSession!.contextFileId = fileId;
      notifyListeners();
    }
  }

  /// Обработать Confluence ссылки в сообщении
  Future<String> processConfluenceLinks(String message) async {
    try {
      // Regex для поиска Confluence ссылок
      final confluenceUrlRegex = RegExp(
        r'https?://[^\s]+/wiki/spaces/[^\s]+',
        caseSensitive: false,
      );

      final matches = confluenceUrlRegex.allMatches(message);
      if (matches.isEmpty) {
        return message;
      }

      String processedMessage = message;

      for (final match in matches) {
        final url = match.group(0)!;

        try {
          // Загружаем контент через ConfluenceService
          // TODO: Реализовать метод загрузки по URL в ConfluenceService
          debugPrint('[AIChatService] Found Confluence link: $url');
          // final content = await _confluenceService.fetchContentByUrl(url);
          // processedMessage += '\n\nКонтент из Confluence:\n$content';
        } catch (e) {
          debugPrint('[AIChatService] Error loading Confluence link: $e');
        }
      }

      return processedMessage;
    } catch (e) {
      debugPrint('[AIChatService] Error processing Confluence links: $e');
      return message;
    }
  }

  /// Закрыть текущую сессию
  void closeSession() {
    _currentSession = null;
    _pendingFileChanges = null;
    _currentFileChangeIndex = 0;
    notifyListeners();
  }

  /// Очистить все pending изменения
  void clearPendingChanges() {
    _currentSession?.clearPendingContent();
    _pendingFileChanges = null;
    _currentFileChangeIndex = 0;
    notifyListeners();
  }
}
