import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/models/app_config.dart';
import 'package:tee_zee_nator/models/confluence_config.dart';
import 'package:tee_zee_nator/models/output_format.dart';

void main() {
  group('AppConfig Confluence Extension Tests', () {
    group('ConfluenceConfig Field Integration', () {
      test('should create AppConfig with ConfluenceConfig field', () {
        final confluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'test-token',
          isValid: true,
        );

        final appConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'sk-test-token',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: confluenceConfig,
        );

        expect(appConfig.confluenceConfig, equals(confluenceConfig));
        expect(appConfig.confluenceConfig?.enabled, isTrue);
        expect(appConfig.confluenceConfig?.baseUrl, equals('https://company.atlassian.net'));
        expect(appConfig.confluenceConfig?.token, equals('test-token'));
        expect(appConfig.confluenceConfig?.isValid, isTrue);
      });

      test('should create AppConfig without ConfluenceConfig (null)', () {
        final appConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'sk-test-token',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
        );

        expect(appConfig.confluenceConfig, isNull);
      });

      test('should create AppConfig with disabled ConfluenceConfig', () {
        final confluenceConfig = ConfluenceConfig.disabled();

        final appConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'sk-test-token',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: confluenceConfig,
        );

        expect(appConfig.confluenceConfig, equals(confluenceConfig));
        expect(appConfig.confluenceConfig?.enabled, isFalse);
        expect(appConfig.confluenceConfig?.baseUrl, isEmpty);
        expect(appConfig.confluenceConfig?.token, isEmpty);
        expect(appConfig.confluenceConfig?.isValid, isFalse);
      });
    });

    group('CopyWith Method Extension', () {
      test('should update ConfluenceConfig using copyWith', () {
        final originalConfluenceConfig = ConfluenceConfig.disabled();
        final originalAppConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'sk-test-token',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: originalConfluenceConfig,
        );

        final newConfluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'new-token',
          isValid: true,
        );

        final updatedAppConfig = originalAppConfig.copyWith(
          confluenceConfig: newConfluenceConfig,
        );

        expect(updatedAppConfig.confluenceConfig, equals(newConfluenceConfig));
        expect(updatedAppConfig.confluenceConfig?.enabled, isTrue);
        expect(updatedAppConfig.confluenceConfig?.baseUrl, equals('https://company.atlassian.net'));
        expect(updatedAppConfig.confluenceConfig?.token, equals('new-token'));
        expect(updatedAppConfig.confluenceConfig?.isValid, isTrue);

        // Verify other fields remain unchanged
        expect(updatedAppConfig.apiUrl, equals(originalAppConfig.apiUrl));
        expect(updatedAppConfig.apiToken, equals(originalAppConfig.apiToken));
        expect(updatedAppConfig.provider, equals(originalAppConfig.provider));
        expect(updatedAppConfig.preferredFormat, equals(originalAppConfig.preferredFormat));
      });

      test('should preserve ConfluenceConfig when not specified in copyWith', () {
        final confluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'test-token',
          isValid: true,
        );

        final originalAppConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'sk-test-token',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: confluenceConfig,
        );

        final updatedAppConfig = originalAppConfig.copyWith(
          apiUrl: 'https://api.openai.com/v2',
        );

        expect(updatedAppConfig.confluenceConfig, equals(confluenceConfig));
        expect(updatedAppConfig.apiUrl, equals('https://api.openai.com/v2'));
      });

      test('should set ConfluenceConfig to null using copyWith', () {
        final confluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'test-token',
          isValid: true,
        );

        final originalAppConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'sk-test-token',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: confluenceConfig,
        );

        final updatedAppConfig = originalAppConfig.copyWith(
          confluenceConfig: null,
        );

        expect(updatedAppConfig.confluenceConfig, isNull);
      });
    });

    group('Configuration Migration Logic', () {
      test('should handle migration from old AppConfig without ConfluenceConfig', () {
        // Simulate old configuration data without ConfluenceConfig field
        final oldConfigMap = <dynamic, dynamic>{
          0: 'https://api.openai.com/v1', // apiUrl
          1: 'sk-test-token', // apiToken
          2: 'gpt-4', // defaultModel
          3: 'gpt-3.5-turbo', // reviewModel
          4: 'template-1', // selectedTemplateId
          5: 'openai', // provider
          6: null, // llmopsBaseUrl
          7: null, // llmopsModel
          8: null, // llmopsAuthHeader
          9: OutputFormat.markdown, // preferredFormat
          // No field 10 (confluenceConfig) - simulating old data
        };

        final migratedConfig = AppConfig.fromMap(oldConfigMap);

        expect(migratedConfig.apiUrl, equals('https://api.openai.com/v1'));
        expect(migratedConfig.apiToken, equals('sk-test-token'));
        expect(migratedConfig.defaultModel, equals('gpt-4'));
        expect(migratedConfig.reviewModel, equals('gpt-3.5-turbo'));
        expect(migratedConfig.selectedTemplateId, equals('template-1'));
        expect(migratedConfig.provider, equals('openai'));
        expect(migratedConfig.preferredFormat, equals(OutputFormat.markdown));
        expect(migratedConfig.confluenceConfig, isNull); // Should be null for existing users
      });

      test('should handle migration with existing ConfluenceConfig', () {
        final confluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'test-token',
          isValid: true,
        );

        final configMap = <dynamic, dynamic>{
          0: 'https://api.openai.com/v1', // apiUrl
          1: 'sk-test-token', // apiToken
          2: 'gpt-4', // defaultModel
          3: 'gpt-3.5-turbo', // reviewModel
          4: 'template-1', // selectedTemplateId
          5: 'openai', // provider
          6: null, // llmopsBaseUrl
          7: null, // llmopsModel
          8: null, // llmopsAuthHeader
          9: OutputFormat.markdown, // preferredFormat
          10: confluenceConfig, // confluenceConfig
        };

        final migratedConfig = AppConfig.fromMap(configMap);

        expect(migratedConfig.confluenceConfig, equals(confluenceConfig));
        expect(migratedConfig.confluenceConfig?.enabled, isTrue);
        expect(migratedConfig.confluenceConfig?.baseUrl, equals('https://company.atlassian.net'));
      });

      test('should handle migration with null ConfluenceConfig', () {
        final configMap = <dynamic, dynamic>{
          0: 'https://api.openai.com/v1', // apiUrl
          1: 'sk-test-token', // apiToken
          2: 'gpt-4', // defaultModel
          3: 'gpt-3.5-turbo', // reviewModel
          4: 'template-1', // selectedTemplateId
          5: 'openai', // provider
          6: null, // llmopsBaseUrl
          7: null, // llmopsModel
          8: null, // llmopsAuthHeader
          9: OutputFormat.markdown, // preferredFormat
          10: null, // confluenceConfig explicitly null
        };

        final migratedConfig = AppConfig.fromMap(configMap);

        expect(migratedConfig.confluenceConfig, isNull);
      });

      test('should provide default values for existing users during migration', () {
        // Test that existing users get appropriate defaults
        final oldConfigMap = <dynamic, dynamic>{
          0: 'https://api.openai.com/v1',
          1: 'sk-test-token',
          2: null, // defaultModel
          3: null, // reviewModel
          4: null, // selectedTemplateId
          5: null, // provider - should default to 'openai'
          6: null, // llmopsBaseUrl
          7: null, // llmopsModel
          8: null, // llmopsAuthHeader
          9: null, // preferredFormat - should default to markdown
          // No confluenceConfig field
        };

        final migratedConfig = AppConfig.fromMap(oldConfigMap);

        expect(migratedConfig.provider, equals('openai')); // Default for old configs
        expect(migratedConfig.preferredFormat, equals(OutputFormat.markdown)); // Default for old configs
        expect(migratedConfig.confluenceConfig, isNull); // Should be null for existing users
      });
    });

    group('JSON Serialization with ConfluenceConfig', () {
      test('should serialize and deserialize AppConfig with ConfluenceConfig', () {
        final confluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'test-token',
          isValid: true,
          lastValidated: DateTime(2024, 1, 15),
        );

        final originalConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'sk-test-token',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: confluenceConfig,
        );

        final json = originalConfig.toJson();
        final deserializedConfig = AppConfig.fromJson(json);

        expect(deserializedConfig.confluenceConfig?.enabled, equals(confluenceConfig.enabled));
        expect(deserializedConfig.confluenceConfig?.baseUrl, equals(confluenceConfig.baseUrl));
        expect(deserializedConfig.confluenceConfig?.token, equals(confluenceConfig.token));
        expect(deserializedConfig.confluenceConfig?.isValid, equals(confluenceConfig.isValid));
        expect(deserializedConfig.confluenceConfig?.lastValidated, equals(confluenceConfig.lastValidated));
      });

      test('should serialize and deserialize AppConfig with null ConfluenceConfig', () {
        final originalConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'sk-test-token',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: null,
        );

        final json = originalConfig.toJson();
        final deserializedConfig = AppConfig.fromJson(json);

        expect(deserializedConfig.confluenceConfig, isNull);
      });
    });

    group('Integration with Existing Fields', () {
      test('should maintain all existing AppConfig functionality with ConfluenceConfig', () {
        final confluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'test-token',
          isValid: true,
        );

        final appConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'sk-test-token',
          defaultModel: 'gpt-4',
          reviewModel: 'gpt-3.5-turbo',
          selectedTemplateId: 'template-1',
          provider: 'openai',
          llmopsBaseUrl: 'https://llmops.example.com',
          llmopsModel: 'custom-model',
          llmopsAuthHeader: 'Bearer token',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: confluenceConfig,
        );

        // Test all existing fields are preserved
        expect(appConfig.apiUrl, equals('https://api.openai.com/v1'));
        expect(appConfig.apiToken, equals('sk-test-token'));
        expect(appConfig.defaultModel, equals('gpt-4'));
        expect(appConfig.reviewModel, equals('gpt-3.5-turbo'));
        expect(appConfig.selectedTemplateId, equals('template-1'));
        expect(appConfig.provider, equals('openai'));
        expect(appConfig.llmopsBaseUrl, equals('https://llmops.example.com'));
        expect(appConfig.llmopsModel, equals('custom-model'));
        expect(appConfig.llmopsAuthHeader, equals('Bearer token'));
        expect(appConfig.preferredFormat, equals(OutputFormat.markdown));
        
        // Test new field
        expect(appConfig.confluenceConfig, equals(confluenceConfig));
      });

      test('should handle copyWith with mixed field updates including ConfluenceConfig', () {
        final originalConfluenceConfig = ConfluenceConfig.disabled();
        final originalConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'sk-old-token',
          provider: 'openai',
          preferredFormat: OutputFormat.markdown,
          confluenceConfig: originalConfluenceConfig,
        );

        final newConfluenceConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'new-token',
          isValid: true,
        );

        final updatedConfig = originalConfig.copyWith(
          apiToken: 'sk-new-token',
          provider: 'llmops',
          confluenceConfig: newConfluenceConfig,
        );

        expect(updatedConfig.apiUrl, equals('https://api.openai.com/v1')); // Unchanged
        expect(updatedConfig.apiToken, equals('sk-new-token')); // Updated
        expect(updatedConfig.provider, equals('llmops')); // Updated
        expect(updatedConfig.preferredFormat, equals(OutputFormat.markdown)); // Unchanged
        expect(updatedConfig.confluenceConfig, equals(newConfluenceConfig)); // Updated
      });
    });
  });
}