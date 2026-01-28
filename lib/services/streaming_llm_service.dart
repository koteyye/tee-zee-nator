import 'dart:async';
import 'dart:convert';
import '../models/output_format.dart';
import '../models/llm_stream_chunk.dart';
import 'llm_service.dart';
import 'llm_streaming_provider.dart';
import 'package:dio/dio.dart';

/// Service that produces an NDJSON streaming simulation (status / content / final)
/// Until native provider streaming is implemented, this wraps the existing LLMService
/// single-response call and splits the final document into incremental chunks.
class StreamingLLMService {
  final LLMService _llmService;
  CancelToken? _activeCancelToken;

  StreamingLLMService({
    required LLMService llmService,
  }) : _llmService = llmService;

  /// Starts a specification streaming session returning a Stream<String> of NDJSON lines.
  /// For now: simulated streaming based on a single full response.
  Stream<String> startSpecificationStream({
    required String rawRequirements,
    String? changes,
    String? templateContent,
    required OutputFormat format,
  }) {
  final controller = StreamController<String>();
    final startTs = DateTime.now().toUtc();

    String isoNow() => DateTime.now().toUtc().toIso8601String();

    void addJson(Map<String, dynamic> obj) {
      controller.add(jsonEncode(obj));
    }

    void emitInitial() {
      addJson({
        'stream_type': 'status',
        'phase': 'init',
        'progress': 0,
        'message': 'Инициализация',
        'ts': startTs.toIso8601String(),
      });
      addJson({
        'stream_type': 'content',
        'append': ''
      });
    }

    emitInitial();

    final provider = _llmService.provider;
  final supportsReal = provider is LLMStreamingProvider && (provider as LLMStreamingProvider).supportsStreaming;

    if (supportsReal) {
      () async {
        try {
          addJson({
            'stream_type': 'status',
            'phase': 'plan',
            'progress': 3,
            'message': 'Подготовка промтов',
            'ts': isoNow(),
          });
          // For real provider streaming we need normal prompts (no NDJSON protocol),
          // otherwise the model will emit JSON lines as content.
          final prompts = _llmService.buildGenerationPrompts(
            rawRequirements: rawRequirements,
            changes: changes,
            templateContent: templateContent,
            format: format,
            forStreaming: false,
          );
          addJson({
            'stream_type': 'status',
            'phase': 'structure',
            'progress': 6,
            'message': 'Запуск стриминга',
            'ts': isoNow(),
          });

          final streamingProvider = provider as LLMStreamingProvider;
          final started = DateTime.now();
          _activeCancelToken = CancelToken();

          bool gotFinal = false;

          await for (final chunk in streamingProvider.streamChat(
            systemPrompt: prompts['system']!,
            userPrompt: prompts['user']!,
            model: null,
            cancelToken: _activeCancelToken,
          )) {
            if (chunk is LLMStreamChunkDelta) {
              final delta = chunk.delta;
              if (delta.isNotEmpty) {
                addJson({
                  'stream_type': 'content',
                  'append': delta,
                });
              }
            } else if (chunk is LLMStreamChunkError) {
              addJson({
                'stream_type': 'status',
                'phase': 'finalize',
                'progress': 100,
                'message': 'Ошибка: ${chunk.message}',
                'ts': isoNow(),
              });
              addJson({
                'stream_type': 'final',
                'progress': 100,
                'message': 'Завершено с ошибкой',
                'summary': 'Ошибка стриминга: ${chunk.message}'
              });
              gotFinal = true;
              break;
            } else if (chunk is LLMStreamChunkFinal) {
              final full = chunk.full;
              if (full != null && full.isNotEmpty) {
                addJson({
                  'stream_type': 'content',
                  'full': full,
                });
              }
              if (!gotFinal) {
                addJson({
                  'stream_type': 'status',
                  'phase': 'finalize',
                  'progress': 99,
                  'message': 'Финализация',
                  'ts': isoNow(),
                });
                addJson({
                  'stream_type': 'final',
                  'progress': 100,
                  'message': 'Готово',
                  'summary': 'Реальный стрим завершен за ${DateTime.now().difference(started).inSeconds}s'
                });
              }
              break;
            }
          }
        } catch (e) {
          addJson({
            'stream_type': 'status',
            'phase': 'finalize',
            'progress': 100,
            'message': 'Ошибка: $e',
            'ts': isoNow(),
          });
          addJson({
            'stream_type': 'final',
            'progress': 100,
            'message': 'Завершено с ошибкой',
            'summary': 'Ошибка стриминга: $e'
          });
        } finally {
          _activeCancelToken = null;
          await Future.delayed(const Duration(milliseconds: 40));
          await controller.close();
        }
      }();
      return controller.stream;
    }

    // Start async generation
  // Fallback simulation (legacy non-stream approach)
  () async {
      try {
        addJson({
          'stream_type': 'status',
          'phase': 'plan',
          'progress': 5,
          'message': 'Анализ требований',
          'ts': isoNow(),
        });

        final activeTemplate = templateContent ?? '';

        addJson({
          'stream_type': 'status',
          'phase': 'structure',
          'progress': 10,
          'message': 'Формирование структуры',
          'ts': isoNow(),
        });

        // Use existing generation (non-stream)
        final generated = await _llmService.generateTZ(
          rawRequirements: rawRequirements,
          changes: changes,
          templateContent: activeTemplate.isEmpty ? null : activeTemplate,
          format: format,
        );

        // Extract actual content markers if present (reuse llm_service processors indirectly handled by caller)
        // We split by double newline to keep paragraphs small.
        final cleaned = generated;
        final paragraphs = _splitIntoChunks(cleaned);
        if (paragraphs.isEmpty) {
          addJson({
            'stream_type': 'content',
            'append': cleaned.trim(),
          });
        } else {
          final total = paragraphs.length;
          int idx = 0;
          for (final p in paragraphs) {
            idx++;
            final ratio = idx / total;
            final phase = ratio < 0.7 ? 'draft_sections' : (ratio < 0.9 ? 'refine' : 'validate');
            final progress = (10 + (ratio * 80)).clamp(11, 95).round();
            addJson({
              'stream_type': 'status',
              'phase': phase,
              'progress': progress,
              'message': phase == 'draft_sections' ? 'Генерация частей документа' : phase == 'refine' ? 'Уточнение и улучшения' : 'Проверка качества',
              'ts': isoNow(),
            });
            addJson({
              'stream_type': 'content',
              'append': p,
            });
            // Small delay to allow UI to repaint (simulation)
            await Future.delayed(const Duration(milliseconds: 120));
          }
        }

        addJson({
          'stream_type': 'status',
          'phase': 'finalize',
          'progress': 99,
          'message': 'Финализация документа',
          'ts': isoNow(),
        });

        addJson({
          'stream_type': 'final',
          'progress': 100,
            'message': 'Готово',
          'summary': 'Сформирован полный документ (${format.displayName}) за ${DateTime.now().difference(startTs).inSeconds}s'
        });
      } catch (e) {
        addJson({
          'stream_type': 'status',
          'phase': 'finalize',
          'progress': 100,
          'message': 'Ошибка: $e',
          'ts': isoNow(),
        });
        addJson({
          'stream_type': 'final',
          'progress': 100,
          'message': 'Завершено с ошибкой',
          'summary': 'Ошибка генерации: $e'
        });
      } finally {
        await Future.delayed(const Duration(milliseconds: 50));
        await controller.close();
      }
    }();

    return controller.stream;
  }

  /// Aborts active real streaming HTTP request (if any). No-op for simulation.
  void abortCurrent() {
    if (_activeCancelToken != null && !_activeCancelToken!.isCancelled) {
      _activeCancelToken!.cancel('user_abort');
    }
  }

  List<String> _splitIntoChunks(String text) {
    // Remove markers if present
    final startMarker = '@@@START@@@';
    final endMarker = '@@@END@@@';
    String cleaned = text;
    if (cleaned.contains(startMarker) && cleaned.contains(endMarker)) {
      final startIdx = cleaned.indexOf(startMarker) + startMarker.length;
      final endIdx = cleaned.indexOf(endMarker);
      if (startIdx < endIdx) {
        cleaned = cleaned.substring(startIdx, endIdx).trim();
      }
    }
    final rawChunks = cleaned.split(RegExp(r'\n{2,}'));
    return rawChunks
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .map((c) => '$c\n\n')
        .toList();
  }
}
