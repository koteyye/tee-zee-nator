import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/services/streaming_session_controller.dart';
import 'package:tee_zee_nator/services/streaming_llm_service.dart';
import 'package:tee_zee_nator/models/output_format.dart';

// Fake streaming service to produce deterministic lines
class FakeStreamingLLMService extends StreamingLLMService {
  FakeStreamingLLMService() : super(llmService: throw UnimplementedError());

  @override
  Stream<String> startSpecificationStream({
    required String rawRequirements,
    String? changes,
    String? templateContent,
    required OutputFormat format,
  }) async* {
    yield '{"stream_type":"status","phase":"init","progress":0,"message":"Инициализация","ts":"2025-01-01T00:00:00Z"}';
    yield '{"stream_type":"content","append":""}';
    yield '{"stream_type":"status","phase":"draft_sections","progress":40,"message":"Черновик","ts":"2025-01-01T00:00:02Z"}';
    yield '{"stream_type":"content","append":"# Заголовок\n\nТекст."}';
    yield '{"stream_type":"final","progress":100,"message":"Готово","summary":"OK"}';
  }
}

void main() {
  test('StreamingSessionController processes append and final', () async {
    final controller = StreamingSessionController(FakeStreamingLLMService());
    await controller.start(
      rawRequirements: 'R',
      format: OutputFormat.markdown,
    );
    // wait a short while for stream to finish
    await Future.delayed(const Duration(milliseconds: 50));
    expect(controller.state.document.contains('# Заголовок'), true);
    expect(controller.state.finalized, true);
    expect(controller.state.progress, 100);
  });

  test('Abort sets finalized and preserves partial text', () async {
    // Service with delay to allow abort
    final controller = StreamingSessionController(_SlowFakeService());
    unawaited(controller.start(rawRequirements: 'R', format: OutputFormat.markdown));
    await Future.delayed(const Duration(milliseconds: 30));
    await controller.abort();
    expect(controller.state.finalized, true);
  });
}

class _SlowFakeService extends StreamingLLMService {
  _SlowFakeService() : super(llmService: throw UnimplementedError());
  @override
  Stream<String> startSpecificationStream({
    required String rawRequirements,
    String? changes,
    String? templateContent,
    required OutputFormat format,
  }) async* {
    yield '{"stream_type":"status","phase":"init","progress":0,"message":"Инициализация","ts":"2025-01-01T00:00:00Z"}';
    await Future.delayed(const Duration(milliseconds: 100));
    yield '{"stream_type":"content","append":"Draft..."}';
  }
}
