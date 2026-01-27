import 'package:flutter/material.dart';
import '../exceptions/content_processing_exceptions.dart';

/// Service for handling and displaying user-friendly error messages
class ErrorHandlerService {
  /// Shows an error dialog with user-friendly message and recovery suggestions
  static Future<void> showErrorDialog(
    BuildContext context,
    Exception error, {
    String? title,
    VoidCallback? onRetry,
    VoidCallback? onChangeFormat,
    VoidCallback? onOpenSettings,
    VoidCallback? onUseFallback,
    VoidCallback? onViewRawResponse,
  }) async {
    String userMessage;
    String? recoveryAction;
    String? technicalDetails;
    List<Widget> actions = [];

    // Extract error information based on exception type
    if (error is ContentProcessingException) {
      userMessage = error.message;
      recoveryAction = error.recoveryAction;
      technicalDetails = error.technicalDetails;
    } else {
      userMessage = 'Произошла неожиданная ошибка';
      technicalDetails = error.toString();
    }

    // Build action buttons based on error type and available callbacks
    actions.add(
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Закрыть'),
      ),
    );

    if (onRetry != null) {
      actions.insert(0, TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onRetry();
        },
        child: const Text('Повторить'),
      ));
    }

    if (error is ContentFormatException && onChangeFormat != null) {
      actions.insert(0, TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onChangeFormat();
        },
        child: const Text('Сменить формат'),
      ));
    }

    if ((error is LLMResponseValidationException && 
         error.message.contains('провайдер')) && onOpenSettings != null) {
      actions.insert(0, TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onOpenSettings();
        },
        child: const Text('Настройки'),
      ));
    }

    // Add fallback processing option for extraction failures
    if ((error is ContentExtractionException || 
         error is EscapeMarkerException ||
         error is MarkdownProcessingException ||
         error is HtmlProcessingException) && onUseFallback != null) {
      actions.insert(0, TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onUseFallback();
        },
        child: const Text('Попробовать восстановление'),
      ));
    }

    // Add raw response viewing for LLM validation errors
    if (error is LLMResponseValidationException && onViewRawResponse != null) {
      actions.insert(0, TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onViewRawResponse();
        },
        child: const Text('Показать ответ AI'),
      ));
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title ?? _getErrorTitle(error)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(userMessage),
                if (recoveryAction != null) ...[
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
                            recoveryAction,
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
                if (technicalDetails != null) ...[
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
                          technicalDetails,
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

  /// Shows a snackbar with error message for less critical errors
  static void showErrorSnackBar(
    BuildContext context,
    Exception error, {
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    String message;
    
    if (error is ContentProcessingException) {
      message = error.message;
    } else {
      message = 'Произошла ошибка: ${error.toString()}';
    }

    final snackBar = SnackBar(
      content: Text(message),
      duration: duration,
      action: action,
      backgroundColor: Colors.red.shade600,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  /// Gets appropriate error title based on exception type
  static String _getErrorTitle(Exception error) {
    if (error is MarkdownProcessingException) {
      return 'Ошибка обработки Markdown';
    } else if (error is HtmlProcessingException) {
      return 'Ошибка обработки HTML';
    } else if (error is EscapeMarkerException) {
      return 'Ошибка форматирования ответа AI';
    } else if (error is ContentFormatException) {
      return 'Ошибка формата контента';
    } else if (error is LLMResponseValidationException) {
      return 'Ошибка валидации ответа AI';
    } else if (error is ContentExtractionException) {
      return 'Ошибка извлечения контента';
    } else {
      return 'Ошибка';
    }
  }

  /// Creates a recovery action button for common error scenarios
  static SnackBarAction? createRecoveryAction(
    Exception error,
    VoidCallback? onRetry,
    VoidCallback? onChangeFormat,
  ) {
    if (error is EscapeMarkerException && onRetry != null) {
      return SnackBarAction(
        label: 'Повторить',
        onPressed: onRetry,
      );
    } else if (error is ContentFormatException && onChangeFormat != null) {
      return SnackBarAction(
        label: 'Сменить формат',
        onPressed: onChangeFormat,
      );
    }
    
    return null;
  }

  /// Determines if an error should be shown as dialog (critical) or snackbar (minor)
  static bool shouldShowAsDialog(Exception error) {
    // Check more specific exceptions first
    if (error is EscapeMarkerException) {
      // Missing both markers is critical
      return !error.hasStartMarker && !error.hasEndMarker;
    }
    
    if (error is LLMResponseValidationException) {
      // Service state errors are critical
      return error.message.contains('провайдер') || 
             error.message.contains('модель') ||
             error.message.contains('API') ||
             error.message.contains('инициализирован');
    }
    
    if (error is ContentExtractionException) {
      // Complete extraction failures are critical
      return true;
    }
    
    if (error is MarkdownProcessingException || error is HtmlProcessingException) {
      // Processing failures are generally critical
      return true;
    }
    
    // Other errors can be shown as snackbars
    return false;
  }

  /// Creates a formatted error message for logging
  static String formatErrorForLogging(Exception error, {String? context}) {
    final buffer = StringBuffer();
    
    if (context != null) {
      buffer.writeln('Context: $context');
    }
    
    buffer.writeln('Error Type: ${error.runtimeType}');
    
    if (error is ContentProcessingException) {
      buffer.writeln('Message: ${error.message}');
      if (error.recoveryAction != null) {
        buffer.writeln('Recovery Action: ${error.recoveryAction}');
      }
      if (error.technicalDetails != null) {
        buffer.writeln('Technical Details: ${error.technicalDetails}');
      }
      
      if (error is EscapeMarkerException) {
        buffer.writeln('Has Start Marker: ${error.hasStartMarker}');
        buffer.writeln('Has End Marker: ${error.hasEndMarker}');
        buffer.writeln('Has Content: ${error.hasContent}');
      }
      
      if (error is ContentFormatException) {
        buffer.writeln('Expected Format: ${error.expectedFormat}');
        buffer.writeln('Actual Format: ${error.actualFormat}');
      }
    } else {
      buffer.writeln('Message: ${error.toString()}');
    }
    
    return buffer.toString();
  }

  /// Shows a dialog with raw AI response for debugging purposes
  static Future<void> showRawResponseDialog(
    BuildContext context,
    String rawResponse, {
    String? title,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title ?? 'Ответ AI'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  rawResponse,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  /// Provides format-specific error messages for processing failures
  static String getFormatSpecificErrorMessage(Exception error, String format) {
    if (error is EscapeMarkerException) {
      if (format.toLowerCase() == 'markdown') {
        return 'AI не использовал маркеры @@@START@@@ и @@@END@@@ для Markdown контента. '
               'Это критично для корректной обработки Markdown формата.';
      } else {
        return 'Ошибка форматирования ответа AI для формата $format.';
      }
    }
    
    if (error is ContentFormatException) {
      return 'AI вернул контент в формате ${error.actualFormat}, '
             'но ожидался формат ${error.expectedFormat}. '
             'Попробуйте сменить формат или повторить генерацию.';
    }
    
    if (error is MarkdownProcessingException) {
      return 'Ошибка при обработке Markdown контента: ${error.message}. '
             'Возможно, AI включил HTML теги или некорректную разметку.';
    }
    
    if (error is HtmlProcessingException) {
      return 'Ошибка при обработке HTML контента: ${error.message}. '
             'Возможно, AI вернул некорректную HTML структуру.';
    }
    
    if (error is ContentProcessingException) {
      return error.message;
    }
    
    return 'Произошла ошибка при обработке контента в формате $format.';
  }

  /// Validates LLM response and provides specific error feedback
  static void validateLLMResponse(String response, String expectedFormat) {
    if (response.isEmpty) {
      throw LLMResponseValidationException(
        'AI вернул пустой ответ',
        response,
        recoveryAction: 'Попробуйте повторить генерацию с более детальными требованиями',
        technicalDetails: 'Empty response from LLM',
      );
    }
    
    if (response.length < 50) {
      throw LLMResponseValidationException(
        'AI вернул слишком короткий ответ (${response.length} символов)',
        response,
        recoveryAction: 'Попробуйте повторить генерацию с более детальными требованиями или проверьте настройки модели',
        technicalDetails: 'Response too short: ${response.length} characters',
      );
    }
    
    // Format-specific validation
    if (expectedFormat.toLowerCase() == 'markdown') {
      _validateMarkdownResponse(response);
    } else if (expectedFormat.toLowerCase() == 'html' || expectedFormat.toLowerCase() == 'confluence') {
      _validateHtmlResponse(response);
    }
    
    // Check for common AI errors
    _validateResponseForCommonErrors(response);
  }

  /// Validates Markdown-specific response format
  static void _validateMarkdownResponse(String response) {
    if (!response.contains('@@@START@@@')) {
      throw EscapeMarkerException(
        'Ответ AI не содержит начальный маркер @@@START@@@',
        response,
        hasStartMarker: false,
        hasEndMarker: response.contains('@@@END@@@'),
        hasContent: response.isNotEmpty,
        recoveryAction: 'Попробуйте повторить генерацию. AI не следует инструкциям по форматированию',
        technicalDetails: 'Missing @@@START@@@ marker in Markdown response',
      );
    }
    
    if (!response.contains('@@@END@@@')) {
      throw EscapeMarkerException(
        'Ответ AI не содержит конечный маркер @@@END@@@',
        response,
        hasStartMarker: response.contains('@@@START@@@'),
        hasEndMarker: false,
        hasContent: response.isNotEmpty,
        recoveryAction: 'Попробуйте повторить генерацию. Возможно, ответ был обрезан',
        technicalDetails: 'Missing @@@END@@@ marker in Markdown response',
      );
    }
    
    // Check marker order
    final startIndex = response.indexOf('@@@START@@@');
    final endIndex = response.indexOf('@@@END@@@');
    
    if (startIndex >= endIndex) {
      throw EscapeMarkerException(
        'Маркеры @@@START@@@ и @@@END@@@ расположены в неправильном порядке',
        response,
        hasStartMarker: true,
        hasEndMarker: true,
        hasContent: false,
        recoveryAction: 'Попробуйте повторить генерацию. AI нарушил порядок маркеров',
        technicalDetails: 'Start marker appears after end marker',
      );
    }
    
    // Check for content between markers
    final content = response.substring(startIndex + '@@@START@@@'.length, endIndex).trim();
    if (content.isEmpty) {
      throw EscapeMarkerException(
        'Контент между маркерами @@@START@@@ и @@@END@@@ пуст',
        response,
        hasStartMarker: true,
        hasEndMarker: true,
        hasContent: false,
        recoveryAction: 'Попробуйте повторить генерацию с более детальными требованиями',
        technicalDetails: 'Empty content between escape markers',
      );
    }
  }

  /// Validates HTML-specific response format
  static void _validateHtmlResponse(String response) {
    if (!response.contains('<') || !response.contains('>')) {
      throw ContentFormatException(
        'AI вернул ответ без HTML разметки для формата Confluence',
        'HTML',
        'Plain text',
        recoveryAction: 'Попробуйте повторить генерацию или выберите формат Markdown',
        technicalDetails: 'No HTML tags found in HTML response',
      );
    }
    
    if (!response.toLowerCase().contains('<h1')) {
      throw HtmlProcessingException(
        'AI не включил заголовок H1 в HTML ответ',
        recoveryAction: 'Попробуйте повторить генерацию. AI должен начинать с заголовка H1',
        technicalDetails: 'No H1 tag found in HTML response',
      );
    }
  }

  /// Validates response for common AI errors
  static void _validateResponseForCommonErrors(String response) {
    // Check for common AI refusal patterns
    final refusalPatterns = [
      'I cannot',
      'I\'m unable to',
      'I can\'t',
      'Sorry, I cannot',
      'I\'m not able to',
      'Я не могу',
      'Извините, я не могу',
      'К сожалению, я не могу',
    ];
    
    for (final pattern in refusalPatterns) {
      if (response.toLowerCase().contains(pattern.toLowerCase())) {
        throw LLMResponseValidationException(
          'AI отказался выполнить запрос',
          response,
          recoveryAction: 'Попробуйте переформулировать требования или использовать другую модель AI',
          technicalDetails: 'AI refusal pattern detected: $pattern',
        );
      }
    }
    
    // Check for incomplete responses only at the end of output
    final incompletePatterns = [
      '...',
      '[продолжение следует]',
      '[to be continued]',
      'и так далее',
      'etc.',
    ];
    final trimmed = response.trim();
    final lastLine = trimmed.split(RegExp(r'[\r\n]+')).last.trim().toLowerCase();
    for (final pattern in incompletePatterns) {
      final lowerPattern = pattern.toLowerCase();
      if (lastLine == lowerPattern || lastLine.endsWith(lowerPattern)) {
        throw LLMResponseValidationException(
          'AI вернул неполный ответ',
          response,
          recoveryAction: 'Попробуйте повторить генерацию или увеличьте лимит токенов в настройках',
          technicalDetails: 'Incomplete response pattern detected at end: $pattern',
        );
      }
    }
  }

  /// Creates recovery suggestions based on error type and context
  static List<String> getRecoverySuggestions(Exception error) {
    final suggestions = <String>[];
    
    if (error is EscapeMarkerException) {
      suggestions.addAll([
        'Попробуйте повторить генерацию',
        'Проверьте настройки AI модели',
        'Убедитесь, что модель поддерживает инструкции по форматированию',
      ]);
      
      if (!error.hasStartMarker && !error.hasEndMarker) {
        suggestions.add('Рассмотрите использование другой AI модели');
      }
    }
    
    if (error is ContentFormatException) {
      suggestions.addAll([
        'Смените формат вывода на ${error.actualFormat}',
        'Попробуйте повторить генерацию с уточненными требованиями',
        'Проверьте совместимость шаблона с выбранным форматом',
      ]);
    }
    
    if (error is MarkdownProcessingException) {
      suggestions.addAll([
        'Попробуйте формат Confluence вместо Markdown',
        'Повторите генерацию с более простыми требованиями',
        'Проверьте, не содержит ли шаблон HTML теги',
      ]);
    }
    
    if (error is HtmlProcessingException) {
      suggestions.addAll([
        'Попробуйте формат Markdown вместо HTML',
        'Повторите генерацию с указанием структуры документа',
        'Убедитесь, что AI модель поддерживает HTML генерацию',
      ]);
    }
    
    if (error is LLMResponseValidationException) {
      suggestions.addAll([
        'Проверьте подключение к интернету',
        'Убедитесь в корректности API ключей',
        'Попробуйте другую AI модель',
        'Увеличьте лимит токенов в настройках',
      ]);
    }
    
    if (error is ContentExtractionException) {
      suggestions.addAll([
        'Попробуйте использовать функцию восстановления контента',
        'Смените формат вывода',
        'Упростите требования для генерации',
        'Проверьте настройки AI провайдера',
      ]);
    }
    
    // Add general suggestions if no specific ones were added
    if (suggestions.isEmpty) {
      suggestions.addAll([
        'Попробуйте повторить операцию',
        'Проверьте настройки приложения',
        'Перезапустите приложение при необходимости',
      ]);
    }
    
    return suggestions;
  }
}