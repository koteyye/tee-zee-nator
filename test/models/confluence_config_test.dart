import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/models/confluence_config.dart';

void main() {
  group('ConfluenceConfig', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final config = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://example.atlassian.net',
          token: 'test-token',
        );

        expect(config.enabled, isTrue);
        expect(config.baseUrl, equals('https://example.atlassian.net'));
        expect(config.token, equals('test-token'));
        expect(config.lastValidated, isNull);
        expect(config.isValid, isFalse); // Default value
      });

      test('creates instance with all fields', () {
        final lastValidated = DateTime.now();
        final config = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://example.atlassian.net',
          token: 'test-token',
          lastValidated: lastValidated,
          isValid: true,
        );

        expect(config.enabled, isTrue);
        expect(config.baseUrl, equals('https://example.atlassian.net'));
        expect(config.token, equals('test-token'));
        expect(config.lastValidated, equals(lastValidated));
        expect(config.isValid, isTrue);
      });
    });

    group('factory constructors', () {
      test('disabled() creates disabled configuration', () {
        final config = ConfluenceConfig.disabled();

        expect(config.enabled, isFalse);
        expect(config.baseUrl, isEmpty);
        expect(config.token, isEmpty);
        expect(config.lastValidated, isNull);
        expect(config.isValid, isFalse);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = ConfluenceConfig(
          enabled: false,
          baseUrl: 'https://old.atlassian.net',
          token: 'old-token',
          isValid: false,
        );

        final updated = original.copyWith(
          enabled: true,
          baseUrl: 'https://new.atlassian.net',
          isValid: true,
        );

        expect(updated.enabled, isTrue);
        expect(updated.baseUrl, equals('https://new.atlassian.net'));
        expect(updated.token, equals('old-token')); // Unchanged
        expect(updated.isValid, isTrue);
      });

      test('creates copy with same values when no parameters provided', () {
        final original = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://example.atlassian.net',
          token: 'test-token',
          isValid: true,
        );

        final copy = original.copyWith();

        expect(copy.enabled, equals(original.enabled));
        expect(copy.baseUrl, equals(original.baseUrl));
        expect(copy.token, equals(original.token));
        expect(copy.isValid, equals(original.isValid));
      });
    });

    group('isConfigurationComplete', () {
      test('returns true when enabled with valid baseUrl and token', () {
        final config = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://example.atlassian.net',
          token: 'test-token',
        );

        expect(config.isConfigurationComplete, isTrue);
      });

      test('returns false when disabled', () {
        final config = ConfluenceConfig(
          enabled: false,
          baseUrl: 'https://example.atlassian.net',
          token: 'test-token',
        );

        expect(config.isConfigurationComplete, isFalse);
      });

      test('returns false when baseUrl is empty', () {
        final config = ConfluenceConfig(
          enabled: true,
          baseUrl: '',
          token: 'test-token',
        );

        expect(config.isConfigurationComplete, isFalse);
      });

      test('returns false when token is empty', () {
        final config = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://example.atlassian.net',
          token: '',
        );

        expect(config.isConfigurationComplete, isFalse);
      });
    });

    group('sanitizedBaseUrl', () {
      test('removes trailing slashes', () {
        final config = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://example.atlassian.net///',
          token: 'test-token',
        );

        expect(config.sanitizedBaseUrl, equals('https://example.atlassian.net'));
      });

      test('removes /wiki/rest/api suffix', () {
        final config = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://example.atlassian.net/wiki/rest/api',
          token: 'test-token',
        );

        expect(config.sanitizedBaseUrl, equals('https://example.atlassian.net'));
      });

      test('removes both trailing slashes and /wiki/rest/api suffix', () {
        final config = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://example.atlassian.net/wiki/rest/api///',
          token: 'test-token',
        );

        expect(config.sanitizedBaseUrl, equals('https://example.atlassian.net'));
      });

      test('handles clean URL without changes', () {
        final config = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://example.atlassian.net',
          token: 'test-token',
        );

        expect(config.sanitizedBaseUrl, equals('https://example.atlassian.net'));
      });

      test('trims whitespace', () {
        final config = ConfluenceConfig(
          enabled: true,
          baseUrl: '  https://example.atlassian.net  ',
          token: 'test-token',
        );

        expect(config.sanitizedBaseUrl, equals('https://example.atlassian.net'));
      });
    });

    group('apiBaseUrl', () {
      test('returns correct API base URL', () {
        final config = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://example.atlassian.net',
          token: 'test-token',
        );

        expect(config.apiBaseUrl, equals('https://example.atlassian.net/wiki/rest/api'));
      });

      test('returns correct API base URL with sanitization', () {
        final config = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://example.atlassian.net/wiki/rest/api///',
          token: 'test-token',
        );

        expect(config.apiBaseUrl, equals('https://example.atlassian.net/wiki/rest/api'));
      });
    });

    group('equality and hashCode', () {
      test('equal objects have same hashCode', () {
        final config1 = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://example.atlassian.net',
          token: 'test-token',
          isValid: true,
        );

        final config2 = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://example.atlassian.net',
          token: 'test-token',
          isValid: true,
        );

        expect(config1, equals(config2));
        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('different objects are not equal', () {
        final config1 = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://example.atlassian.net',
          token: 'test-token',
        );

        final config2 = ConfluenceConfig(
          enabled: false,
          baseUrl: 'https://example.atlassian.net',
          token: 'test-token',
        );

        expect(config1, isNot(equals(config2)));
      });
    });

    group('toString', () {
      test('does not expose token in string representation', () {
        final config = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://example.atlassian.net',
          token: 'secret-token',
          isValid: true,
        );

        final stringRepresentation = config.toString();

        expect(stringRepresentation, contains('enabled: true'));
        expect(stringRepresentation, contains('https://example.atlassian.net'));
        expect(stringRepresentation, contains('isValid: true'));
        expect(stringRepresentation, contains('[REDACTED]'));
        expect(stringRepresentation, isNot(contains('secret-token')));
      });
    });

    group('JSON serialization', () {
      test('serializes to JSON correctly', () {
        final config = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://example.atlassian.net',
          token: 'test-token',
          isValid: true,
        );

        final json = config.toJson();

        expect(json['enabled'], isTrue);
        expect(json['baseUrl'], equals('https://example.atlassian.net'));
        expect(json['token'], equals('test-token'));
        expect(json['isValid'], isTrue);
      });

      test('deserializes from JSON correctly', () {
        final json = {
          'enabled': true,
          'baseUrl': 'https://example.atlassian.net',
          'token': 'test-token',
          'lastValidated': '2024-01-01T12:00:00.000Z',
          'isValid': true,
        };

        final config = ConfluenceConfig.fromJson(json);

        expect(config.enabled, isTrue);
        expect(config.baseUrl, equals('https://example.atlassian.net'));
        expect(config.token, equals('test-token'));
        expect(config.isValid, isTrue);
        expect(config.lastValidated, isNotNull);
      });

      test('handles null values in JSON', () {
        final json = {
          'enabled': false,
          'baseUrl': '',
          'token': '',
          'lastValidated': null,
          'isValid': false,
        };

        final config = ConfluenceConfig.fromJson(json);

        expect(config.enabled, isFalse);
        expect(config.baseUrl, isEmpty);
        expect(config.token, isEmpty);
        expect(config.lastValidated, isNull);
        expect(config.isValid, isFalse);
      });
    });
  });
}