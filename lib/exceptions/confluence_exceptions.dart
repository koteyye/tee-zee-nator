/// Base exception for all Confluence-related errors
abstract class ConfluenceException implements Exception {
  final String message;
  final String? technicalDetails;
  final String? recoveryAction;
  final ConfluenceErrorType type;

  const ConfluenceException(
    this.message,
    this.type, {
    this.technicalDetails,
    this.recoveryAction,
  });

  @override
  String toString() => 'ConfluenceException: $message';

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

/// Exception thrown when token decryption fails
class ConfluenceTokenException extends ConfluenceException {
  final String? token;

  const ConfluenceTokenException(
    String message, {
    this.token,
    String? technicalDetails,
    String? recoveryAction,
  }) : super(
          message,
          ConfluenceErrorType.authentication,
          technicalDetails: technicalDetails,
          recoveryAction: recoveryAction,
        );

  @override
  String toString() => 'ConfluenceTokenException: $message';
}

/// Enumeration of Confluence error types
enum ConfluenceErrorType {
  connection,
  authentication,
  authorization,
  contentProcessing,
  publishing,
  rateLimit,
  validation,
  network,
  parsing,
}

/// Exception thrown when connection to Confluence fails
class ConfluenceConnectionException extends ConfluenceException {
  final String? baseUrl;
  final int? statusCode;

  const ConfluenceConnectionException(
    String message, {
    this.baseUrl,
    this.statusCode,
    String? technicalDetails,
    String? recoveryAction,
  }) : super(
          message,
          ConfluenceErrorType.connection,
          technicalDetails: technicalDetails,
          recoveryAction: recoveryAction,
        );

  @override
  String toString() => 'ConfluenceConnectionException: $message';
}

/// Exception thrown when authentication fails
class ConfluenceAuthenticationException extends ConfluenceException {
  final String? token;

  const ConfluenceAuthenticationException(
    String message, {
    this.token,
    String? technicalDetails,
    String? recoveryAction,
  }) : super(
          message,
          ConfluenceErrorType.authentication,
          technicalDetails: technicalDetails,
          recoveryAction: recoveryAction,
        );

  @override
  String toString() => 'ConfluenceAuthenticationException: $message';
}

/// Exception thrown when user lacks required permissions
class ConfluenceAuthorizationException extends ConfluenceException {
  final String? requiredPermission;
  final String? pageId;

  const ConfluenceAuthorizationException(
    String message, {
    this.requiredPermission,
    this.pageId,
    String? technicalDetails,
    String? recoveryAction,
  }) : super(
          message,
          ConfluenceErrorType.authorization,
          technicalDetails: technicalDetails,
          recoveryAction: recoveryAction,
        );

  @override
  String toString() => 'ConfluenceAuthorizationException: $message';
}

/// Exception thrown when content processing fails
class ConfluenceContentProcessingException extends ConfluenceException {
  final String? originalUrl;
  final String? pageId;

  const ConfluenceContentProcessingException(
    String message, {
    this.originalUrl,
    this.pageId,
    String? technicalDetails,
    String? recoveryAction,
  }) : super(
          message,
          ConfluenceErrorType.contentProcessing,
          technicalDetails: technicalDetails,
          recoveryAction: recoveryAction,
        );

  @override
  String toString() => 'ConfluenceContentProcessingException: $message';
}

/// Exception thrown when publishing operations fail
class ConfluencePublishingException extends ConfluenceException {
  final String? pageId;
  final String? parentPageId;
  final String? operation;

  const ConfluencePublishingException(
    String message, {
    this.pageId,
    this.parentPageId,
    this.operation,
    String? technicalDetails,
    String? recoveryAction,
  }) : super(
          message,
          ConfluenceErrorType.publishing,
          technicalDetails: technicalDetails,
          recoveryAction: recoveryAction,
        );

  @override
  String toString() => 'ConfluencePublishingException: $message';
}

/// Exception thrown when API rate limits are exceeded
class ConfluenceRateLimitException extends ConfluenceException {
  final int? retryAfterSeconds;
  final int? remainingRequests;

  const ConfluenceRateLimitException(
    String message, {
    this.retryAfterSeconds,
    this.remainingRequests,
    String? technicalDetails,
    String? recoveryAction,
  }) : super(
          message,
          ConfluenceErrorType.rateLimit,
          technicalDetails: technicalDetails,
          recoveryAction: recoveryAction,
        );

  @override
  String toString() => 'ConfluenceRateLimitException: $message';
}

/// Exception thrown when validation fails
class ConfluenceValidationException extends ConfluenceException {
  final String? fieldName;
  final String? invalidValue;

  const ConfluenceValidationException(
    String message, {
    this.fieldName,
    this.invalidValue,
    String? technicalDetails,
    String? recoveryAction,
  }) : super(
          message,
          ConfluenceErrorType.validation,
          technicalDetails: technicalDetails,
          recoveryAction: recoveryAction,
        );

  @override
  String toString() => 'ConfluenceValidationException: $message';
}

/// Exception thrown when network operations fail
class ConfluenceNetworkException extends ConfluenceException {
  final String? url;
  final String? method;
  final int? statusCode;

  const ConfluenceNetworkException(
    String message, {
    this.url,
    this.method,
    this.statusCode,
    String? technicalDetails,
    String? recoveryAction,
  }) : super(
          message,
          ConfluenceErrorType.network,
          technicalDetails: technicalDetails,
          recoveryAction: recoveryAction,
        );

  @override
  String toString() => 'ConfluenceNetworkException: $message';
}

/// Exception thrown when parsing Confluence responses fails
class ConfluenceParsingException extends ConfluenceException {
  final String? rawResponse;
  final String? expectedFormat;

  const ConfluenceParsingException(
    String message, {
    this.rawResponse,
    this.expectedFormat,
    String? technicalDetails,
    String? recoveryAction,
  }) : super(
          message,
          ConfluenceErrorType.parsing,
          technicalDetails: technicalDetails,
          recoveryAction: recoveryAction,
        );

  @override
  String toString() => 'ConfluenceParsingException: $message';
}

/// Factory class for creating common Confluence exceptions
class ConfluenceExceptionFactory {
  /// Creates a connection exception with common recovery actions
  static ConfluenceConnectionException connectionFailed({
    required String baseUrl,
    int? statusCode,
    String? details,
  }) {
    return ConfluenceConnectionException(
      'Failed to connect to Confluence at $baseUrl',
      baseUrl: baseUrl,
      statusCode: statusCode,
      technicalDetails: details,
      recoveryAction: 'Check your internet connection and verify the Base URL is correct',
    );
  }

  /// Creates an authentication exception with common recovery actions
  static ConfluenceAuthenticationException authenticationFailed({
    String? details,
  }) {
    return ConfluenceAuthenticationException(
      'Authentication failed. Invalid token or credentials.',
      technicalDetails: details,
      recoveryAction: 'Verify your API token is correct and has not expired',
    );
  }

  /// Creates an authorization exception with common recovery actions
  static ConfluenceAuthorizationException authorizationFailed({
    required String operation,
    String? pageId,
    String? details,
  }) {
    return ConfluenceAuthorizationException(
      'Insufficient permissions to $operation',
      requiredPermission: operation,
      pageId: pageId,
      technicalDetails: details,
      recoveryAction: 'Contact your Confluence administrator to grant the required permissions',
    );
  }

  /// Creates a rate limit exception with retry information
  static ConfluenceRateLimitException rateLimitExceeded({
    int? retryAfterSeconds,
    String? details,
  }) {
    final retryMessage = retryAfterSeconds != null 
        ? ' Retry after $retryAfterSeconds seconds.'
        : '';
    
    return ConfluenceRateLimitException(
      'API rate limit exceeded.$retryMessage',
      retryAfterSeconds: retryAfterSeconds,
      technicalDetails: details,
      recoveryAction: 'Wait before making additional requests to avoid rate limiting',
    );
  }

  /// Creates a validation exception for invalid URLs
  static ConfluenceValidationException invalidUrl({
    required String url,
    String? expectedFormat,
  }) {
    return ConfluenceValidationException(
      'Invalid Confluence URL format',
      fieldName: 'url',
      invalidValue: url,
      technicalDetails: expectedFormat != null 
          ? 'Expected format: $expectedFormat'
          : null,
      recoveryAction: 'Ensure the URL follows the correct Confluence page format',
    );
  }

  /// Creates a content processing exception
  static ConfluenceContentProcessingException contentProcessingFailed({
    required String url,
    String? pageId,
    String? details,
  }) {
    return ConfluenceContentProcessingException(
      'Failed to process content from Confluence page',
      originalUrl: url,
      pageId: pageId,
      technicalDetails: details,
      recoveryAction: 'Verify the page exists and is accessible with your credentials',
    );
  }

  /// Creates a publishing exception
  static ConfluencePublishingException publishingFailed({
    required String operation,
    String? pageId,
    String? details,
  }) {
    return ConfluencePublishingException(
      'Failed to $operation Confluence page',
      operation: operation,
      pageId: pageId,
      technicalDetails: details,
      recoveryAction: 'Check your permissions and ensure the target page/space is accessible',
    );
  }
}