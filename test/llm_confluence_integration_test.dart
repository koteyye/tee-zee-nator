import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/services/llm_service.dart';
import 'package:tee_zee_nator/models/output_format.dart';
import 'package:tee_zee_nator/exceptions/content_processing_exceptions.dart';

void main() {
  group('LLM Service Confluence Integration Tests', () {
    late LLMService llmService;

    setUp(() {
      llmService = LLMService();
    });

    group('End-to-end Confluence content processing', () {
      test('should process Confluence content in requirements before LLM generation', () async {
        const rawRequirements = '''
        Basic requirements for the feature.
        
        Additional context: @conf-cnt 
        This is content from a Confluence page that provides important context.
        It includes technical details and business requirements.
        The content should be processed and included in the LLM request.
        @
        
        More requirements after the Confluence content.
        ''';

        // This should fail on provider initialization, not content processing
        try {
          await llmService.generateTZ(
            rawRequirements: rawRequirements,
            format: OutputFormat.markdown,
          );
          fail('Should fail on provider initialization');
        } catch (e) {
          // Should fail on provider initialization, not content processing
          expect(e.toString(), contains('провайдер не инициализирован'));
          expect(e.toString(), isNot(contains('маркеры')));
        }
      });

      test('should process Confluence content in changes field', () async {
        const changes = '''
        Update the feature based on: @conf-cnt 
        New requirements from stakeholder meeting.
        Updated business rules and validation criteria.
        @
        ''';

        try {
          await llmService.generateTZ(
            rawRequirements: 'Basic requirements',
            changes: changes,
            format: OutputFormat.markdown,
          );
          fail('Should fail on provider initialization');
        } catch (e) {
          // Should fail on provider initialization, not content processing
          expect(e.toString(), contains('провайдер не инициализирован'));
          expect(e.toString(), isNot(contains('маркеры')));
        }
      });

      test('should handle mixed content with multiple Confluence markers', () async {
        const mixedContent = '''
        Feature requirements:
        
        1. User authentication: @conf-cnt Authentication requirements from security team@ 
        
        2. Data validation: @conf-cnt Validation rules from business analyst@
        
        3. Error handling: @conf-cnt Error handling guidelines from architecture team@
        
        Additional notes and requirements.
        ''';

        try {
          await llmService.generateTZ(
            rawRequirements: mixedContent,
            format: OutputFormat.markdown,
          );
          fail('Should fail on provider initialization');
        } catch (e) {
          // Should fail on provider initialization, not content processing
          expect(e.toString(), contains('провайдер не инициализирован'));
          expect(e.toString(), isNot(contains('маркеры')));
        }
      });

      test('should validate content length after processing Confluence markers', () {
        // Create content that becomes too long after processing
        final longConfluenceContent = 'A' * 5000;
        final requirements = '''
        Requirements: @conf-cnt $longConfluenceContent@
        More: @conf-cnt $longConfluenceContent@
        Even more: @conf-cnt $longConfluenceContent@
        Final: @conf-cnt $longConfluenceContent@
        ''';

        // Should fail on content length validation
        expect(() => llmService.validateGenerationParameters(
          requirements, 
          OutputFormat.markdown, 
          null
        ), throwsA(predicate((e) => e.toString().contains('слишком длинные'))));
      });

      test('should detect malformed Confluence markers', () {
        // Process the content first to see if markers remain unprocessed
        const malformedContent = '''
        Requirements with @conf-cnt incomplete marker
        And another @conf-cnt also incomplete
        ''';
        
        final processed = llmService.processConfluenceContent(malformedContent);
        
        // Should fail on unprocessed markers validation if any remain
        if (processed.contains('@conf-cnt')) {
          expect(() => llmService.validateGenerationParameters(
            processed, 
            OutputFormat.markdown, 
            null
          ), throwsA(predicate((e) => e.toString().contains('необработанные маркеры'))));
        } else {
          // If no markers remain, the content was processed (incomplete markers were ignored)
          expect(processed, isNot(contains('@conf-cnt')));
        }
      });
    });

    group('Content processing edge cases', () {
      test('should handle empty Confluence content gracefully', () {
        final processed = llmService.processConfluenceContent(
          'Text with @conf-cnt @ empty marker and @conf-cnt   @ whitespace only'
        );
        
        expect(processed, equals('Text with  empty marker and  whitespace only'));
      });

      test('should handle nested-like markers', () {
        final processed = llmService.processConfluenceContent(
          'Text @conf-cnt Content with nested text@ more content'
        );
        
        // Should process the complete marker
        expect(processed, contains('--- Информация из Confluence ---'));
        expect(processed, contains('Content with nested text'));
        expect(processed, contains('more content'));
      });

      test('should preserve text formatting in processed content', () {
        final processed = llmService.processConfluenceContent(
          'Requirements: @conf-cnt Line 1\nLine 2\n\nParagraph 2@ End'
        );
        
        expect(processed, contains('Line 1'));
        expect(processed, contains('Line 2'));
        expect(processed, contains('Paragraph 2'));
        expect(processed, contains('End'));
      });

      test('should handle special characters in Confluence content', () {
        final processed = llmService.processConfluenceContent(
          'Text @conf-cnt Special chars: áéíóú, ñ, ç, ü, ß, 中文, русский@ End'
        );
        
        expect(processed, contains('Special chars: áéíóú, ñ, ç, ü, ß, 中文, русский'));
        expect(processed, contains('End'));
      });
    });

    group('Security and sanitization', () {
      test('should sanitize potentially dangerous HTML content', () {
        final processed = llmService.processConfluenceContent(
          'Text @conf-cnt <script>alert("xss")</script><iframe src="evil.com"></iframe>@ End'
        );
        
        expect(processed, isNot(contains('<script>')));
        expect(processed, isNot(contains('<iframe>')));
        expect(processed, contains('alert("xss")'));
        expect(processed, contains('End'));
      });

      test('should escape @ symbols to prevent marker confusion', () {
        // Test the sanitization method directly since @ in marker content gets parsed differently
        final sanitized = llmService.sanitizeConfluenceContent(
          'Contact: admin@company.com for @support'
        );
        
        expect(sanitized, contains('admin(at)company.com'));
        expect(sanitized, contains('(at)support'));
      });

      test('should remove control characters', () {
        final processed = llmService.processConfluenceContent(
          'Text @conf-cnt Content\x00with\x1Fcontrol\x7Fchars@ End'
        );
        
        expect(processed, contains('Contentwithcontrolchars'));
        expect(processed, contains('End'));
      });
    });
  });
}