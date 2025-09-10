import '../models/llm_stream_chunk.dart';
import 'package:dio/dio.dart';

/// Interface for providers that support token-level (or chunk-level) streaming.
abstract class LLMStreamingProvider {
  /// Returns true if the underlying provider / endpoint supports streaming.
  bool get supportsStreaming => true;

  /// Starts a streaming chat completion returning incremental chunks.
  /// Must emit [LLMStreamChunkDelta] for partial content and finally
  /// a single [LLMStreamChunkFinal]. In case of unrecoverable error
  /// emit [LLMStreamChunkError] (and then close the stream).
  Stream<LLMStreamChunk> streamChat({
    required String systemPrompt,
    required String userPrompt,
    String? model,
    int? maxTokens,
    double? temperature,
    CancelToken? cancelToken,
  });
}
