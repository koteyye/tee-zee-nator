import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/material.dart';
import '../exceptions/confluence_exceptions.dart';

/// Centralized error handler service for Confluence operations
class ConfluenceErrorHandler {
  static const String _logTag = 'ConfluenceErrorHandler';
  
  // Rate limiting and backoff configuration
  static const int _maxRetryAttempts = 3;
  static const Duration _baseBackoffDelay = Duration(seconds: 1);
  static const Duration _maxBackoffDelay = Duration(seconds: 30);
  static const double _backoffMultiplier = 2.0;
  
  // Connection timeout configuration
  static const Duration _connectionTimeout = Duration(seconds: 30);
  static const Duration _readTimeout = Duration(seconds: 60);
  
  // Rate limiting tracking
  static final Map<String, DateTime> _lastRequestTimes = {};
  static final Map<String, int> _requestCounts = {};
  static const Duration _rateLimitWindow = Duration(minutes: 1);
  static const int _maxRequestsPerWindow = 60; // Conservative limit
  
  // Token error tracking
  static int _tokenErrorCount = 0;
  static const int _maxTokenErrors = 5;
  static DateTime? _lastTokenErrorTime;
  
  /// Handles Confluence exceptions with user-friendly error messages and recovery suggestions
  static Future<void> handleError(
    BuildContext context,
    ConfluenceException error, {
    String? operationContext,
    VoidCallback? onRetry,
    VoidCallback? onReconfigure,
    VoidCallback? onSkip,
    bool showAsDialog = true,
  }) async {
    // Log the error for debugging
    logError(error, context: operationContext);
    
    // Determine if this should be shown as dialog or snackbar
    final shouldShowDialog = showAsDialog || _shouldShowAsDialog(error);
    
    if (shouldShowDialog) {
      await _showErrorDialog(
        context,
        error,
        operationContext: operationContext,
        onRetry: onRetry,
        onReconfigure: onReconfigure,
        onSkip: onSkip,
      );
    } else {
      _showErrorSnackBar(
        context,
        error,
        onRetry: onRetry,
        onReconfigure: onReconfigure,
      );
    }
  }
  
  /// Executes an operation with automatic retry logic and error handling
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    String? operationName,
    int maxAttempts = _maxRetryAttempts,
    Duration? baseDelay,
    bool respectRateLimit = true,
  }) async {
    final effectiveBaseDelay = baseDelay ?? _baseBackoffDelay;
    Exception? lastException;
    
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // Check rate limiting before attempt
        if (respectRateLimit) {
          await _checkRateLimit(operationName ?? 'unknown');
        }
        
        // Log attempt
        if (operationName != null && attempt > 1) {
          logInfo('Retrying $operationName (attempt $attempt/$maxAttempts)');
        }
        
        // Execute operation
        final result = await operation();
        
        // Log success if this was a retry
        if (operationName != null && attempt > 1) {
          logInfo('$operationName succeeded on attempt $attempt');
        }
        
        return result;
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        
        // Log the attempt failure
        if (operationName != null) {
          logWarning('$operationName failed on attempt $attempt: ${e.toString()}');
        }
        
        // Don't retry for certain error types
        if (e is ConfluenceException && !_shouldRetry(e)) {
          logInfo('Not retrying due to error type: ${e.type}');
          break;
        }
        
        // Don't retry on last attempt
        if (attempt == maxAttempts) {
          break;
        }
        
        // Calculate backoff delay
        final delay = _calculateBackoffDelay(attempt, effectiveBaseDelay);
        logInfo('Waiting ${delay.inMilliseconds}ms before retry');
        await Future.delayed(delay);
      }
    }
    
    // All attempts failed, throw the last exception
    if (lastException != null) {
      if (operationName != null) {
        logError(lastException, context: '$operationName failed after $maxAttempts attempts');
      }
      throw lastException;
    }
    
    // This should never happen, but just in case
    throw Exception('Operation failed without exception');
  }
  
  /// Checks if an operation should respect rate limits and delays if necessary
  static Future<void> _checkRateLimit(String operationKey) async {
    final now = DateTime.now();
    final windowStart = now.subtract(_rateLimitWindow);
    
    // Clean old entries
    _lastRequestTimes.removeWhere((key, time) => time.isBefore(windowStart));
    _requestCounts.removeWhere((key, count) => !_lastRequestTimes.containsKey(key));
    
    // Check current request count for this operation
    final currentCount = _requestCounts[operationKey] ?? 0;
    
    if (currentCount >= _maxRequestsPerWindow) {
      final oldestRequest = _lastRequestTimes[operationKey];
      if (oldestRequest != null) {
        final waitTime = _rateLimitWindow - now.difference(oldestRequest);
        if (waitTime.inMilliseconds > 0) {
          logInfo('Rate limit reached for $operationKey, waiting ${waitTime.inMilliseconds}ms');
          await Future.delayed(waitTime);
        }
      }
    }
    
    // Update request tracking
    _lastRequestTimes[operationKey] = now;
    _requestCounts[operationKey] = (_requestCounts[operationKey] ?? 0) + 1;
  }
  
  /// Determines if an error should be retried
  static bool _shouldRetry(ConfluenceException error) {
    switch (error.type) {
      case ConfluenceErrorType.network:
      case ConfluenceErrorType.connection:
        return true;
      case ConfluenceErrorType.rateLimit:
        return true;
      case ConfluenceErrorType.authentication:
      case ConfluenceErrorType.authorization:
      case ConfluenceErrorType.validation:
        return false;
      case ConfluenceErrorType.contentProcessing:
      case ConfluenceErrorType.publishing:
      case ConfluenceErrorType.parsing:
        return true; // These might be transient
    }
  }
  
  /// Calculates exponential backoff delay with jitter
  static Duration _calculateBackoffDelay(int attempt, Duration baseDelay) {
    final exponentialDelay = baseDelay * pow(_backoffMultiplier, attempt - 1);
    final cappedDelay = Duration(
      milliseconds: min(exponentialDelay.inMilliseconds, _maxBackoffDelay.inMilliseconds),
    );
    
    // Add jitter (±25% of the delay)
    final jitterRange = cappedDelay.inMilliseconds * 0.25;
    final jitter = (Random().nextDouble() - 0.5) * 2 * jitterRange;
    final finalDelay = Duration(
      milliseconds: (cappedDelay.inMilliseconds + jitter).round(),
    );
    
    return finalDelay;
  }
  
  /// Determines if an error should be shown as a dialog vs snackbar
  static bool _shouldShowAsDialog(ConfluenceException error) {
    switch (error.type) {
      case ConfluenceErrorType.authentication:
      case ConfluenceErrorType.authorization:
      case ConfluenceErrorType.connection:
        return true; // Critical errors that need immediate attention
      case ConfluenceErrorType.validation:
        return true; // User needs to fix input
      case ConfluenceErrorType.contentProcessing:
      case ConfluenceErrorType.publishing:
        return true; // Important operation failures
      case ConfluenceErrorType.network:
      case ConfluenceErrorType.rateLimit:
      case ConfluenceErrorType.parsing:
        return false; // Can be shown as snackbar
    }
  }
  
  /// Shows error dialog with context-specific actions
  static Future<void> _showErrorDialog(
    BuildContext context,
    ConfluenceException error, {
    String? operationContext,
    VoidCallback? onRetry,
    VoidCallback? onReconfigure,
    VoidCallback? onSkip,
  }) async {
    final actions = <Widget>[];
    
    // Always add close button
    actions.add(
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Закрыть'),
      ),
    );
    
    // Add context-specific action buttons
    if (onSkip != null) {
      actions.insert(0, TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onSkip();
        },
        child: const Text('Пропустить'),
      ));
    }
    
    if (onRetry != null && _shouldRetry(error)) {
      actions.insert(0, TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onRetry();
        },
        child: const Text('Повторить'),
      ));
    }
    
    if (onReconfigure != null && _needsReconfiguration(error)) {
      actions.insert(0, TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onReconfigure();
        },
        child: const Text('Настройки'),
      ));
    }
    
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_getErrorTitle(error, operationContext)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error.getUserFriendlyMessage()),
                if (error.recoveryAction != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.blue.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error.recoveryAction!,
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (error.technicalDetails != null) ...[
                  const SizedBox(height: 16),
                  ExpansionTile(
                    title: const Text(
                      'Технические детали',
                      style: TextStyle(fontSize: 14),
                    ),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          error.technicalDetails!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: actions,
        );
      },
    );
  }
  
  /// Shows error snackbar for less critical errors
  static void _showErrorSnackBar(
    BuildContext context,
    ConfluenceException error, {
    VoidCallback? onRetry,
    VoidCallback? onReconfigure,
  }) {
    SnackBarAction? action;
    
    if (onRetry != null && _shouldRetry(error)) {
      action = SnackBarAction(
        label: 'Повторить',
        onPressed: onRetry,
      );
    } else if (onReconfigure != null && _needsReconfiguration(error)) {
      action = SnackBarAction(
        label: 'Настройки',
        onPressed: onReconfigure,
      );
    }
    
    final snackBar = SnackBar(
      content: Text(error.message),
      duration: const Duration(seconds: 6),
      action: action,
      backgroundColor: _getErrorColor(error),
    );
    
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
  
  /// Determines if an error requires reconfiguration
  static bool _needsReconfiguration(ConfluenceException error) {
    return error.type == ConfluenceErrorType.authentication ||
           error.type == ConfluenceErrorType.authorization ||
           error.type == ConfluenceErrorType.connection;
  }
  
  /// Gets appropriate error title based on error type and context
  static String _getErrorTitle(ConfluenceException error, String? context) {
    final baseTitle = switch (error.type) {
      ConfluenceErrorType.connection => 'Ошибка подключения к Confluence',
      ConfluenceErrorType.authentication => 'Ошибка аутентификации',
      ConfluenceErrorType.authorization => 'Недостаточно прав доступа',
      ConfluenceErrorType.contentProcessing => 'Ошибка обработки контента',
      ConfluenceErrorType.publishing => 'Ошибка публикации',
      ConfluenceErrorType.rateLimit => 'Превышен лимит запросов',
      ConfluenceErrorType.validation => 'Ошибка валидации',
      ConfluenceErrorType.network => 'Сетевая ошибка',
      ConfluenceErrorType.parsing => 'Ошибка обработки ответа',
    };
    
    if (context != null) {
      return '$baseTitle ($context)';
    }
    
    return baseTitle;
  }
  
  /// Gets appropriate color for error type
  static Color _getErrorColor(ConfluenceException error) {
    return switch (error.type) {
      ConfluenceErrorType.authentication ||
      ConfluenceErrorType.authorization ||
      ConfluenceErrorType.connection => Colors.red.shade700,
      ConfluenceErrorType.rateLimit => Colors.orange.shade600,
      ConfluenceErrorType.validation => Colors.amber.shade700,
      _ => Colors.red.shade600,
    };
  }
  
  /// Logs error with appropriate level and context
  static void logError(Exception error, {String? context}) {
    final message = _formatLogMessage(error, context);
    developer.log(
      message,
      name: _logTag,
      level: 1000, // Error level
      error: error,
    );
  }
  
  /// Logs warning message
  static void logWarning(String message, {String? context, dynamic details}) {
    final formattedMessage = context != null ? '$context: $message' : message;
    developer.log(
      formattedMessage,
      name: _logTag,
      level: 900, // Warning level
    );
    
    if (details != null) {
      developer.log(
        'Details: $details',
        name: _logTag,
        level: 900, // Warning level
      );
    }
  }
  
  /// Handles token decryption errors
  static String handleTokenError(String encryptedToken, dynamic error) {
    final now = DateTime.now();
    _tokenErrorCount++;
    _lastTokenErrorTime = now;
    
    // Log the error
    logError(Exception('Token decryption failed: $error'), 
      context: 'Token processing');
    
    // If we're seeing too many token errors, log a more severe warning
    if (_tokenErrorCount >= _maxTokenErrors) {
      logWarning('Multiple token decryption failures detected', 
        context: 'Authentication', 
        details: 'Count: $_tokenErrorCount, Consider resetting Confluence configuration');
    }
    
    // Return the original token as fallback
    return encryptedToken;
  }
  
  /// Gets a safe pattern representation of a token for logging
  static String _getTokenPattern(String token) {
    if (token.isEmpty) return 'empty';
    
    // Create a pattern that shows the structure without revealing the actual token
    final length = token.length;
    final prefix = length > 4 ? token.substring(0, 2) : '';
    final suffix = length > 4 ? token.substring(length - 2) : '';
    
    return '$prefix...($length chars)...$suffix';
  }
  
  /// Logs info message
  static void logInfo(String message, {String? context}) {
    final formattedMessage = context != null ? '$context: $message' : message;
    developer.log(
      formattedMessage,
      name: _logTag,
      level: 800, // Info level
    );
  }
  
  /// Logs debug message
  static void logDebug(String message, {String? context}) {
    final formattedMessage = context != null ? '$context: $message' : message;
    developer.log(
      formattedMessage,
      name: _logTag,
      level: 700, // Debug level
    );
  }
  
  /// Logs API request details
  static void logApiRequest(String method, String url, {Map<String, String>? headers}) {
    final sanitizedHeaders = headers != null ? _sanitizeHeaders(headers) : null;
    final message = 'API Request: $method $url';
    final details = sanitizedHeaders != null ? 'Headers: $sanitizedHeaders' : null;
    
    developer.log(
      details != null ? '$message\n$details' : message,
      name: _logTag,
      level: 700, // Debug level
    );
  }
  
  /// Logs API response details
  static void logApiResponse(String method, String url, int statusCode, {String? body}) {
    final message = 'API Response: $method $url -> $statusCode';
    final details = body != null ? 'Body: ${_truncateBody(body)}' : null;
    
    developer.log(
      details != null ? '$message\n$details' : message,
      name: _logTag,
      level: statusCode >= 400 ? 1000 : 700, // Error level for 4xx/5xx, debug otherwise
    );
  }
  
  /// Logs connection attempt
  static void logConnectionAttempt(String baseUrl, {String? token}) {
    final sanitizedToken = token != null ? _sanitizeToken(token) : null;
    final message = 'Attempting connection to: $baseUrl';
    final details = sanitizedToken != null ? 'Token: $sanitizedToken' : null;
    
    developer.log(
      details != null ? '$message\n$details' : message,
      name: _logTag,
      level: 800, // Info level
    );
  }
  
  /// Logs successful connection
  static void logConnectionSuccess(String baseUrl) {
    developer.log(
      'Successfully connected to: $baseUrl',
      name: _logTag,
      level: 800, // Info level
    );
  }
  
  /// Logs connection failure
  static void logConnectionFailure(String baseUrl, Exception error) {
    developer.log(
      'Connection failed to: $baseUrl\nError: ${error.toString()}',
      name: _logTag,
      level: 1000, // Error level
      error: error,
    );
  }
  
  /// Formats log message with error details
  static String _formatLogMessage(Exception error, String? context) {
    final buffer = StringBuffer();
    
    if (context != null) {
      buffer.writeln('Context: $context');
    }
    
    buffer.writeln('Error Type: ${error.runtimeType}');
    
    if (error is ConfluenceException) {
      buffer.writeln('Message: ${error.message}');
      buffer.writeln('Error Type: ${error.type}');
      
      if (error.technicalDetails != null) {
        buffer.writeln('Technical Details: ${error.technicalDetails}');
      }
      
      if (error.recoveryAction != null) {
        buffer.writeln('Recovery Action: ${error.recoveryAction}');
      }
      
      // Add specific error details
      if (error is ConfluenceConnectionException) {
        buffer.writeln('Base URL: ${error.baseUrl}');
        buffer.writeln('Status Code: ${error.statusCode}');
      } else if (error is ConfluenceRateLimitException) {
        buffer.writeln('Retry After: ${error.retryAfterSeconds}s');
        buffer.writeln('Remaining Requests: ${error.remainingRequests}');
      } else if (error is ConfluenceValidationException) {
        buffer.writeln('Field: ${error.fieldName}');
        buffer.writeln('Invalid Value: ${error.invalidValue}');
      }
    } else {
      buffer.writeln('Message: ${error.toString()}');
    }
    
    return buffer.toString();
  }
  
  /// Sanitizes headers for logging (removes sensitive information)
  static Map<String, String> _sanitizeHeaders(Map<String, String> headers) {
    final sanitized = <String, String>{};
    
    for (final entry in headers.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('authorization') || key.contains('token') || key.contains('key')) {
        sanitized[entry.key] = _sanitizeToken(entry.value);
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    
    return sanitized;
  }
  
  /// Sanitizes token for logging
  static String _sanitizeToken(String token) {
    if (token.length <= 8) {
      return '***';
    }
    return '${token.substring(0, 4)}***${token.substring(token.length - 4)}';
  }
  
  /// Truncates response body for logging
  static String _truncateBody(String body) {
    const maxLength = 500;
    if (body.length <= maxLength) {
      return body;
    }
    return '${body.substring(0, maxLength)}... [truncated ${body.length - maxLength} chars]';
  }
  
  /// Creates recovery suggestions based on error type
  static List<String> getRecoverySuggestions(ConfluenceException error) {
    return switch (error.type) {
      ConfluenceErrorType.connection => [
        'Проверьте подключение к интернету',
        'Убедитесь, что Base URL указан корректно',
        'Проверьте, доступен ли Confluence сервер',
        'Попробуйте подключиться через браузер',
      ],
      ConfluenceErrorType.authentication => [
        'Проверьте правильность API токена',
        'Убедитесь, что токен не истек',
        'Создайте новый API токен в настройках Confluence',
        'Проверьте права доступа для токена',
      ],
      ConfluenceErrorType.authorization => [
        'Обратитесь к администратору Confluence за правами доступа',
        'Убедитесь, что у вас есть права на чтение/запись в пространстве',
        'Проверьте права доступа к конкретной странице',
      ],
      ConfluenceErrorType.contentProcessing => [
        'Проверьте, что страница существует и доступна',
        'Убедитесь в корректности URL страницы',
        'Попробуйте обновить страницу в Confluence',
      ],
      ConfluenceErrorType.publishing => [
        'Проверьте права на создание/редактирование страниц',
        'Убедитесь, что родительская страница существует',
        'Проверьте, не заблокирована ли страница другим пользователем',
      ],
      ConfluenceErrorType.rateLimit => [
        'Подождите перед следующим запросом',
        'Уменьшите частоту операций с Confluence',
        'Обратитесь к администратору для увеличения лимитов',
      ],
      ConfluenceErrorType.validation => [
        'Проверьте корректность введенных данных',
        'Убедитесь в правильности формата URL',
        'Исправьте выделенные поля',
      ],
      ConfluenceErrorType.network => [
        'Проверьте подключение к интернету',
        'Попробуйте повторить операцию позже',
        'Проверьте настройки прокси или VPN',
      ],
      ConfluenceErrorType.parsing => [
        'Попробуйте повторить операцию',
        'Обратитесь в поддержку, если проблема повторяется',
        'Проверьте версию Confluence API',
      ],
    };
  }
  
  /// Validates operation parameters and throws appropriate exceptions
  static void validateOperation({
    String? baseUrl,
    String? token,
    String? pageUrl,
    String? content,
    bool allowEmpty = true,
  }) {
    if (baseUrl != null) {
      if (!allowEmpty && baseUrl.isEmpty) {
        throw ConfluenceExceptionFactory.invalidUrl(
          url: baseUrl,
          expectedFormat: 'https://your-domain.atlassian.net',
        );
      } else if (baseUrl.isNotEmpty) {
        final uri = Uri.tryParse(baseUrl);
        if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
          throw ConfluenceExceptionFactory.invalidUrl(
            url: baseUrl,
            expectedFormat: 'https://your-domain.atlassian.net',
          );
        }
      }
    }
    
    if (token != null && !allowEmpty && token.isEmpty) {
      throw ConfluenceExceptionFactory.authenticationFailed(
        details: 'Token cannot be empty',
      );
    }
    
    if (pageUrl != null && pageUrl.isNotEmpty) {
      final uri = Uri.tryParse(pageUrl);
      if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
        throw ConfluenceExceptionFactory.invalidUrl(
          url: pageUrl,
          expectedFormat: 'https://your-domain.atlassian.net/wiki/spaces/SPACE/pages/123456/Page+Title',
        );
      }
    }
    
    if (content != null && !allowEmpty && content.isEmpty) {
      throw ConfluenceValidationException(
        'Content cannot be empty',
        fieldName: 'content',
        invalidValue: content,
        recoveryAction: 'Provide content to publish',
      );
    }
  }
  
  /// Clears rate limiting data (useful for testing or reset)
  static void clearRateLimitData() {
    _lastRequestTimes.clear();
    _requestCounts.clear();
    logInfo('Rate limit data cleared');
  }
  
  /// Gets current rate limit status for debugging
  static Map<String, dynamic> getRateLimitStatus() {
    final now = DateTime.now();
    final windowStart = now.subtract(_rateLimitWindow);
    
    // Clean old entries first
    _lastRequestTimes.removeWhere((key, time) => time.isBefore(windowStart));
    _requestCounts.removeWhere((key, count) => !_lastRequestTimes.containsKey(key));
    
    return {
      'currentRequests': _requestCounts,
      'maxRequestsPerWindow': _maxRequestsPerWindow,
      'windowDurationMinutes': _rateLimitWindow.inMinutes,
      'lastRequestTimes': _lastRequestTimes.map(
        (key, value) => MapEntry(key, value.toIso8601String()),
      ),
    };
  }
}