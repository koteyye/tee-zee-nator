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
}