/// Base exception for content processing errors
abstract class ContentProcessingException implements Exception {
  final String message;
  final String? recoveryAction;
  final String? technicalDetails;
  
  const ContentProcessingException(
    this.message, {
    this.recoveryAction,
    this.technicalDetails,
  });
  
  @override
  String toString() => 'ContentProcessingException: $message';
  
  /// Returns a user-friendly error message with recovery suggestions
  String getUserFriendlyMessage() {
    String userMessage = message;
    if (recoveryAction != null) {
      userMessage += '\n\nРекомендуемое действие: $recoveryAction';
    }
    return userMessage;
  }
  
  /// Returns technical details for debugging
  String? getTechnicalDetails() => technicalDetails;
}

/// Exception thrown when Markdown processing fails
class MarkdownProcessingException extends ContentProcessingException {
  const MarkdownProcessingException(
    super.message, {
    super.recoveryAction,
    super.technicalDetails,
  });
  
  @override
  String toString() => 'MarkdownProcessingException: $message';
}

/// Exception thrown when HTML processing fails
class HtmlProcessingException extends ContentProcessingException {
  const HtmlProcessingException(
    super.message, {
    super.recoveryAction,
    super.technicalDetails,
  });
  
  @override
  String toString() => 'HtmlProcessingException: $message';
}

/// Exception thrown when LLM response validation fails
class LLMResponseValidationException extends ContentProcessingException {
  final String rawResponse;
  
  const LLMResponseValidationException(
    super.message,
    this.rawResponse, {
    super.recoveryAction,
    super.technicalDetails,
  });
  
  @override
  String toString() => 'LLMResponseValidationException: $message';
}

/// Exception thrown when escape markers are malformed or missing
class EscapeMarkerException extends LLMResponseValidationException {
  final bool hasStartMarker;
  final bool hasEndMarker;
  final bool hasContent;
  
  const EscapeMarkerException(
    super.message,
    super.rawResponse, {
    required this.hasStartMarker,
    required this.hasEndMarker,
    required this.hasContent,
    super.recoveryAction,
    super.technicalDetails,
  });
  
  @override
  String toString() => 'EscapeMarkerException: $message';
}

/// Exception thrown when content format validation fails
class ContentFormatException extends ContentProcessingException {
  final String expectedFormat;
  final String actualFormat;
  
  const ContentFormatException(
    super.message,
    this.expectedFormat,
    this.actualFormat, {
    super.recoveryAction,
    super.technicalDetails,
  });
  
  @override
  String toString() => 'ContentFormatException: $message';
}

/// Exception thrown when content extraction completely fails
class ContentExtractionException extends ContentProcessingException {
  final String processorType;
  
  const ContentExtractionException(
    super.message,
    this.processorType, {
    super.recoveryAction,
    super.technicalDetails,
  });
  
  @override
  String toString() => 'ContentExtractionException: $message';
}

/// Exception thrown during music generation API operations
class MusicGenerationException extends ContentProcessingException {
  const MusicGenerationException(
    super.message, {
    super.recoveryAction,
    super.technicalDetails,
  });

  @override
  String toString() => 'MusicGenerationException: $message';
}

/// Исключение для ошибок аутентификации GenAPI (401)
class ApiAuthenticationException extends MusicGenerationException {
  final int statusCode;

  const ApiAuthenticationException(
    super.message, {
    this.statusCode = 401,
    super.recoveryAction,
    super.technicalDetails,
  });

  @override
  String toString() => 'ApiAuthenticationException: $message (HTTP $statusCode)';
}

/// Исключение для ошибок лимита запросов GenAPI (419)
class ApiRateLimitException extends MusicGenerationException {
  final int statusCode;
  final Duration? retryAfter;

  const ApiRateLimitException(
    super.message, {
    this.statusCode = 419,
    this.retryAfter,
    super.recoveryAction,
    super.technicalDetails,
  });

  @override
  String toString() => 'ApiRateLimitException: $message (HTTP $statusCode)';
}

/// Исключение для ошибок сервера GenAPI (500, 503)
class ApiServerException extends MusicGenerationException {
  final int statusCode;

  const ApiServerException(
    super.message, {
    required this.statusCode,
    super.recoveryAction,
    super.technicalDetails,
  });

  @override
  String toString() => 'ApiServerException: $message (HTTP $statusCode)';
}

/// Исключение для ошибки таймаута генерации
class MusicGenerationTimeoutException extends MusicGenerationException {
  final Duration timeout;

  const MusicGenerationTimeoutException(
    super.message, {
    required this.timeout,
    super.recoveryAction,
    super.technicalDetails,
  });

  @override
  String toString() => 'MusicGenerationTimeoutException: $message (${timeout.inMinutes} min)';
}

/// Исключение для ошибок скачивания музыкального файла
class MusicDownloadException extends MusicGenerationException {
  final String? audioUrl;

  const MusicDownloadException(
    super.message, {
    this.audioUrl,
    super.recoveryAction,
    super.technicalDetails,
  });

  @override
  String toString() => 'MusicDownloadException: $message';
}

/// Исключение для недостаточного баланса (402)
class InsufficientFundsException extends MusicGenerationException {
  const InsufficientFundsException(
    super.message, {
    super.recoveryAction,
    super.technicalDetails,
  });

  @override
  String toString() => 'InsufficientFundsException: $message';
}