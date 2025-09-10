/// Base sealed class for streaming chunks coming from provider.
sealed class LLMStreamChunk {
  const LLMStreamChunk();
}

/// Delta (append) content piece.
class LLMStreamChunkDelta extends LLMStreamChunk {
  final String delta; // raw appended text
  const LLMStreamChunkDelta(this.delta);
}

/// Final chunk signaling completion; may carry the full accumulated text (optional).
class LLMStreamChunkFinal extends LLMStreamChunk {
  final String? full; // optional full assembled text
  final String? finishReason; // e.g. stop, length
  const LLMStreamChunkFinal({this.full, this.finishReason});
}

/// Error chunk signaling an error before completion.
class LLMStreamChunkError extends LLMStreamChunk {
  final String message;
  const LLMStreamChunkError(this.message);
}
