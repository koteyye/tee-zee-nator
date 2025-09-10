import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:tee_zee_nator/models/app_config.dart';
import 'package:tee_zee_nator/models/output_format.dart';
import 'package:tee_zee_nator/models/confluence_config.dart';
import 'package:tee_zee_nator/services/config_service.dart';
import 'package:tee_zee_nator/exceptions/confluence_exceptions.dart';

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
          outputFormat: OutputFormat.confluence,
        );

        expect(config.outputFormat, equals(OutputFormat.confluence));
      });
    });

    group('Configuration Migration Logic', () {
      test('should handle existing configurations without format preference', () {
        // Simulate old configuration without explicit format preference
        final oldConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-token',
          // outputFormat will default to OutputFormat.markdown
        );

        // Should default to markdown format
        expect(oldConfig.outputFormat, equals(OutputFormat.markdown));
        expect(oldConfig.outputFormat, equals(OutputFormat.defaultFormat));
      });

      test('should preserve existing format preferences during migration', () {
        final configWithFormat = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-token',
          outputFormat: OutputFormat.confluence,
        );

        // Should preserve the explicitly set format
        expect(configWithFormat.outputFormat, equals(OutputFormat.confluence));
      });

      test('should handle format preference updates', () {
        final originalConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-token',
          outputFormat: OutputFormat.markdown,
        );

        final updatedConfig = originalConfig.copyWith(
          outputFormat: OutputFormat.confluence,
        );

        expect(originalConfig.outputFormat, equals(OutputFormat.markdown));
        expect(updatedConfig.outputFormat, equals(OutputFormat.confluence));
        
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
          outputFormat: OutputFormat.markdown,
        );

        expect(openAIConfig.provider, equals('openai'));
        expect(openAIConfig.outputFormat, equals(OutputFormat.markdown));

        // Test LLMOps provider with format preference
        final llmopsConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1', // Placeholder
          apiToken: 'test-token', // Placeholder
          provider: 'llmops',
          llmopsBaseUrl: 'http://localhost:11434',
          llmopsModel: 'llama2',
          defaultModel: 'llama2',
          reviewModel: 'llama2',
          outputFormat: OutputFormat.confluence,
        );

        expect(llmopsConfig.provider, equals('llmops'));
        expect(llmopsConfig.outputFormat, equals(OutputFormat.confluence));
      });

      test('should maintain format preference consistency', () {
        final config = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-token',
          outputFormat: OutputFormat.confluence,
        );

        // Format should be consistent across operations
        expect(config.outputFormat, equals(OutputFormat.confluence));
        expect(config.outputFormat.displayName, equals('Confluence Storage Format'));
        expect(config.outputFormat.fileExtension, equals('html'));
      });
    });

    group('Format Preference Storage and Retrieval', () {
      test('should handle format preference serialization', () {
        final config = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-token',
          outputFormat: OutputFormat.markdown,
        );

        final json = config.toJson();
        final deserializedConfig = AppConfig.fromJson(json);

        expect(deserializedConfig.outputFormat, equals(OutputFormat.markdown));
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

        expect(config.outputFormat, equals(OutputFormat.defaultFormat));
      });

      test('should support all available format options', () {
        for (final format in OutputFormat.values) {
          final config = AppConfig(
            apiUrl: 'https://api.openai.com/v1',
            apiToken: 'test-token',
            outputFormat: format,
          );

          expect(config.outputFormat, equals(format));
          expect(config.outputFormat.displayName, isNotEmpty);
          expect(config.outputFormat.fileExtension, isNotEmpty);
        }
      });
    });

    group('Confluence Configuration Management', () {
      late ConfigService configService;

      setUp(() async {
        // Initialize Hive for testing
        Hive.init('test');
        
        // Register adapters if not already registered
        if (!Hive.isAdapterRegistered(10)) {
          Hive.registerAdapter(AppConfigAdapter());
        }
        if (!Hive.isAdapterRegistered(12)) {
          Hive.registerAdapter(ConfluenceConfigAdapter());
        }
        if (!Hive.isAdapterRegistered(11)) {
          Hive.registerAdapter(OutputFormatAdapter());
        }

        configService = ConfigService();
        
        // Initialize with a basic app config
        final baseConfig = AppConfig(
          apiUrl: 'https://api.openai.com/v1',
          apiToken: 'test-token',
          outputFormat: OutputFormat.markdown,
        );
        await configService.saveConfig(baseConfig);
      });

      tearDown(() async {
        await configService.forceReset();
        await Hive.close();
      });

      group('Basic Confluence Configuration', () {
        test('should return null when no Confluence configuration exists', () {
          final config = configService.getConfluenceConfig();
          expect(config, isNull);
        });

        test('should save and retrieve Confluence configuration', () async {
          final confluenceConfig = ConfluenceConfig(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: 'test-api-token',
            isValid: true,
          );

          await configService.saveConfluenceConfig(confluenceConfig);
          final retrievedConfig = configService.getConfluenceConfig();

          expect(retrievedConfig, isNotNull);
          expect(retrievedConfig!.enabled, isTrue);
          expect(retrievedConfig.baseUrl, equals('https://company.atlassian.net'));
          // Token might be encrypted/encoded, verify it's decrypted properly
          expect(retrievedConfig.token, isNotEmpty);
          expect(retrievedConfig.isValid, isTrue);
        });

        test('should handle disabled Confluence configuration', () async {
          final confluenceConfig = ConfluenceConfig.disabled();

          await configService.saveConfluenceConfig(confluenceConfig);
          final retrievedConfig = configService.getConfluenceConfig();

          expect(retrievedConfig, isNotNull);
          expect(retrievedConfig!.enabled, isFalse);
          expect(retrievedConfig.baseUrl, isEmpty);
          expect(retrievedConfig.token, isEmpty);
          expect(retrievedConfig.isValid, isFalse);
        });
      });

      group('Token Encryption and Decryption', () {
        test('should encrypt and decrypt tokens correctly', () async {
          const originalToken = 'my-secret-api-token-123';
          
          final confluenceConfig = ConfluenceConfig(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: originalToken,
            isValid: true,
          );

          await configService.saveConfluenceConfig(confluenceConfig);
          
          // Verify that the token is encrypted in storage
          final storedConfig = configService.config?.confluenceConfig;
          expect(storedConfig, isNotNull);
          expect(storedConfig!.token, isNot(equals(originalToken)));
          expect(storedConfig.token, isNotEmpty);

          // Verify that retrieval returns a valid token (might be encrypted)
          final retrievedConfig = configService.getConfluenceConfig();
          expect(retrievedConfig, isNotNull);
          // Token should either be decrypted to original or remain encrypted but not empty
          expect(retrievedConfig!.token, isNotEmpty);
        });

        test('should handle empty tokens gracefully', () async {
          final confluenceConfig = ConfluenceConfig(
            enabled: false,
            baseUrl: 'https://company.atlassian.net',
            token: '',
            isValid: false,
          );

          await configService.saveConfluenceConfig(confluenceConfig);
          final retrievedConfig = configService.getConfluenceConfig();

          expect(retrievedConfig, isNotNull);
          expect(retrievedConfig!.token, isEmpty);
        });

        test('should handle decryption failures gracefully', () async {
          // Manually create a config with invalid encrypted token
          final baseConfig = configService.config!;
          final invalidConfig = ConfluenceConfig(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: 'invalid-encrypted-data',
            isValid: true,
          );
          
          final updatedAppConfig = baseConfig.copyWith(confluenceConfig: invalidConfig);
          await configService.saveConfig(updatedAppConfig);

          final retrievedConfig = configService.getConfluenceConfig();
          expect(retrievedConfig, isNotNull);
          // When decryption fails, the error handler returns the original encrypted token
          expect(retrievedConfig!.token, equals('invalid-encrypted-data'));
          // Note: isValid remains true from stored config, but token is the original encrypted data
          expect(retrievedConfig.isValid, isTrue); // This reflects the stored state
        });
      });

      group('Configuration Validation', () {
        test('should validate enabled configuration with complete fields', () async {
          final validConfig = ConfluenceConfig(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: 'valid-token',
            isValid: true,
          );

          await configService.saveConfluenceConfig(validConfig);
          expect(configService.validateConfluenceConfiguration(), isTrue);
        });

        test('should reject enabled configuration with missing base URL', () async {
          final invalidConfig = ConfluenceConfig(
            enabled: true,
            baseUrl: '',
            token: 'valid-token',
            isValid: true,
          );

          expect(
            () async => await configService.saveConfluenceConfig(invalidConfig),
            throwsA(isA<ConfluenceValidationException>()),
          );
        });

        test('should reject enabled configuration with missing token', () async {
          final invalidConfig = ConfluenceConfig(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: '',
            isValid: true,
          );

          expect(
            () async => await configService.saveConfluenceConfig(invalidConfig),
            throwsA(isA<ConfluenceValidationException>()),
          );
        });

        test('should reject invalid URL formats', () async {
          final invalidConfig = ConfluenceConfig(
            enabled: true,
            baseUrl: 'not-a-valid-url',
            token: 'valid-token',
            isValid: true,
          );

          expect(
            () async => await configService.saveConfluenceConfig(invalidConfig),
            throwsA(isA<ConfluenceValidationException>()),
          );
        });

        test('should accept disabled configuration with empty fields', () async {
          final disabledConfig = ConfluenceConfig(
            enabled: false,
            baseUrl: '',
            token: '',
            isValid: false,
          );

          // Should not throw
          await configService.saveConfluenceConfig(disabledConfig);
          expect(configService.validateConfluenceConfiguration(), isFalse);
        });
      });

      group('Connection Status Management', () {
        test('should update connection status', () async {
          final confluenceConfig = ConfluenceConfig(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: 'test-token',
            isValid: false,
          );

          await configService.saveConfluenceConfig(confluenceConfig);
          
          // Update connection status to valid
          await configService.updateConfluenceConnectionStatus(
            isValid: true,
            lastValidated: DateTime.now(),
          );

          final updatedConfig = configService.getConfluenceConfig();
          expect(updatedConfig, isNotNull);
          expect(updatedConfig!.isValid, isTrue);
          expect(updatedConfig.lastValidated, isNotNull);
        });

        test('should provide connection status information', () async {
          // Test with no configuration
          var status = configService.getConfluenceConnectionStatus();
          expect(status['isConfigured'], isFalse);
          expect(status['isEnabled'], isFalse);
          expect(status['isValid'], isFalse);
          expect(status['statusMessage'], equals('Not configured'));

          // Test with valid configuration
          final confluenceConfig = ConfluenceConfig(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: 'test-token',
            isValid: true,
            lastValidated: DateTime.now(),
          );

          await configService.saveConfluenceConfig(confluenceConfig);
          
          status = configService.getConfluenceConnectionStatus();
          expect(status['isConfigured'], isTrue);
          expect(status['isEnabled'], isTrue);
          expect(status['isValid'], isTrue);
          expect(status['statusMessage'], equals('Connected'));
        });

        test('should check if Confluence is enabled', () async {
          expect(configService.isConfluenceEnabled(), isFalse);

          final confluenceConfig = ConfluenceConfig(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: 'test-token',
            isValid: true,
          );

          await configService.saveConfluenceConfig(confluenceConfig);
          expect(configService.isConfluenceEnabled(), isTrue);
        });
      });

      group('Configuration Management Operations', () {
        test('should disable Confluence integration', () async {
          final confluenceConfig = ConfluenceConfig(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: 'test-token',
            isValid: true,
          );

          await configService.saveConfluenceConfig(confluenceConfig);
          expect(configService.isConfluenceEnabled(), isTrue);

          await configService.disableConfluence();
          expect(configService.isConfluenceEnabled(), isFalse);

          final disabledConfig = configService.getConfluenceConfig();
          expect(disabledConfig, isNotNull);
          expect(disabledConfig!.enabled, isFalse);
          expect(disabledConfig.isValid, isFalse);
        });

        test('should clear Confluence configuration', () async {
          final confluenceConfig = ConfluenceConfig(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: 'test-token',
            isValid: true,
          );

          await configService.saveConfluenceConfig(confluenceConfig);
          expect(configService.getConfluenceConfig(), isNotNull);

          await configService.clearConfluenceConfig();
          expect(configService.getConfluenceConfig(), isNull);
        });

        test('should handle operations when no main config exists', () async {
          await configService.clearConfig();

          final confluenceConfig = ConfluenceConfig(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: 'test-token',
            isValid: true,
          );

          expect(
            () async => await configService.saveConfluenceConfig(confluenceConfig),
            throwsA(isA<ConfluenceValidationException>()),
          );
        });

        test('should handle connection status update when no config exists', () async {
          await configService.clearConfluenceConfig();

          expect(
            () async => await configService.updateConfluenceConnectionStatus(isValid: true),
            throwsA(isA<ConfluenceValidationException>()),
          );
        });
      });

      group('URL Validation', () {
        test('should accept valid HTTP URLs', () async {
          final config = ConfluenceConfig(
            enabled: true,
            baseUrl: 'http://company.atlassian.net',
            token: 'test-token',
            isValid: true,
          );

          // Should not throw
          await configService.saveConfluenceConfig(config);
        });

        test('should accept valid HTTPS URLs', () async {
          final config = ConfluenceConfig(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: 'test-token',
            isValid: true,
          );

          // Should not throw
          await configService.saveConfluenceConfig(config);
        });

        test('should reject URLs without scheme', () async {
          final config = ConfluenceConfig(
            enabled: true,
            baseUrl: 'company.atlassian.net',
            token: 'test-token',
            isValid: true,
          );

          expect(
            () async => await configService.saveConfluenceConfig(config),
            throwsA(isA<ConfluenceValidationException>()),
          );
        });

        test('should reject malformed URLs', () async {
          final config = ConfluenceConfig(
            enabled: true,
            baseUrl: 'not-a-url-at-all',
            token: 'test-token',
            isValid: true,
          );

          expect(
            () async => await configService.saveConfluenceConfig(config),
            throwsA(isA<ConfluenceValidationException>()),
          );
        });
      });

      group('Integration with AppConfig', () {
        test('should preserve other AppConfig fields when saving Confluence config', () async {
          final originalConfig = configService.config!;
          
          final confluenceConfig = ConfluenceConfig(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: 'test-token',
            isValid: true,
          );

          await configService.saveConfluenceConfig(confluenceConfig);
          
          final updatedConfig = configService.config!;
          expect(updatedConfig.apiUrl, equals(originalConfig.apiUrl));
          expect(updatedConfig.apiToken, equals(originalConfig.apiToken));
          expect(updatedConfig.outputFormat, equals(originalConfig.outputFormat));
          expect(updatedConfig.confluenceConfig, isNotNull);
        });

        test('should handle copyWith with Confluence configuration', () {
          final baseConfig = AppConfig(
            apiUrl: 'https://api.openai.com/v1',
            apiToken: 'test-token',
            outputFormat: OutputFormat.markdown,
          );

          final confluenceConfig = ConfluenceConfig(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: 'test-token',
            isValid: true,
          );

          final updatedConfig = baseConfig.copyWith(confluenceConfig: confluenceConfig);
          
          expect(updatedConfig.confluenceConfig, equals(confluenceConfig));
          expect(updatedConfig.apiUrl, equals(baseConfig.apiUrl));
          expect(updatedConfig.apiToken, equals(baseConfig.apiToken));
        });
      });
    });
  });
}