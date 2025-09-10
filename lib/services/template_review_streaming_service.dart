import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'llm_service.dart';
import 'llm_streaming_provider.dart';
import '../models/llm_stream_chunk.dart';
import '../models/output_format.dart';

/// Streaming review & (future) fix service for templates.
class TemplateReviewStreamingService {
  final LLMService _llmService;
  TemplateReviewStreamingService({required LLMService llmService}) : _llmService = llmService;

  static const _criticalTag = '[КРИТИЧЕСКОЕ ЗАМЕЧАНИЕ]';
  static const _minorTag = '[НЕЗНАЧИТЕЛЬНОЕ ЗАМЕЧАНИЕ]';

  String buildReviewSystemPrompt() => '''Ты выступаешь как строгий методолог технической документации.
Анализируй шаблон на полноту, структурную и логическую согласованность.

ФОРМАТ ВЫХОДА: строго NDJSON (каждая строка отдельный валидный JSON-объект без лишнего текста).
ПЕРВАЯ строка: {"event":"meta","isCritical":<true|false>,"isMinor":<true|false>}.
Затем поток строк {"event":"text","delta":"<фрагмент пояснений>"} — разбивай логически, можно построчно.
Никакого иного текста вне JSON. Не добавляй префиксы/markdown до или после JSON.

Семантика:
- isCritical=true если есть хотя бы одно критическое несоответствие.
- isMinor=true если есть улучшения/замечания некритические.
- Если оба false => шаблон корректен, в текстовых событиях можно выдать одну осмысленную строку "Шаблон корректен.".
- Если isCritical=true и есть также минорные – ставь isMinor=true.

Содержимое пояснений (delta):
- Сначала блок критических (если есть) – списком (маркеры "- " допустимы внутри delta).
- Затем блок некритических.
- Не повторяй флаги и не выводи больше старые теговые строки, НО на случай деградации модели допустимо (fallback) вывести отдельной строкой $_criticalTag или $_minorTag – это не ошибка.

Важно:
- Не включай символы новой строки внутри JSON кроме как в escaped виде (\n). Предпочтительно разбивать по строкам отдельных замечаний, каждое своим JSON.
- Не добавляй лишние поля.
- Не сокращай ключи.

Пример (оба типа):
{"event":"meta","isCritical":true,"isMinor":true}
{"event":"text","delta":"- Критическое: отсутствует раздел 'Требования'"}
{"event":"text","delta":"- Критическое: противоречие между разделами 2 и 5"}
{"event":"text","delta":"- Улучшение: уточнить формат дат (ГГГГ-ММ-ДД)"}

Пример (только минорные):
{"event":"meta","isCritical":false,"isMinor":true}
{"event":"text","delta":"- Улучшение: добавить глоссарий"}

Пример (корректен):
{"event":"meta","isCritical":false,"isMinor":false}
{"event":"text","delta":"Шаблон корректен."}
''';

  Stream<String> streamReview({required String content, String? model}) {
    final provider = _llmService.provider;
    final controller = StreamController<String>();
    final system = buildReviewSystemPrompt();
    final user = content;

    // If provider supports streaming, use it; else fallback to single call.
  final base = provider; // may be null
  if (base is LLMStreamingProvider && (base as LLMStreamingProvider).supportsStreaming) {
      () async {
        try {
          final streamingProvider = base as LLMStreamingProvider; // explicit
          await for (final chunk in streamingProvider.streamChat(
            systemPrompt: system,
            userPrompt: user,
            model: model,
            cancelToken: CancelToken(),
          )) {
            if (chunk is LLMStreamChunkDelta) {
              if (chunk.delta.isNotEmpty) controller.add(chunk.delta);
            } else if (chunk is LLMStreamChunkError) {
              controller.addError(chunk.message);
            } else if (chunk is LLMStreamChunkFinal) {
              // Optionally flush full content (already streamed)
              break;
            }
          }
        } catch (e) {
          controller.addError(e);
        } finally {
          await controller.close();
        }
      }();
    } else {
      () async {
        try {
          final result = await _llmService.reviewTemplate(content, model);
          // Simulate chunking by splitting paragraphs
          final parts = const LineSplitter().convert(result);
          for (final p in parts) {
            controller.add(p + '\n');
            await Future.delayed(const Duration(milliseconds: 60));
          }
        } catch (e) {
          controller.addError(e);
        } finally {
          await controller.close();
        }
      }();
    }

    return controller.stream;
  }

  String buildFixSystemPrompt() => '''Ты редактор. Тебе дан исходный шаблон и результаты ревью. Синтезируй полностью исправленный шаблон в Markdown.
Правила:
1. Верни ТОЛЬКО новый текст без пояснений, тегов, комментариев.
2. Сохрани стиль.
3. Исправь критические и незначительные замечания.
''';

  Stream<String> streamFix({required String original, required String reviewText, String? model}) {
    final provider = _llmService.provider;
    final controller = StreamController<String>();
    final system = buildFixSystemPrompt();
    final user = 'Исходный шаблон:\n-----\n$original\n-----\nРезультат ревью:\n-----\n$reviewText\n-----\n';

    final base = provider;
    if (base is LLMStreamingProvider && (base as LLMStreamingProvider).supportsStreaming) {
      () async {
        try {
          final streamingProvider = base as LLMStreamingProvider;
          await for (final chunk in streamingProvider.streamChat(
            systemPrompt: system,
            userPrompt: user,
            model: model,
            cancelToken: CancelToken(),
          )) {
            if (chunk is LLMStreamChunkDelta) {
              if (chunk.delta.isNotEmpty) controller.add(chunk.delta);
            } else if (chunk is LLMStreamChunkError) {
              controller.addError(chunk.message);
            } else if (chunk is LLMStreamChunkFinal) {
              break;
            }
          }
        } catch (e) {
          controller.addError(e);
        } finally {
          await controller.close();
        }
      }();
      return controller.stream;
    }

    // fallback single call using reviewTemplate + heuristic (we need generation not review, reuse generateTZ?)
    () async {
      try {
        final generated = await _llmService.generateTZ(
          rawRequirements: original,
          changes: null,
          templateContent: null,
          format: OutputFormat.markdown,
        );
        for (final p in const LineSplitter().convert(generated)) {
          controller.add(p + '\n');
          await Future.delayed(const Duration(milliseconds: 60));
        }
      } catch (e) {
        controller.addError(e);
      } finally {
        await controller.close();
      }
    }();
    return controller.stream;
  }
}
