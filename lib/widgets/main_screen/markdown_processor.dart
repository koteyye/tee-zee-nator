import 'content_processor.dart';
import '../../exceptions/content_processing_exceptions.dart';

/// Processor for Markdown format content from AI responses
class MarkdownProcessor implements ContentProcessor {
  @override
  String extractContent(String rawAiResponse) {
    try {
      return extractMarkdown(rawAiResponse);
    } on ContentProcessingException {
      rethrow;
    } catch (e) {
      throw ContentExtractionException(
        'Неожиданная ошибка при обработке Markdown контента',
        'MarkdownProcessor',
        recoveryAction: 'Попробуйте повторить генерацию или выберите другой формат',
        technicalDetails: e.toString(),
      );
    }
  }
  
  @override
  String getFileExtension() {
    return 'md';
  }
  
  @override
  String getContentType() {
    return 'text/markdown';
  }

  /// Extracts Markdown content from AI response between @@@START@@@ and @@@END@@@ markers
  /// Validates that the content is clean Markdown without HTML remnants
  static String extractMarkdown(String rawAiResponse) {
    if (rawAiResponse.isEmpty) {
      throw MarkdownProcessingException(
        'Получен пустой ответ от AI',
        recoveryAction: 'Попробуйте повторить генерацию с более детальными требованиями',
        technicalDetails: 'Raw AI response is empty',
      );
    }
    
    final text = rawAiResponse.trim();
    
    // Validate escape markers first
    final markerValidation = _validateEscapeMarkers(text);
    if (!markerValidation.isValid) {
      throw markerValidation.exception!;
    }
    
    // Look for content between escape markers with strict validation
    final strictPattern = RegExp(
      r'^.*?@@@START@@@\s*\n?(.*?)\n?\s*@@@END@@@\s*$',
      caseSensitive: true,
      multiLine: true,
      dotAll: true,
    );
    
    final match = strictPattern.firstMatch(text);
    if (match != null) {
      String markdownContent = match.group(1)?.trim() ?? '';
      
      if (markdownContent.isEmpty) {
        throw MarkdownProcessingException(
          'Контент между маркерами @@@START@@@ и @@@END@@@ пуст',
          recoveryAction: 'Попробуйте повторить генерацию или уточните требования',
          technicalDetails: 'Content between escape markers is empty',
        );
      }
      
      // Validate and clean the Markdown content
      try {
        markdownContent = _validateAndCleanMarkdown(markdownContent);
        return markdownContent;
      } catch (e) {
        // If validation fails, try fallback processing
        return _attemptFallbackProcessing(text, markdownContent);
      }
    }
    
    // If strict pattern fails, try fallback processing
    return _attemptFallbackProcessing(text, null);
  }
  
  /// Validates Markdown content and removes any HTML remnants
  static String _validateAndCleanMarkdown(String content) {
    // Check for common HTML tags that shouldn't be in Markdown
    final htmlTagPattern = RegExp(
      r'<(?!/?(?:code|pre|em|strong|a|img|br|hr)\b)[^>]+>',
      caseSensitive: false,
    );
    
    if (htmlTagPattern.hasMatch(content)) {
      // Remove HTML tags while preserving allowed ones
      content = _removeDisallowedHtmlTags(content);
    }
    
    // Clean up any HTML entities that might remain
    content = _cleanHtmlEntities(content);
    
    // Validate basic Markdown structure
    _validateMarkdownStructure(content);
    
    return content.trim();
  }
  
  /// Removes HTML tags that are not allowed in standard Markdown
  static String _removeDisallowedHtmlTags(String content) {
    // Allow only basic HTML tags that are commonly supported in Markdown
    final allowedTags = ['code', 'pre', 'em', 'strong', 'a', 'img', 'br', 'hr'];
    final allowedTagsPattern = allowedTags.join('|');
    
    // Remove all HTML tags except allowed ones
    final disallowedTagPattern = RegExp(
      r'<(?!/?(?:' + allowedTagsPattern + r')\b)[^>]+>',
      caseSensitive: false,
    );
    
    return content.replaceAll(disallowedTagPattern, '');
  }
  
  /// Cleans common HTML entities and converts them to Markdown equivalents
  static String _cleanHtmlEntities(String content) {
    final entityReplacements = {
      '&lt;': '<',
      '&gt;': '>',
      '&amp;': '&',
      '&quot;': '"',
      '&#39;': "'",
      '&nbsp;': ' ',
    };
    
    String cleaned = content;
    entityReplacements.forEach((entity, replacement) {
      cleaned = cleaned.replaceAll(entity, replacement);
    });
    
    return cleaned;
  }
  
  /// Validates basic Markdown structure
  static void _validateMarkdownStructure(String content) {
    // Check for basic Markdown elements to ensure it's valid
    final lines = content.split('\n');
    bool hasValidStructure = false;
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      
      // Check for common Markdown elements
      if (trimmedLine.startsWith('#') ||           // Headers
          trimmedLine.startsWith('*') ||           // Lists
          trimmedLine.startsWith('-') ||           // Lists
          trimmedLine.startsWith('1.') ||          // Numbered lists
          trimmedLine.contains('**') ||            // Bold
          trimmedLine.contains('*') ||             // Italic
          trimmedLine.startsWith('```') ||         // Code blocks
          trimmedLine.startsWith('`') ||           // Inline code
          trimmedLine.startsWith('>')) {           // Blockquotes
        hasValidStructure = true;
        break;
      }
    }
    
    if (!hasValidStructure && content.isNotEmpty) {
      // If no Markdown structure found but content exists, it might still be valid plain text
      // This is acceptable for Markdown
    }
  }
  
  /// Validates escape markers in the AI response
  static _MarkerValidationResult _validateEscapeMarkers(String text) {
    final hasStartMarker = text.contains('@@@START@@@');
    final hasEndMarker = text.contains('@@@END@@@');
    
    if (!hasStartMarker && !hasEndMarker) {
      return _MarkerValidationResult(
        isValid: false,
        exception: EscapeMarkerException(
          'Маркеры @@@START@@@ и @@@END@@@ не найдены в ответе AI',
          text,
          hasStartMarker: false,
          hasEndMarker: false,
          hasContent: false,
          recoveryAction: 'Попробуйте повторить генерацию. Если проблема повторяется, проверьте настройки модели AI',
          technicalDetails: 'Both escape markers are missing from AI response',
        ),
      );
    }
    
    if (!hasStartMarker) {
      return _MarkerValidationResult(
        isValid: false,
        exception: EscapeMarkerException(
          'Маркер @@@START@@@ не найден в ответе AI',
          text,
          hasStartMarker: false,
          hasEndMarker: hasEndMarker,
          hasContent: false,
          recoveryAction: 'Попробуйте повторить генерацию. Возможно, AI не следует инструкциям по форматированию',
          technicalDetails: 'Start marker @@@START@@@ is missing',
        ),
      );
    }
    
    if (!hasEndMarker) {
      return _MarkerValidationResult(
        isValid: false,
        exception: EscapeMarkerException(
          'Маркер @@@END@@@ не найден в ответе AI',
          text,
          hasStartMarker: hasStartMarker,
          hasEndMarker: false,
          hasContent: false,
          recoveryAction: 'Попробуйте повторить генерацию. Возможно, ответ был обрезан или AI не завершил генерацию',
          technicalDetails: 'End marker @@@END@@@ is missing',
        ),
      );
    }
    
    // Check marker order
    final startIndex = text.indexOf('@@@START@@@');
    final endIndex = text.indexOf('@@@END@@@');
    
    if (startIndex >= endIndex) {
      return _MarkerValidationResult(
        isValid: false,
        exception: EscapeMarkerException(
          'Маркеры @@@START@@@ и @@@END@@@ расположены в неправильном порядке',
          text,
          hasStartMarker: hasStartMarker,
          hasEndMarker: hasEndMarker,
          hasContent: false,
          recoveryAction: 'Попробуйте повторить генерацию. AI нарушил порядок маркеров',
          technicalDetails: 'Start marker appears after end marker',
        ),
      );
    }
    
    // Check for multiple markers - should be exactly one of each
    final startCount = '@@@START@@@'.allMatches(text).length;
    final endCount = '@@@END@@@'.allMatches(text).length;
    
    if (startCount > 1 || endCount > 1) {
      return _MarkerValidationResult(
        isValid: false,
        exception: EscapeMarkerException(
          'Найдено слишком много маркеров @@@START@@@ или @@@END@@@',
          text,
          hasStartMarker: hasStartMarker,
          hasEndMarker: hasEndMarker,
          hasContent: false,
          recoveryAction: 'Попробуйте повторить генерацию. AI добавил лишние маркеры',
          technicalDetails: 'Too many escape markers found: START=$startCount, END=$endCount',
        ),
      );
    }
    
    return _MarkerValidationResult(isValid: true);
  }
  
  /// Attempts fallback processing when strict pattern matching fails
  static String _attemptFallbackProcessing(String text, String? extractedContent) {
    // Try to extract content with more lenient pattern
    final lenientPattern = RegExp(
      r'@@@START@@@(.*?)@@@END@@@',
      caseSensitive: true,
      multiLine: true,
      dotAll: true,
    );
    
    final match = lenientPattern.firstMatch(text);
    if (match != null) {
      String content = match.group(1)?.trim() ?? '';
      
      if (content.isNotEmpty) {
        try {
          content = _validateAndCleanMarkdown(content);
          return content;
        } catch (e) {
          // If validation still fails, return raw content with warning
          throw MarkdownProcessingException(
            'Контент извлечен, но содержит ошибки форматирования',
            recoveryAction: 'Проверьте сгенерированный контент и отредактируйте вручную при необходимости',
            technicalDetails: 'Fallback processing succeeded but validation failed: $e',
          );
        }
      }
    }
    
    // Last resort: try to extract any meaningful content
    if (extractedContent != null && extractedContent.isNotEmpty) {
      throw MarkdownProcessingException(
        'Контент найден, но не прошел валидацию',
        recoveryAction: 'Попробуйте повторить генерацию или отредактируйте контент вручную',
        technicalDetails: 'Content validation failed, raw content available',
      );
    }
    
    // Complete failure
    throw ContentExtractionException(
      'Не удалось извлечь контент из ответа AI',
      'MarkdownProcessor',
      recoveryAction: 'Попробуйте повторить генерацию с другими параметрами или выберите формат Confluence',
      technicalDetails: 'All extraction methods failed',
    );
  }
}

/// Result of escape marker validation
class _MarkerValidationResult {
  final bool isValid;
  final EscapeMarkerException? exception;
  
  const _MarkerValidationResult({
    required this.isValid,
    this.exception,
  });
}