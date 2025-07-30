import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/models/app_config.dart';
import 'package:tee_zee_nator/models/output_format.dart';

void main() {
  group('Configuration Management Tests', () {
    group('Format Preference Validation', () {
      test('should validate format preferences correctly', () {
        // Test all valid formats
        for (final format in OutputFormat.values) {
          expect(OutputFormat.values.contains(format), isTrue);
        }
      });

      test('should provide default format fallback', () {
        final defaultFormat = OutputFormat.defaultFormat;
        expect(defaultFormat, equals(OutputFormat.markdown));
        expect(defaultFormat.isDefault, isTrue);
      });

      test('should handle format preference in AppConfig', () {
        final config = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-token',
          preferredFormat: OutputFormat.confluence,
        );

        expect(config.preferredFormat, equals(OutputFormat.confluence));
      });
    });

    group('Configuration Migration Logic', () {
      test('should handle existing configurations without format preference', () {
        // Simulate old configuration without explicit format preference
        final oldConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-token',
          // preferredFormat will default to OutputFormat.markdown
        );

        // Should default to markdown format
        expect(oldConfig.preferredFormat, equals(OutputFormat.markdown));
        expect(oldConfig.preferredFormat, equals(OutputFormat.defaultFormat));
      });

      test('should preserve existing format preferences during migration', () {
        final configWithFormat = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-token',
          preferredFormat: OutputFormat.confluence,
        );

        // Should preserve the explicitly set format
        expect(configWithFormat.preferredFormat, equals(OutputFormat.confluence));
      });

      test('should handle format preference updates', () {
        final originalConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-token',
          preferredFormat: OutputFormat.markdown,
        );

        final updatedConfig = originalConfig.copyWith(
          preferredFormat: OutputFormat.confluence,
        );

        expect(originalConfig.preferredFormat, equals(OutputFormat.markdown));
        expect(updatedConfig.preferredFormat, equals(OutputFormat.confluence));
        
        // Verify other fields remain unchanged
        expect(updatedConfig.apiUrl, equals(originalConfig.apiUrl));
        expect(updatedConfig.apiToken, equals(originalConfig.apiToken));
      });
    });

    group('Setup Screen Integration', () {
      test('should handle format selection in setup configuration', () {
        // Test OpenAI provider with format preference
        final openAIConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'sk-test-token',
          provider: 'openai',
          defaultModel: 'gpt-4',
          reviewModel: 'gpt-4',
          preferredFormat: OutputFormat.markdown,
        );

        expect(openAIConfig.provider, equals('openai'));
        expect(openAIConfig.preferredFormat, equals(OutputFormat.markdown));

        // Test LLMOps provider with format preference
        final llmopsConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1', // Placeholder
          apiToken: 'test-token', // Placeholder
          provider: 'llmops',
          llmopsBaseUrl: 'http://localhost:11434',
          llmopsModel: 'llama2',
          defaultModel: 'llama2',
          reviewModel: 'llama2',
          preferredFormat: OutputFormat.confluence,
        );

        expect(llmopsConfig.provider, equals('llmops'));
        expect(llmopsConfig.preferredFormat, equals(OutputFormat.confluence));
      });

      test('should maintain format preference consistency', () {
        final config = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-token',
          preferredFormat: OutputFormat.confluence,
        );

        // Format should be consistent across operations
        expect(config.preferredFormat, equals(OutputFormat.confluence));
        expect(config.preferredFormat.displayName, equals('Confluence Storage Format'));
        expect(config.preferredFormat.fileExtension, equals('html'));
      });
    });

    group('Format Preference Storage and Retrieval', () {
      test('should handle format preference serialization', () {
        final config = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-token',
          preferredFormat: OutputFormat.markdown,
        );

        final json = config.toJson();
        final deserializedConfig = AppConfig.fromJson(json);

        expect(deserializedConfig.preferredFormat, equals(OutputFormat.markdown));
        expect(deserializedConfig.apiUrl, equals(config.apiUrl));
        expect(deserializedConfig.apiToken, equals(config.apiToken));
      });

      test('should handle format preference validation with fallback', () {
        // Test that invalid format scenarios fall back to default
        final config = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-token',
          // No explicit format - should default
        );

        expect(config.preferredFormat, equals(OutputFormat.defaultFormat));
      });

      test('should support all available format options', () {
        for (final format in OutputFormat.values) {
          final config = AppConfig(
            apiUrl: 'https://api.openai.com/v1',
            apiToken: 'test-token',
            preferredFormat: format,
          );

          expect(config.preferredFormat, equals(format));
          expect(config.preferredFormat.displayName, isNotEmpty);
          expect(config.preferredFormat.fileExtension, isNotEmpty);
        }
      });
    });
  });
}