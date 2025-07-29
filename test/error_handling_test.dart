import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import '../lib/services/error_handler_service.dart';
import '../lib/exceptions/content_processing_exceptions.dart';
import '../lib/widgets/main_screen/fallback_processor.dart';
import '../lib/widgets/main_screen/markdown_processor.dart';
import '../lib/widgets/main_screen/html_processor.dart';
import '../lib/widgets/main_screen/content_processor.dart';
import '../lib/models/output_format.dart';

void main() {
  group('ErrorHandlerService', () {
    test('should format error for logging correctly', () {
      final error = MarkdownProcessingException(
        'Test markdown error',
        recoveryAction: 'Try again',
        technicalDetails: 'Technical info',
      );
      
      final formatted = ErrorHandlerService.formatErrorForLogging(
        error,
        context: 'Test context',
      );
      
      expect(formatted, contains('Context: Test context'));
      expect(formatted, contains('Error Type: MarkdownProcessingException'));
      expect(formatted, contains('Message: Test markdown error'));
      expect(formatted, contains('Recovery Action: Try again'));
      expect(formatted, contains('Technical Details: Technical info'));
    });

    test('should determine dialog vs snackbar correctly', () {
      // Critical errors should show as dialog
      final criticalError = ContentExtractionException(
        'Critical extraction failure',
        'TestProcessor',
      );
      expect(ErrorHandlerService.shouldShowAsDialog(criticalError), isTrue);

      // Missing both markers is critical
      final bothMarkersMissing = EscapeMarkerException(
        'Both markers missing',
        'response',
        hasStartMarker: false,
        hasEndMarker: false,
        hasContent: false,
      );
      expect(ErrorHandlerService.shouldShowAsDialog(bothMarkersMissing), isTrue);

      // Missing one marker is not critical
      final oneMarkerMissing = EscapeMarkerException(
        'One marker missing',
        'response',
        hasStartMarker: true,
        hasEndMarker: false,
        hasContent: true,
      );
      expect(ErrorHandlerService.shouldShowAsDialog(oneMarkerMissing), isFalse);

      // Processing exceptions are critical
      final markdownError = MarkdownProcessingException('Markdown error');
      expect(ErrorHandlerService.shouldShowAsDialog(markdownError), isTrue);

      final htmlError = HtmlProcessingException('HTML error');
      expect(ErrorHandlerService.shouldShowAsDialog(htmlError), isTrue);
    });

    test('should provide format-specific error messages', () {
      final escapeMarkerError = EscapeMarkerException(
        'Markers missing',
        'response',
        hasStartMarker: false,
        hasEndMarker: false,
        hasContent: false,
      );
      
      final markdownMessage = ErrorHandlerService.getFormatSpecificErrorMessage(
        escapeMarkerError,
        'markdown',
      );
      expect(markdownMessage, contains('@@@START@@@'));
      expect(markdownMessage, contains('@@@END@@@'));
      expect(markdownMessage, contains('Markdown'));

      final formatError = ContentFormatException(
        'Wrong format',
        'HTML',
        'Markdown',
      );
      
      final formatMessage = ErrorHandlerService.getFormatSpecificErrorMessage(
        formatError,
        'HTML',
      );
      expect(formatMessage, contains('Markdown'));
      expect(formatMessage, contains('HTML'));
    });

    test('should validate LLM response correctly', () {
      // Empty response should throw
      expect(
        () => ErrorHandlerService.validateLLMResponse('', 'markdown'),
        throwsA(isA<LLMResponseValidationException>()),
      );

      // Too short response should throw
      expect(
        () => ErrorHandlerService.validateLLMResponse('short', 'markdown'),
        throwsA(isA<LLMResponseValidationException>()),
      );

      // Valid markdown response should not throw
      const validMarkdown = '''
        @@@START@@@
        # Test Document
        This is a test document with proper markdown formatting.
        @@@END@@@
      ''';
      expect(
        () => ErrorHandlerService.validateLLMResponse(validMarkdown, 'markdown'),
        returnsNormally,
      );

      // Invalid markdown (missing markers) should throw
      const invalidMarkdown = '''
        # Test Document
        This is missing escape markers.
      ''';
      expect(
        () => ErrorHandlerService.validateLLMResponse(invalidMarkdown, 'markdown'),
        throwsA(isA<EscapeMarkerException>()),
      );
    });

    test('should provide recovery suggestions based on error type', () {
      final escapeMarkerError = EscapeMarkerException(
        'Markers missing',
        'response',
        hasStartMarker: false,
        hasEndMarker: false,
        hasContent: false,
      );
      
      final suggestions = ErrorHandlerService.getRecoverySuggestions(escapeMarkerError);
      expect(suggestions, isNotEmpty);
      expect(suggestions.any((s) => s.contains('повторить')), isTrue);
      expect(suggestions.any((s) => s.contains('модели')), isTrue);

      final formatError = ContentFormatException(
        'Wrong format',
        'HTML',
        'Markdown',
      );
      
      final formatSuggestions = ErrorHandlerService.getRecoverySuggestions(formatError);
      expect(formatSuggestions, isNotEmpty);
      expect(formatSuggestions.any((s) => s.contains('формат')), isTrue);
    });
  });

  group('FallbackProcessor', () {
    test('should use primary processor when it succeeds', () {
      final mockProcessor = _MockContentProcessor();
      final fallbackProcessor = FallbackProcessor(
        targetFormat: OutputFormat.markdown,
        primaryProcessor: mockProcessor,
      );

      const testResponse = 'test response';
      const expectedResult = 'processed content';
      mockProcessor.setResult(expectedResult);

      final result = fallbackProcessor.extractContent(testResponse);
      expect(result, equals(expectedResult));
      expect(mockProcessor.wasCalledWith, equals(testResponse));
    });

    test('should attempt fallback when primary processor fails', () {
      final mockProcessor = _MockContentProcessor();
      mockProcessor.shouldThrow = true;
      
      final fallbackProcessor = FallbackProcessor(
        targetFormat: OutputFormat.markdown,
        primaryProcessor: mockProcessor,
      );

      // Test with markdown content that should be extractable by pattern
      const testResponse = '''
        # Technical Specification
        ## User Story
        As a user, I want to test fallback processing.
        
        ## Acceptance Criteria
        - The system should extract content
        - The system should format it properly
      ''';

      final result = fallbackProcessor.extractContent(testResponse);
      expect(result, isNotEmpty);
      expect(result, contains('Technical Specification'));
    });

    test('should convert between formats when cross-format extraction succeeds', () {
      final mockProcessor = _MockContentProcessor();
      mockProcessor.shouldThrow = true;
      
      final fallbackProcessor = FallbackProcessor(
        targetFormat: OutputFormat.confluence,
        primaryProcessor: mockProcessor,
      );

      // Test with HTML content for Confluence target
      const testResponse = '''
        <h1>Technical Specification</h1>
        <h2>User Story</h2>
        <p>As a user, I want to test cross-format extraction.</p>
        
        <h2>Acceptance Criteria</h2>
        <ul>
          <li>The system should extract HTML content</li>
          <li>The system should format it properly</li>
        </ul>
      ''';

      final result = fallbackProcessor.extractContent(testResponse);
      expect(result, isNotEmpty);
      expect(result, contains('<h1>'));
    });

    test('should handle lenient marker extraction for markdown', () {
      final mockProcessor = _MockContentProcessor();
      mockProcessor.shouldThrow = true;
      
      final fallbackProcessor = FallbackProcessor(
        targetFormat: OutputFormat.markdown,
        primaryProcessor: mockProcessor,
      );

      // Test with lenient markers
      const testResponse = '''
        Some text before
        @@@ START @@@
        # Technical Specification
        This is the actual content.
        @@@ END @@@
        Some text after
      ''';

      final result = fallbackProcessor.extractContent(testResponse);
      expect(result, isNotEmpty);
      expect(result, contains('Technical Specification'));
    });

    test('should format plain text appropriately for target format', () {
      final mockProcessor = _MockContentProcessor();
      mockProcessor.shouldThrow = true;
      
      final fallbackProcessor = FallbackProcessor(
        targetFormat: OutputFormat.markdown,
        primaryProcessor: mockProcessor,
      );

      const testResponse = '''
        This is a plain text response about user story requirements.
        The system should handle user authentication.
        Критерии приемки include proper validation.
      ''';

      final result = fallbackProcessor.extractContent(testResponse);
      expect(result, isNotEmpty);
      expect(result, contains('#')); // Should add markdown headers
    });

    test('should throw comprehensive failure exception when all strategies fail', () {
      final mockProcessor = _MockContentProcessor();
      mockProcessor.shouldThrow = true;
      
      final fallbackProcessor = FallbackProcessor(
        targetFormat: OutputFormat.markdown,
        primaryProcessor: mockProcessor,
      );

      // Use a very short response that won't trigger plain text extraction
      const testResponse = 'x';

      expect(
        () => fallbackProcessor.extractContent(testResponse),
        throwsA(isA<ContentExtractionException>()),
      );
    });

    test('should get correct file extension from primary processor', () {
      final mockProcessor = _MockContentProcessor();
      final fallbackProcessor = FallbackProcessor(
        targetFormat: OutputFormat.markdown,
        primaryProcessor: mockProcessor,
      );

      expect(fallbackProcessor.getFileExtension(), equals('test'));
      expect(fallbackProcessor.getContentType(), equals('test/type'));
    });
  });

  group('Enhanced Processor Error Handling', () {
    test('MarkdownProcessor should provide detailed error information', () {
      expect(
        () => MarkdownProcessor.extractMarkdown(''),
        throwsA(isA<MarkdownProcessingException>()),
      );

      expect(
        () => MarkdownProcessor.extractMarkdown('No markers here'),
        throwsA(isA<EscapeMarkerException>()),
      );

      expect(
        () => MarkdownProcessor.extractMarkdown('@@@START@@@@@@END@@@'),
        throwsA(isA<MarkdownProcessingException>()),
      );
    });

    test('HtmlProcessor should provide detailed error information', () {
      expect(
        () => HtmlProcessor.extractHtml(''),
        throwsA(isA<HtmlProcessingException>()),
      );

      expect(
        () => HtmlProcessor.extractHtml('No HTML tags here'),
        throwsA(isA<HtmlProcessingException>()),
      );

      // Test with malformed HTML that should trigger validation errors
      expect(
        () => HtmlProcessor.extractHtml('<<<<invalid>>>>'),
        throwsA(isA<HtmlProcessingException>()),
      );
    });

    test('should handle malformed escape markers correctly', () {
      const responses = [
        '@@@END@@@ content @@@START@@@', // Wrong order
        '@@@START@@@ @@@START@@@ content @@@END@@@', // Duplicate start
        '@@@START@@@ content @@@END@@@ @@@END@@@', // Duplicate end
        'START@@@ content @@@END', // Malformed markers
      ];

      for (final response in responses) {
        expect(
          () => MarkdownProcessor.extractMarkdown(response),
          throwsA(isA<EscapeMarkerException>()),
          reason: 'Should throw for response: $response',
        );
      }
    });

    test('should validate markdown content and remove HTML', () {
      const htmlInMarkdown = '''
        @@@START@@@
        # Test Document
        <div>This should be removed</div>
        <strong>This should stay</strong>
        <script>alert("bad")</script>
        @@@END@@@
      ''';

      final result = MarkdownProcessor.extractMarkdown(htmlInMarkdown);
      expect(result, isNot(contains('<div>')));
      expect(result, isNot(contains('<script>')));
      expect(result, contains('<strong>')); // Allowed tag
    });

    test('should handle HTML entities in markdown', () {
      const entitiesInMarkdown = '''
        @@@START@@@
        # Test &amp; Document
        Content with &lt;brackets&gt; and &quot;quotes&quot;
        @@@END@@@
      ''';

      final result = MarkdownProcessor.extractMarkdown(entitiesInMarkdown);
      expect(result, contains('Test & Document'));
      expect(result, contains('<brackets>'));
      expect(result, contains('"quotes"'));
    });
  });
}

/// Mock content processor for testing
class _MockContentProcessor implements ContentProcessor {
  String _result = 'mock result';
  bool shouldThrow = false;
  String? wasCalledWith;

  void setResult(String result) {
    _result = result;
  }

  @override
  String extractContent(String rawAiResponse) {
    wasCalledWith = rawAiResponse;
    
    if (shouldThrow) {
      throw ContentExtractionException(
        'Mock processor failure',
        'MockProcessor',
        recoveryAction: 'Try again',
        technicalDetails: 'Mock error for testing',
      );
    }
    
    return _result;
  }

  @override
  String getFileExtension() => 'test';

  @override
  String getContentType() => 'test/type';
}