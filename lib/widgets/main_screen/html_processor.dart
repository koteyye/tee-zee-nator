import 'content_processor.dart';
import '../../exceptions/content_processing_exceptions.dart';

/// Утилиты для обработки HTML контента от AI
class HtmlProcessor implements ContentProcessor {
  @override
  String extractContent(String rawAiResponse) {
    try {
      return extractHtml(rawAiResponse);
    } on ContentProcessingException {
      rethrow;
    } catch (e) {
      throw ContentExtractionException(
        'Неожиданная ошибка при обработке HTML контента',
        'HtmlProcessor',
        recoveryAction: 'Попробуйте повторить генерацию или выберите формат Markdown',
        technicalDetails: e.toString(),
      );
    }
  }
  
  @override
  String getFileExtension() {
    return 'html';
  }
  
  @override
  String getContentType() {
    return 'text/html';
  }

  /// Извлекает HTML-документ из ответа AI
  /// Ищет тег <h1>Техническое задание</h1> и возвращает всё с этого места
  static String extractHtml(String rawAiResponse) {
    if (rawAiResponse.isEmpty) {
      throw HtmlProcessingException(
        'Получен пустой ответ от AI',
        recoveryAction: 'Попробуйте повторить генерацию с более детальными требованиями',
        technicalDetails: 'Raw AI response is empty',
      );
    }
    
    final text = rawAiResponse.trim();
    
    // Validate basic HTML structure
    _validateBasicHtmlStructure(text);
    
    // Ищем начало HTML-документа с заголовком "Техническое задание"
    final h1Pattern = RegExp(r'<h1[^>]*>.*?[Тт]ехническое\s+задание.*?</h1>', 
                              caseSensitive: false, 
                              multiLine: true, 
                              dotAll: true);
    
    final match = h1Pattern.firstMatch(text);
    if (match != null) {
      final htmlStartIndex = match.start;
      String htmlContent = text.substring(htmlStartIndex);
      
      // Validate and clean HTML content
      htmlContent = _validateAndCleanHtml(htmlContent);
      
      return htmlContent.trim();
    }
    
    // Если не нашли стандартный заголовок, ищем любой <h1>
    final anyH1Pattern = RegExp(r'<h1[^>]*>.*?</h1>', 
                               caseSensitive: false, 
                               multiLine: true, 
                               dotAll: true);
    
    final anyH1Match = anyH1Pattern.firstMatch(text);
    if (anyH1Match != null) {
      final htmlStartIndex = anyH1Match.start;
      String htmlContent = text.substring(htmlStartIndex);
      
      // Добавляем стандартный заголовок, если его нет
      if (!htmlContent.toLowerCase().contains('техническое задание')) {
        htmlContent = '<h1>Техническое задание</h1>\n\n$htmlContent';
      }
      
      // Validate and clean HTML content
      htmlContent = _validateAndCleanHtml(htmlContent);
      
      return htmlContent.trim();
    }
    
    // Try fallback processing
    return _attemptFallbackProcessing(text);
  }
  
  /// Validates basic HTML structure in the response
  static void _validateBasicHtmlStructure(String text) {
    // Check for basic HTML elements
    if (!text.contains('<') || !text.contains('>')) {
      throw HtmlProcessingException(
        'Ответ не содержит HTML разметки',
        recoveryAction: 'Попробуйте повторить генерацию или выберите формат Markdown',
        technicalDetails: 'No HTML tags found in response',
      );
    }
    
    // Check for malformed HTML tags
    final malformedTagPattern = RegExp(r'<[^>]*<|>[^<]*>');
    if (malformedTagPattern.hasMatch(text)) {
      throw HtmlProcessingException(
        'Обнаружены некорректные HTML теги',
        recoveryAction: 'Попробуйте повторить генерацию. AI сгенерировал некорректную HTML разметку',
        technicalDetails: 'Malformed HTML tags detected',
      );
    }
  }
  
  /// Validates and cleans HTML content
  static String _validateAndCleanHtml(String htmlContent) {
    // Remove extra text after closing body/html tags
    final bodyEndPattern = RegExp(r'</body>\s*</html>.*$', 
                                 caseSensitive: false, 
                                 multiLine: true, 
                                 dotAll: true);
    htmlContent = htmlContent.replaceAll(bodyEndPattern, '</body></html>');
    
    // Validate HTML structure
    _validateHtmlTags(htmlContent);
    
    // Clean up common issues
    htmlContent = _cleanHtmlContent(htmlContent);
    
    return htmlContent;
  }
  
  /// Validates HTML tag structure
  static void _validateHtmlTags(String htmlContent) {
    // Check for unclosed tags (basic validation)
    final openTags = <String>[];
    final tagPattern = RegExp(r'<(/?)(\w+)[^>]*>');
    
    for (final match in tagPattern.allMatches(htmlContent)) {
      final isClosing = match.group(1) == '/';
      final tagName = match.group(2)?.toLowerCase() ?? '';
      
      // Skip self-closing tags
      if (['br', 'hr', 'img', 'input', 'meta', 'link'].contains(tagName)) {
        continue;
      }
      
      if (isClosing) {
        if (openTags.isEmpty || openTags.last != tagName) {
          // Don't throw error for minor tag mismatches, just log
          continue;
        }
        openTags.removeLast();
      } else {
        openTags.add(tagName);
      }
    }
    
    // If too many unclosed tags, warn but don't fail
    if (openTags.length > 3) {
      throw HtmlProcessingException(
        'Обнаружено много незакрытых HTML тегов',
        recoveryAction: 'Попробуйте повторить генерацию. AI сгенерировал некорректную HTML структуру',
        technicalDetails: 'Unclosed tags: ${openTags.join(', ')}',
      );
    }
  }
  
  /// Cleans HTML content from common issues
  static String _cleanHtmlContent(String htmlContent) {
    // Remove any text before first HTML tag
    final firstTagIndex = htmlContent.indexOf('<');
    if (firstTagIndex > 0) {
      htmlContent = htmlContent.substring(firstTagIndex);
    }
    
    // Clean up excessive whitespace
    htmlContent = htmlContent.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');
    
    // Fix common HTML entity issues
    htmlContent = htmlContent.replaceAll('&amp;amp;', '&amp;');
    htmlContent = htmlContent.replaceAll('&lt;lt;', '&lt;');
    htmlContent = htmlContent.replaceAll('&gt;gt;', '&gt;');
    
    return htmlContent;
  }
  
  /// Attempts fallback processing when standard patterns fail
  static String _attemptFallbackProcessing(String text) {
    // If no HTML structure found, try to create basic HTML
    if (!text.contains('<h1')) {
      if (text.isNotEmpty) {
        // Try to detect if it's plain text that should be HTML
        final lines = text.split('\n');
        final hasStructure = lines.any((line) => 
          line.trim().startsWith('#') || 
          line.trim().startsWith('*') || 
          line.trim().startsWith('-') ||
          line.trim().startsWith('1.')
        );
        
        if (hasStructure) {
          throw ContentFormatException(
            'Получен контент в формате Markdown вместо HTML',
            'HTML',
            'Markdown',
            recoveryAction: 'Выберите формат Markdown или попробуйте повторить генерацию с форматом HTML',
            technicalDetails: 'Response appears to be in Markdown format',
          );
        }
        
        // Wrap plain text in basic HTML structure
        return '<h1>Техническое задание</h1>\n\n<p>${text.replaceAll('\n\n', '</p>\n\n<p>')}</p>';
      }
    }
    
    // Complete failure
    throw ContentExtractionException(
      'Не удалось извлечь HTML контент из ответа AI',
      'HtmlProcessor',
      recoveryAction: 'Попробуйте повторить генерацию с другими параметрами или выберите формат Markdown',
      technicalDetails: 'All HTML extraction methods failed',
    );
  }
}