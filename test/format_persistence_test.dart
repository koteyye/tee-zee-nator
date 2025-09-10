import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/models/output_format.dart';
import 'package:tee_zee_nator/models/app_config.dart';
import 'package:tee_zee_nator/models/generation_history.dart';

void main() {
  group('Format Persistence Tests', () {
    group('AppConfig Format Persistence', () {
      test('should persist format preference in AppConfig', () {
        final config = AppConfig(
          provider: 'openai',
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-key',
          defaultModel: 'gpt-4',
          preferredFormat: OutputFormat.markdown,
        );

        expect(config.preferredFormat, equals(OutputFormat.markdown));
      });

      test('should handle format preference updates', () {
        final originalConfig = AppConfig(
          provider: 'openai',
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-key',
          defaultModel: 'gpt-4',
          preferredFormat: OutputFormat.markdown,
        );

        final updatedConfig = originalConfig.copyWith(
          preferredFormat: OutputFormat.confluence,
        );

        expect(originalConfig.preferredFormat, equals(OutputFormat.markdown));
        expect(updatedConfig.preferredFormat, equals(OutputFormat.confluence));
        
        // Verify other fields remain unchanged
        expect(updatedConfig.provider, equals('openai'));
        expect(updatedConfig.apiToken, equals('test-key'));
        expect(updatedConfig.defaultModel, equals('gpt-4'));
      });

      test('should handle default format preference', () {
        final config = AppConfig(
          provider: 'openai',
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-key',
          defaultModel: 'gpt-4',
          // preferredFormat will default to OutputFormat.markdown
        );

        expect(config.preferredFormat, equals(OutputFormat.markdown));
        
        // Should be able to change format later
        final updatedConfig = config.copyWith(
          preferredFormat: OutputFormat.confluence,
        );
        
        expect(updatedConfig.preferredFormat, equals(OutputFormat.confluence));
      });
    });

    group('Generation History Format Persistence', () {
      test('should persist format in generation history', () {
        final history = GenerationHistory(
          rawRequirements: 'Test requirements',
          changes: 'Test changes',
          generatedTz: 'Test content',
          timestamp: DateTime.now(),
          model: 'gpt-4',
          format: OutputFormat.markdown,
        );

        expect(history.format, equals(OutputFormat.markdown));
      });

      test('should handle format serialization in history', () {
        final originalHistory = GenerationHistory(
          rawRequirements: 'Test requirements',
          changes: null,
          generatedTz: 'Test content',
          timestamp: DateTime(2024, 1, 1, 12, 0, 0),
          model: 'gpt-4',
          format: OutputFormat.confluence,
        );

        final json = originalHistory.toJson();
        final deserializedHistory = GenerationHistory.fromJson(json);

        expect(deserializedHistory.format, equals(OutputFormat.confluence));
        expect(deserializedHistory.rawRequirements, equals('Test requirements'));
        expect(deserializedHistory.generatedTz, equals('Test content'));
        expect(deserializedHistory.model, equals('gpt-4'));
      });

      test('should handle legacy history without format field', () {
        final legacyJson = {
          'rawRequirements': 'Legacy requirements',
          'changes': null,
          'generatedTz': 'Legacy content',
          'timestamp': '2024-01-01T12:00:00.000',
          'model': 'gpt-3.5',
          // No format field - simulating legacy data
        };

        final history = GenerationHistory.fromJson(legacyJson);

        // Should default to the default format
        expect(history.format, equals(OutputFormat.defaultFormat));
        expect(history.rawRequirements, equals('Legacy requirements'));
        expect(history.model, equals('gpt-3.5'));
      });
    });

    group('Session Management', () {
      test('should maintain format preference across simulated sessions', () {
        // Simulate session 1
        OutputFormat session1Format = OutputFormat.confluence;
        
        // Save to config
        final config = AppConfig(
          provider: 'openai',
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-key',
          defaultModel: 'gpt-4',
          preferredFormat: session1Format,
        );

        // Simulate app restart - session 2
        final loadedFormat = config.preferredFormat;
        expect(loadedFormat, equals(OutputFormat.confluence));

        // User changes format in session 2
        final updatedConfig = config.copyWith(
          preferredFormat: OutputFormat.markdown,
        );

        // Simulate another app restart - session 3
        final session3Format = updatedConfig.preferredFormat;
        expect(session3Format, equals(OutputFormat.markdown));
      });

      test('should handle format preference initialization', () {
        // New user - no preference set
        AppConfig? config;
        
        // Initialize with default
        config = AppConfig(
          provider: 'openai',
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-key',
          defaultModel: 'gpt-4',
          preferredFormat: OutputFormat.defaultFormat,
        );

        expect(config.preferredFormat, equals(OutputFormat.markdown));
        expect(config.preferredFormat.isDefault, isTrue);
      });
    });

    group('Format Migration and Compatibility', () {
      test('should handle format enum changes gracefully', () {
        // Test that existing format values remain stable
        expect(OutputFormat.markdown.name, equals('markdown'));
        expect(OutputFormat.confluence.name, equals('confluence'));

        // Test that properties are consistent
        expect(OutputFormat.markdown.displayName, equals('Markdown'));
        expect(OutputFormat.confluence.displayName, equals('Confluence Storage Format'));
        
        expect(OutputFormat.markdown.fileExtension, equals('md'));
        expect(OutputFormat.confluence.fileExtension, equals('html'));
      });

      test('should validate format data integrity', () {
        // Test that format enum maintains data integrity
        final allFormats = OutputFormat.values;
        
        // Should have exactly the expected formats
        expect(allFormats, hasLength(2));
        expect(allFormats, contains(OutputFormat.markdown));
        expect(allFormats, contains(OutputFormat.confluence));

        // Should have exactly one default format
        final defaultFormats = allFormats.where((f) => f.isDefault).toList();
        expect(defaultFormats, hasLength(1));
        expect(defaultFormats.first, equals(OutputFormat.markdown));

        // All formats should have valid properties
        for (final format in allFormats) {
          expect(format.displayName, isNotEmpty);
          expect(format.fileExtension, isNotEmpty);
          expect(format.fileExtension, matches(RegExp(r'^[a-z]+$')));
        }
      });
    });
  });
}