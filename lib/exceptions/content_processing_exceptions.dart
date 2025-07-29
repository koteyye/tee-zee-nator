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
    String message, {
    String? recoveryAction,
    String? technicalDetails,
  }) : super(message, recoveryAction: recoveryAction, technicalDetails: technicalDetails);
  
  @override
  String toString() => 'MarkdownProcessingException: $message';
}

/// Exception thrown when HTML processing fails
class HtmlProcessingException extends ContentProcessingException {
  const HtmlProcessingException(
    String message, {
    String? recoveryAction,
    String? technicalDetails,
  }) : super(message, recoveryAction: recoveryAction, technicalDetails: technicalDetails);
  
  @override
  String toString() => 'HtmlProcessingException: $message';
}

/// Exception thrown when LLM response validation fails
class LLMResponseValidationException extends ContentProcessingException {
  final String rawResponse;
  
  const LLMResponseValidationException(
    String message,
    this.rawResponse, {
    String? recoveryAction,
    String? technicalDetails,
  }) : super(message, recoveryAction: recoveryAction, technicalDetails: technicalDetails);
  
  @override
  String toString() => 'LLMResponseValidationException: $message';
}

/// Exception thrown when escape markers are malformed or missing
class EscapeMarkerException extends LLMResponseValidationException {
  final bool hasStartMarker;
  final bool hasEndMarker;
  final bool hasContent;
  
  const EscapeMarkerException(
    String message,
    String rawResponse, {
    required this.hasStartMarker,
    required this.hasEndMarker,
    required this.hasContent,
    String? recoveryAction,
    String? technicalDetails,
  }) : super(message, rawResponse, recoveryAction: recoveryAction, technicalDetails: technicalDetails);
  
  @override
  String toString() => 'EscapeMarkerException: $message';
}

/// Exception thrown when content format validation fails
class ContentFormatException extends ContentProcessingException {
  final String expectedFormat;
  final String actualFormat;
  
  const ContentFormatException(
    String message,
    this.expectedFormat,
    this.actualFormat, {
    String? recoveryAction,
    String? technicalDetails,
  }) : super(message, recoveryAction: recoveryAction, technicalDetails: technicalDetails);
  
  @override
  String toString() => 'ContentFormatException: $message';
}

/// Exception thrown when content extraction completely fails
class ContentExtractionException extends ContentProcessingException {
  final String processorType;
  
  const ContentExtractionException(
    String message,
    this.processorType, {
    String? recoveryAction,
    String? technicalDetails,
  }) : super(message, recoveryAction: recoveryAction, technicalDetails: technicalDetails);
  
  @override
  String toString() => 'ContentExtractionException: $message';
}