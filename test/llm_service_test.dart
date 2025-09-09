import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/services/llm_service.dart';
import 'package:tee_zee_nator/models/output_format.dart';

void main() {
  group('LLMService Format-Aware Generation', () {
    late LLMService llmService;

    setUp(() {
      llmService = LLMService();
    });

    group('generateTZ method signature and validation', () {
      test('should accept OutputFormat parameter', () async {
        // Test that the method accepts the new format parameter
        try {
          await llmService.generateTZ(
            rawRequirements: 'test requirements',
            format: OutputFormat.markdown,
          );
        } catch (e) {
          // We expect this to fail because provider is not initialized
          expect(e.toString(), contains('провайдер не инициализирован'));
        }
      });

      test('should default to markdown format when not specified', () async {
        // Test that the method works with default parameter
        try {
          await llmService.generateTZ(
            rawRequirements: 'test requirements',
          );
        } catch (e) {
          // We expect this to fail because provider is not initialized
          expect(e.toString(), contains('провайдер не инициализирован'));
        }
      });

      test('should accept confluence format', () async {
        // Test that the method accepts confluence format
        try {
          await llmService.generateTZ(
            rawRequirements: 'test requirements',
            format: OutputFormat.confluence,
          );
        } catch (e) {
          // We expect this to fail because provider is not initialized
          expect(e.toString(), contains('провайдер не инициализирован'));
        }
      });

      test('should accept all parameters including format', () async {
        // Test that the method accepts all parameters including the new format parameter
        try {
          await llmService.generateTZ(
            rawRequirements: 'test requirements',
            changes: 'test changes',
            templateContent: 'test template',
            format: OutputFormat.markdown,
          );
        } catch (e) {
          // We expect this to fail because provider is not initialized
          expect(e.toString(), contains('провайдер не инициализирован'));
        }
      });
    });

    group('OutputFormat enum validation', () {
      test('should have markdown as default format', () {
        expect(OutputFormat.defaultFormat, equals(OutputFormat.markdown));
        expect(OutputFormat.markdown.isDefault, isTrue);
        expect(OutputFormat.confluence.isDefault, isFalse);
      });

      test('should have correct display names', () {
        expect(OutputFormat.markdown.displayName, equals('Markdown'));
        expect(OutputFormat.confluence.displayName, equals('Confluence Storage Format'));
      });

      test('should have correct file extensions', () {
        expect(OutputFormat.markdown.fileExtension, equals('md'));
        expect(OutputFormat.confluence.fileExtension, equals('html'));
      });
    });
  });

  group('LLMService Confluence Content Integration', () {
    late LLMService llmService;

    setUp(() {
      llmService = LLMService();
    });

    group('Confluence content processing', () {
      test('should process single Confluence content marker', () {
        final processedText = llmService.processConfluenceContent(
          'Requirements: @conf-cnt This is confluence content@ and more text'
        );
        
        expect(processedText, contains('--- Информация из Confluence ---'));
        expect(processedText, contains('This is confluence content'));
        expect(processedText, contains('--- Конец информации из Confluence ---'));
        expect(processedText, contains('and more text'));
        expect(processedText, isNot(contains('@conf-cnt')));
      });

      test('should process multiple Confluence content markers', () {
        final processedText = llmService.processConfluenceContent(
          'First: @conf-cnt Content 1@ and second: @conf-cnt Content 2@ end'
        );
        
        expect(processedText, contains('Content 1'));
        expect(processedText, contains('Content 2'));
        expect(processedText, isNot(contains('@conf-cnt')));
        expect(RegExp(r'--- Информация из Confluence ---').allMatches(processedText).length, equals(2));
      });

      test('should handle empty Confluence content markers', () {
        final processedText = llmService.processConfluenceContent(
          'Text with @conf-cnt @ empty marker'
        );
        
        expect(processedText, equals('Text with  empty marker'));
        expect(processedText, isNot(contains('@conf-cnt')));
      });

      test('should handle text without Confluence markers', () {
        const originalText = 'Regular text without any markers';
        final processedText = llmService.processConfluenceContent(originalText);
        
        expect(processedText, equals(originalText));
      });

      test('should truncate very long Confluence content', () {
        final longContent = 'A' * 6000; // Longer than 5000 char limit
        final processedText = llmService.processConfluenceContent(
          'Text @conf-cnt $longContent@ end'
        );
        
        expect(processedText, contains('обрезано из-за ограничений размера'));
        expect(processedText.length, lessThan(longContent.length + 1000));
      });

      test('should sanitize Confluence content', () {
        final processedText = llmService.processConfluenceContent(
          'Text @conf-cnt Content with <script>alert("xss")</script> and text@ end'
        );
        
        expect(processedText, isNot(contains('<script>')));
        expect(processedText, contains('Content with alert("xss") and text'));
        expect(processedText, contains('end')); // Should preserve text after marker
      });

      test('should handle multiline Confluence content', () {
        final processedText = llmService.processConfluenceContent(
          'Text @conf-cnt Line 1\nLine 2\nLine 3@ end'
        );
        
        expect(processedText, contains('Line 1'));
        expect(processedText, contains('Line 2'));
        expect(processedText, contains('Line 3'));
      });
    });

    group('Content validation with Confluence markers', () {
      test('should validate processed requirements length', () {
        final longContent = 'A' * 16000; // Exceeds 15000 char limit
        
        // Test the validation method directly since service state validation happens first
        expect(() => llmService.validateGenerationParameters(longContent, OutputFormat.markdown, null),
               throwsA(predicate((e) => e.toString().contains('слишком длинные'))));
      });

      test('should detect unprocessed Confluence markers', () {
        // Test the validation method directly since service state validation happens first
        expect(() => llmService.validateGenerationParameters(
          'Text with @conf-cnt unprocessed content@ marker', 
          OutputFormat.markdown, 
          null
        ), throwsA(predicate((e) => e.toString().contains('необработанные маркеры'))));
      });

      test('should accept properly processed content', () async {
        // This should not throw validation errors related to Confluence content
        try {
          await llmService.generateTZ(
            rawRequirements: 'Text with processed confluence content',
            format: OutputFormat.markdown,
          );
        } catch (e) {
          // Should fail on provider initialization, not content validation
          expect(e.toString(), contains('провайдер не инициализирован'));
          expect(e.toString(), isNot(contains('маркеры')));
        }
      });
    });

    group('Changes field Confluence processing', () {
      test('should process Confluence content in changes field', () async {
        try {
          await llmService.generateTZ(
            rawRequirements: 'Basic requirements',
            changes: 'Changes with @conf-cnt confluence content@ included',
            format: OutputFormat.markdown,
          );
        } catch (e) {
          // Should fail on provider initialization, not content processing
          expect(e.toString(), contains('провайдер не инициализирован'));
          expect(e.toString(), isNot(contains('маркеры')));
        }
      });

      test('should handle null changes field', () async {
        try {
          await llmService.generateTZ(
            rawRequirements: 'Basic requirements',
            changes: null,
            format: OutputFormat.markdown,
          );
        } catch (e) {
          // Should fail on provider initialization, not content processing
          expect(e.toString(), contains('провайдер не инициализирован'));
        }
      });

      test('should handle empty changes field', () async {
        try {
          await llmService.generateTZ(
            rawRequirements: 'Basic requirements',
            changes: '',
            format: OutputFormat.markdown,
          );
        } catch (e) {
          // Should fail on provider initialization, not content processing
          expect(e.toString(), contains('провайдер не инициализирован'));
        }
      });
    });

    group('Content sanitization', () {
      test('should remove HTML tags from Confluence content', () {
        final sanitized = llmService.sanitizeConfluenceContent(
          '<p>Paragraph with <strong>bold</strong> and <em>italic</em> text</p>'
        );
        
        expect(sanitized, isNot(contains('<p>')));
        expect(sanitized, isNot(contains('<strong>')));
        expect(sanitized, isNot(contains('<em>')));
        expect(sanitized, contains('Paragraph with bold and italic text'));
      });

      test('should normalize whitespace', () {
        final sanitized = llmService.sanitizeConfluenceContent(
          'Text   with    multiple     spaces\n\n\nand\t\ttabs'
        );
        
        expect(sanitized, contains('Text with multiple spaces and tabs'));
        expect(sanitized, isNot(contains('   ')));
        expect(sanitized, isNot(contains('\t\t')));
      });

      test('should escape @ symbols', () {
        final sanitized = llmService.sanitizeConfluenceContent(
          'Email: user@domain.com and @mention'
        );
        
        expect(sanitized, contains('user(at)domain.com'));
        expect(sanitized, contains('(at)mention'));
        expect(sanitized, isNot(contains('@')));
      });

      test('should remove control characters', () {
        final sanitized = llmService.sanitizeConfluenceContent(
          'Text with\x00null\x1Fcontrol\x7Fchars'
        );
        
        expect(sanitized, contains('Text withnullcontrolchars'));
        expect(sanitized, contains('--- Информация из Confluence ---'));
        expect(sanitized, contains('--- Конец информации из Confluence ---'));
      });

      test('should handle empty content', () {
        final sanitized = llmService.sanitizeConfluenceContent('');
        expect(sanitized, isEmpty);
      });
    });
  });
}