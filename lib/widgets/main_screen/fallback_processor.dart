import 'content_processor.dart';
import '../../exceptions/content_processing_exceptions.dart';
import '../../models/output_format.dart';
import 'markdown_processor.dart';
import 'html_processor.dart';

/// Fallback processor that attempts multiple extraction methods when primary processors fail
class FallbackProcessor implements ContentProcessor {
  final OutputFormat targetFormat;
  final ContentProcessor primaryProcessor;
  
  const FallbackProcessor({
    required this.targetFormat,
    required this.primaryProcessor,
  });
  
  @override
  String extractContent(String rawAiResponse) {
    try {
      // First attempt: use primary processor
      return primaryProcessor.extractContent(rawAiResponse);
    } on ContentProcessingException catch (primaryError) {
      // Primary processor failed, attempt fallback strategies
      return _attemptFallbackExtraction(rawAiResponse, primaryError);
    } catch (e) {
      // Unexpected error from primary processor
      throw ContentExtractionException(
        'Неожиданная ошибка в основном процессоре ${primaryProcessor.runtimeType}',
        'FallbackProcessor',
        recoveryAction: 'Попробуйте повторить генерацию или выберите другой формат',
        technicalDetails: 'Primary processor unexpected error: $e',
      );
    }
  }
  
  @override
  String getFileExtension() => primaryProcessor.getFileExtension();
  
  @override
  String getContentType() => primaryProcessor.getContentType();
  
  /// Attempts various fallback extraction methods
  String _attemptFallbackExtraction(String rawAiResponse, ContentProcessingException primaryError) {
    final fallbackStrategies = [
      _attemptCrossFormatExtraction,
      _attemptLenientMarkerExtraction,
      _attemptPatternBasedExtraction,
      _attemptPlainTextExtraction,
    ];
    
    ContentProcessingException? lastError = primaryError;
    
    for (final strategy in fallbackStrategies) {
      try {
        final result = strategy(rawAiResponse);
        if (result != null && result.isNotEmpty) {
          // Success with fallback strategy
          return result;
        }
      } on ContentProcessingException catch (e) {
        lastError = e;
        continue;
      } catch (e) {
        lastError = ContentExtractionException(
          'Ошибка в стратегии восстановления',
          'FallbackProcessor',
          recoveryAction: 'Попробуйте повторить генерацию',
          technicalDetails: 'Fallback strategy error: $e',
        );
        continue;
      }
    }
    
    // All fallback strategies failed
    throw _createComprehensiveFailureException(rawAiResponse, primaryError, lastError);
  }
  
  /// Attempts to extract content using the opposite format processor
  String? _attemptCrossFormatExtraction(String rawAiResponse) {
    try {
      ContentProcessor alternativeProcessor;
      
      switch (targetFormat) {
        case OutputFormat.markdown:
          // Try HTML extraction for Markdown target
          alternativeProcessor = HtmlProcessor();
          break;
        case OutputFormat.confluence:
          // Try Markdown extraction for HTML target
          alternativeProcessor = MarkdownProcessor();
          break;
      }
      
      final extractedContent = alternativeProcessor.extractContent(rawAiResponse);
      
      // Convert the content to target format
      return _convertBetweenFormats(extractedContent, alternativeProcessor, targetFormat);
      
    } catch (e) {
      // Cross-format extraction failed
      return null;
    }
  }
  
  /// Attempts extraction with more lenient marker patterns
  String? _attemptLenientMarkerExtraction(String rawAiResponse) {
    if (targetFormat != OutputFormat.markdown) {
      return null;
    }
    
    try {
      // Try various marker patterns with different spacing and case
      final lenientPatterns = [
        RegExp(r'@@@\s*START\s*@@@(.*?)@@@\s*END\s*@@@', caseSensitive: false, multiLine: true, dotAll: true),
        RegExp(r'@@START@@(.*?)@@END@@', caseSensitive: false, multiLine: true, dotAll: true),
        RegExp(r'START@@@(.*?)@@@END', caseSensitive: false, multiLine: true, dotAll: true),
        RegExp(r'<start>(.*?)</start>', caseSensitive: false, multiLine: true, dotAll: true),
      ];
      
      for (final pattern in lenientPatterns) {
        final match = pattern.firstMatch(rawAiResponse);
        if (match != null) {
          final content = match.group(1)?.trim() ?? '';
          if (content.isNotEmpty) {
            // Validate and clean the extracted content
            return _validateAndCleanExtractedContent(content, targetFormat);
          }
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Attempts extraction based on content patterns
  String? _attemptPatternBasedExtraction(String rawAiResponse) {
    try {
      switch (targetFormat) {
        case OutputFormat.markdown:
          return _extractMarkdownByPattern(rawAiResponse);
        case OutputFormat.confluence:
          return _extractHtmlByPattern(rawAiResponse);
      }
    } catch (e) {
      return null;
    }
  }
  
  /// Attempts to extract Markdown content by recognizing Markdown patterns
  String? _extractMarkdownByPattern(String rawAiResponse) {
    final lines = rawAiResponse.split('\n');
    final contentLines = <String>[];
    bool foundContent = false;
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      
      // Look for Markdown patterns
      if (trimmedLine.startsWith('#') ||           // Headers
          trimmedLine.startsWith('*') ||           // Lists
          trimmedLine.startsWith('-') ||           // Lists
          trimmedLine.startsWith('1.') ||          // Numbered lists
          trimmedLine.contains('**') ||            // Bold
          trimmedLine.startsWith('```') ||         // Code blocks
          trimmedLine.startsWith('>') ||           // Blockquotes
          (foundContent && trimmedLine.isNotEmpty)) { // Continue collecting content
        
        foundContent = true;
        contentLines.add(line);
      } else if (foundContent && trimmedLine.isEmpty) {
        // Keep empty lines within content
        contentLines.add(line);
      } else if (foundContent && 
                 (trimmedLine.toLowerCase().contains('техническое задание') ||
                  trimmedLine.toLowerCase().contains('technical specification'))) {
        // Found title, include it
        contentLines.insert(0, line);
      }
    }
    
    if (contentLines.isNotEmpty) {
      final content = contentLines.join('\n').trim();
      return _validateAndCleanExtractedContent(content, OutputFormat.markdown);
    }
    
    return null;
  }
  
  /// Attempts to extract HTML content by recognizing HTML patterns
  String? _extractHtmlByPattern(String rawAiResponse) {
    // Look for HTML structure
    final htmlTagPattern = RegExp(r'<[^>]+>', multiLine: true);
    if (!htmlTagPattern.hasMatch(rawAiResponse)) {
      return null;
    }
    
    // Find the start of meaningful HTML content
    final h1Pattern = RegExp(r'<h1[^>]*>.*?</h1>', caseSensitive: false, multiLine: true, dotAll: true);
    final match = h1Pattern.firstMatch(rawAiResponse);
    
    if (match != null) {
      final startIndex = match.start;
      final content = rawAiResponse.substring(startIndex).trim();
      return _validateAndCleanExtractedContent(content, OutputFormat.confluence);
    }
    
    // Look for any HTML content
    final firstTagIndex = rawAiResponse.indexOf('<');
    if (firstTagIndex >= 0) {
      final content = rawAiResponse.substring(firstTagIndex).trim();
      if (content.contains('</')) { // Has closing tags
        return _validateAndCleanExtractedContent(content, OutputFormat.confluence);
      }
    }
    
    return null;
  }
  
  /// Last resort: extract as plain text and format appropriately
  String? _attemptPlainTextExtraction(String rawAiResponse) {
    try {
      final cleanText = rawAiResponse.trim();
      
      if (cleanText.isEmpty || cleanText.length < 20) {
        return null;
      }
      
      // Remove common AI response prefixes
      String content = _removeAiResponsePrefixes(cleanText);
      
      // Format as appropriate for target format
      switch (targetFormat) {
        case OutputFormat.markdown:
          return _formatPlainTextAsMarkdown(content);
        case OutputFormat.confluence:
          return _formatPlainTextAsHtml(content);
      }
    } catch (e) {
      return null;
    }
  }
  
  /// Removes common AI response prefixes and suffixes
  String _removeAiResponsePrefixes(String content) {
    final prefixPatterns = [
      RegExp(r'^(Конечно[,!]?\s*)', caseSensitive: false),
      RegExp(r'^(Хорошо[,!]?\s*)', caseSensitive: false),
      RegExp(r'^(Вот\s+)', caseSensitive: false),
      RegExp(r'^(Я\s+создам\s+)', caseSensitive: false),
      RegExp(r'^(Sure[,!]?\s*)', caseSensitive: false),
      RegExp(r'^(Here\s+)', caseSensitive: false),
    ];
    
    String cleaned = content;
    for (final pattern in prefixPatterns) {
      cleaned = cleaned.replaceFirst(pattern, '');
    }
    
    return cleaned.trim();
  }
  
  /// Formats plain text as Markdown
  String _formatPlainTextAsMarkdown(String content) {
    final lines = content.split('\n');
    final formattedLines = <String>[];
    
    // Add main title if not present
    if (!content.toLowerCase().contains('техническое задание') &&
        !content.toLowerCase().contains('technical specification')) {
      formattedLines.add('# Техническое задание');
      formattedLines.add('');
    }
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      
      if (trimmedLine.isEmpty) {
        formattedLines.add('');
        continue;
      }
      
      // Try to identify structure and format accordingly
      if (trimmedLine.toLowerCase().contains('user story') ||
          trimmedLine.toLowerCase().contains('пользовательская история')) {
        formattedLines.add('## User Story');
        formattedLines.add('');
      } else if (trimmedLine.toLowerCase().contains('критерии приемки') ||
                 trimmedLine.toLowerCase().contains('acceptance criteria')) {
        formattedLines.add('## Критерии приемки');
        formattedLines.add('');
      } else if (trimmedLine.toLowerCase().contains('проблематика') ||
                 trimmedLine.toLowerCase().contains('problem')) {
        formattedLines.add('## Проблематика');
        formattedLines.add('');
      } else {
        formattedLines.add(line);
      }
    }
    
    return formattedLines.join('\n').trim();
  }
  
  /// Formats plain text as HTML
  String _formatPlainTextAsHtml(String content) {
    final lines = content.split('\n');
    final formattedLines = <String>[];
    
    // Add main title if not present
    if (!content.toLowerCase().contains('<h1') &&
        !content.toLowerCase().contains('техническое задание')) {
      formattedLines.add('<h1>Техническое задание</h1>');
      formattedLines.add('');
    }
    
    bool inParagraph = false;
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      
      if (trimmedLine.isEmpty) {
        if (inParagraph) {
          formattedLines.add('</p>');
          inParagraph = false;
        }
        formattedLines.add('');
        continue;
      }
      
      // Try to identify structure
      if (trimmedLine.toLowerCase().contains('user story') ||
          trimmedLine.toLowerCase().contains('пользовательская история')) {
        if (inParagraph) {
          formattedLines.add('</p>');
          inParagraph = false;
        }
        formattedLines.add('<h2>User Story</h2>');
      } else if (trimmedLine.toLowerCase().contains('критерии приемки') ||
                 trimmedLine.toLowerCase().contains('acceptance criteria')) {
        if (inParagraph) {
          formattedLines.add('</p>');
          inParagraph = false;
        }
        formattedLines.add('<h2>Критерии приемки</h2>');
      } else if (trimmedLine.toLowerCase().contains('проблематика') ||
                 trimmedLine.toLowerCase().contains('problem')) {
        if (inParagraph) {
          formattedLines.add('</p>');
          inParagraph = false;
        }
        formattedLines.add('<h2>Проблематика</h2>');
      } else {
        if (!inParagraph) {
          formattedLines.add('<p>');
          inParagraph = true;
        }
        formattedLines.add(line);
      }
    }
    
    if (inParagraph) {
      formattedLines.add('</p>');
    }
    
    return formattedLines.join('\n').trim();
  }
  
  /// Converts content between formats
  String _convertBetweenFormats(String content, ContentProcessor sourceProcessor, OutputFormat targetFormat) {
    if (sourceProcessor is MarkdownProcessor && targetFormat == OutputFormat.confluence) {
      return _convertMarkdownToHtml(content);
    } else if (sourceProcessor is HtmlProcessor && targetFormat == OutputFormat.markdown) {
      return _convertHtmlToMarkdown(content);
    }
    
    return content; // No conversion needed or possible
  }
  
  /// Converts Markdown content to HTML
  String _convertMarkdownToHtml(String markdownContent) {
    // Basic Markdown to HTML conversion
    String htmlContent = markdownContent;
    
    // Headers
    htmlContent = htmlContent.replaceAllMapped(
      RegExp(r'^(#{1,6})\s+(.+)$', multiLine: true),
      (match) {
        final level = match.group(1)!.length;
        final text = match.group(2)!;
        return '<h$level>$text</h$level>';
      },
    );
    
    // Bold
    htmlContent = htmlContent.replaceAllMapped(
      RegExp(r'\*\*([^*]+)\*\*'),
      (match) => '<strong>${match.group(1)}</strong>',
    );
    
    // Italic
    htmlContent = htmlContent.replaceAllMapped(
      RegExp(r'\*([^*]+)\*'),
      (match) => '<em>${match.group(1)}</em>',
    );
    
    // Lists (basic)
    htmlContent = htmlContent.replaceAllMapped(
      RegExp(r'^[-*+]\s+(.+)$', multiLine: true),
      (match) => '<li>${match.group(1)}</li>',
    );
    
    // Wrap list items in ul tags (simplified)
    if (htmlContent.contains('<li>')) {
      htmlContent = htmlContent.replaceAll(RegExp(r'(<li>.*?</li>)', dotAll: true), '<ul>\$1</ul>');
    }
    
    // Paragraphs (basic)
    final lines = htmlContent.split('\n');
    final processedLines = <String>[];
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isNotEmpty && 
          !trimmedLine.startsWith('<h') && 
          !trimmedLine.startsWith('<ul') && 
          !trimmedLine.startsWith('<li') &&
          !trimmedLine.startsWith('</')) {
        processedLines.add('<p>$line</p>');
      } else {
        processedLines.add(line);
      }
    }
    
    return processedLines.join('\n');
  }
  
  /// Converts HTML content to Markdown
  String _convertHtmlToMarkdown(String htmlContent) {
    // Basic HTML to Markdown conversion
    String markdownContent = htmlContent;
    
    // Headers
    for (int i = 1; i <= 6; i++) {
      markdownContent = markdownContent.replaceAllMapped(
        RegExp('<h$i[^>]*>(.*?)</h$i>', caseSensitive: false, dotAll: true),
        (match) => '${'#' * i} ${match.group(1)?.trim() ?? ''}',
      );
    }
    
    // Bold
    markdownContent = markdownContent.replaceAllMapped(
      RegExp(r'<strong[^>]*>(.*?)</strong>', caseSensitive: false, dotAll: true),
      (match) => '**${match.group(1)}**',
    );
    
    // Italic
    markdownContent = markdownContent.replaceAllMapped(
      RegExp(r'<em[^>]*>(.*?)</em>', caseSensitive: false, dotAll: true),
      (match) => '*${match.group(1)}*',
    );
    
    // Lists
    markdownContent = markdownContent.replaceAllMapped(
      RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
      (match) => '- ${match.group(1)?.trim() ?? ''}',
    );
    
    // Remove ul/ol tags
    markdownContent = markdownContent.replaceAll(RegExp(r'</?[uo]l[^>]*>', caseSensitive: false), '');
    
    // Paragraphs
    markdownContent = markdownContent.replaceAllMapped(
      RegExp(r'<p[^>]*>(.*?)</p>', caseSensitive: false, dotAll: true),
      (match) => '${match.group(1)?.trim() ?? ''}\n',
    );
    
    // Clean up remaining HTML tags
    markdownContent = markdownContent.replaceAll(RegExp(r'<[^>]+>'), '');
    
    // Clean up excessive whitespace
    markdownContent = markdownContent.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');
    
    return markdownContent.trim();
  }
  
  /// Validates and cleans extracted content
  String _validateAndCleanExtractedContent(String content, OutputFormat format) {
    if (content.isEmpty) {
      throw ContentExtractionException(
        'Извлеченный контент пуст',
        'FallbackProcessor',
        recoveryAction: 'Попробуйте повторить генерацию с более детальными требованиями',
        technicalDetails: 'Extracted content is empty',
      );
    }
    
    switch (format) {
      case OutputFormat.markdown:
        return _validateMarkdownContent(content);
      case OutputFormat.confluence:
        return _validateHtmlContent(content);
    }
  }
  
  /// Validates Markdown content
  String _validateMarkdownContent(String content) {
    // Remove any HTML tags that shouldn't be in Markdown
    final htmlTagPattern = RegExp(r'<(?!/?(?:code|pre|em|strong|a|img|br|hr)\b)[^>]+>', caseSensitive: false);
    String cleanContent = content.replaceAll(htmlTagPattern, '');
    
    // Clean up HTML entities
    final entityReplacements = {
      '&lt;': '<',
      '&gt;': '>',
      '&amp;': '&',
      '&quot;': '"',
      '&#39;': "'",
      '&nbsp;': ' ',
    };
    
    entityReplacements.forEach((entity, replacement) {
      cleanContent = cleanContent.replaceAll(entity, replacement);
    });
    
    return cleanContent.trim();
  }
  
  /// Validates HTML content
  String _validateHtmlContent(String content) {
    // Ensure basic HTML structure
    if (!content.contains('<') || !content.contains('>')) {
      throw ContentFormatException(
        'Контент не содержит HTML разметки',
        'HTML',
        'Plain text',
        recoveryAction: 'Попробуйте выбрать формат Markdown или повторить генерацию',
        technicalDetails: 'No HTML tags found in content',
      );
    }
    
    // Clean up common issues
    String cleanContent = content;
    
    // Fix double-encoded entities
    cleanContent = cleanContent.replaceAll('&amp;amp;', '&amp;');
    cleanContent = cleanContent.replaceAll('&lt;lt;', '&lt;');
    cleanContent = cleanContent.replaceAll('&gt;gt;', '&gt;');
    
    // Remove excessive whitespace
    cleanContent = cleanContent.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');
    
    return cleanContent.trim();
  }
  
  /// Creates a comprehensive failure exception with all attempted strategies
  ContentExtractionException _createComprehensiveFailureException(
    String rawAiResponse,
    ContentProcessingException primaryError,
    ContentProcessingException? lastFallbackError,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('Все методы извлечения контента не удались:');
    buffer.writeln('1. Основной процессор (${primaryProcessor.runtimeType}): ${primaryError.message}');
    
    if (lastFallbackError != null) {
      buffer.writeln('2. Резервные стратегии: ${lastFallbackError.message}');
    }
    
    String recoveryAction = 'Попробуйте следующие действия:\n';
    recoveryAction += '• Повторите генерацию с более детальными требованиями\n';
    recoveryAction += '• Выберите другой формат вывода\n';
    recoveryAction += '• Проверьте настройки AI модели\n';
    recoveryAction += '• Попробуйте другую AI модель';
    
    final technicalDetails = '$buffer\n\nResponse length: ${rawAiResponse.length} characters';
    
    return ContentExtractionException(
      'Критическая ошибка: не удалось извлечь контент ни одним из доступных методов',
      'FallbackProcessor',
      recoveryAction: recoveryAction,
      technicalDetails: technicalDetails,
    );
  }
}