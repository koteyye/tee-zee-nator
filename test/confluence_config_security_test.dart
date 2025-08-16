import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:tee_zee_nator/models/confluence_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConfluenceConfig Security', () {
    setUp(() {
      // Mock the secure storage channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'write':
              return null;
            case 'read':
              final key = methodCall.arguments['key'] as String;
              if (key.contains('confluence_token')) {
                return 'mock_encrypted_token_data';
              } else if (key.contains('encryption_key')) {
                return 'bW9ja19lbmNyeXB0aW9uX2tleQ==';
              }
              return null;
            case 'delete':
              return null;
            case 'containsKey':
              return true;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      );
    });

    group('Secure Configuration Creation', () {
      test('should create secure configuration with valid inputs', () async {
        final config = await ConfluenceConfig.createSecure(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'ATATT3xFfGF0abcdef123456789',
          isValid: true,
        );

        expect(config.enabled, isTrue);
        expect(config.baseUrl, equals('https://company.atlassian.net'));
        expect(config.token, startsWith('secure_'));
        expect(config.isValid, isTrue);
      });

      test('should sanitize base URL during creation', () async {
        final config = await ConfluenceConfig.createSecure(
          enabled: true,
          baseUrl: 'http://company.atlassian.net///',
          token: 'ATATT3xFfGF0abcdef123456789',
        );

        expect(config.baseUrl, equals('https://company.atlassian.net'));
      });

      test('should sanitize token during creation', () async {
        final config = await ConfluenceConfig.createSecure(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: '  ATATT3xFfGF0abcdef123456789  ',
        );

        expect(config.token, startsWith('secure_'));
      });

      test('should reject invalid base URL', () async {
        await expectLater(
          ConfluenceConfig.createSecure(
            enabled: true,
            baseUrl: 'invalid-url',
            token: 'ATATT3xFfGF0abcdef123456789',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should reject invalid token', () async {
        await expectLater(
          ConfluenceConfig.createSecure(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: 'invalid<script>alert("xss")</script>',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should allow disabled configuration with empty values', () async {
        final config = await ConfluenceConfig.createSecure(
          enabled: false,
          baseUrl: '',
          token: '',
        );

        expect(config.enabled, isFalse);
        expect(config.baseUrl, isEmpty);
        expect(config.token, isEmpty);
      });

      test('should handle storage failure', () async {
        // Mock storage failure
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'write') {
              throw PlatformException(code: 'STORAGE_ERROR', message: 'Storage failed');
            }
            return null;
          },
        );

        await expectLater(
          ConfluenceConfig.createSecure(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: 'ATATT3xFfGF0abcdef123456789',
          ),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('Secure Token Operations', () {
      test('should retrieve secure token', () async {
        final config = await ConfluenceConfig.createSecure(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'ATATT3xFfGF0abcdef123456789',
        );

        final retrievedToken = await config.getSecureToken();
        expect(retrievedToken, isNotNull);
        expect(retrievedToken, isNotEmpty);
      });

      test('should handle legacy token format', () async {
        const legacyConfig = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'legacy_token_123', // Not prefixed with 'secure_'
          isValid: true,
        );

        final retrievedToken = await legacyConfig.getSecureToken();
        expect(retrievedToken, equals('legacy_token_123'));
      });

      test('should update secure token', () async {
        final config = await ConfluenceConfig.createSecure(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'ATATT3xFfGF0abcdef123456789',
        );

        final updatedConfig = await config.updateSecureToken('ATATT3xFfGF0newtoken987654321');
        
        expect(updatedConfig.token, startsWith('secure_'));
        expect(updatedConfig.token, isNot(equals(config.token)));
        expect(updatedConfig.isValid, isFalse); // Should reset validation
      });

      test('should reject invalid token update', () async {
        final config = await ConfluenceConfig.createSecure(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'ATATT3xFfGF0abcdef123456789',
        );

        await expectLater(
          config.updateSecureToken('invalid<script>token'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should validate secure token', () async {
        final config = await ConfluenceConfig.createSecure(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'ATATT3xFfGF0abcdef123456789',
        );

        final isValid = await config.validateSecureToken();
        expect(isValid, isTrue);
      });

      test('should handle validation failure', () async {
        // Mock validation failure
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'read') {
              return null; // Simulate missing token
            }
            return null;
          },
        );

        final config = await ConfluenceConfig.createSecure(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'ATATT3xFfGF0abcdef123456789',
        );

        final isValid = await config.validateSecureToken();
        expect(isValid, isFalse);
      });

      test('should clear secure token', () async {
        final config = await ConfluenceConfig.createSecure(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'ATATT3xFfGF0abcdef123456789',
        );

        final clearedConfig = await config.clearSecureToken();
        
        expect(clearedConfig.token, isEmpty);
        expect(clearedConfig.isValid, isFalse);
        expect(clearedConfig.lastValidated, isNull);
      });
    });

    group('Input Sanitization Integration', () {
      test('should sanitize malicious base URL', () async {
        final config = await ConfluenceConfig.createSecure(
          enabled: true,
          baseUrl: 'https://company.atlassian.net<script>alert("xss")</script>',
          token: 'ATATT3xFfGF0abcdef123456789',
        );

        expect(config.baseUrl, isNot(contains('<script>')));
        expect(config.baseUrl, isNot(contains('alert')));
      });

      test('should sanitize malicious token', () async {
        await expectLater(
          ConfluenceConfig.createSecure(
            enabled: true,
            baseUrl: 'https://company.atlassian.net',
            token: 'ATATT3xFfGF0<script>alert("xss")</script>abcdef',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle control characters in inputs', () async {
        final config = await ConfluenceConfig.createSecure(
          enabled: true,
          baseUrl: 'https://company.atlassian.net\x00\x1F\x7F',
          token: 'ATATT3xFfGF0abcdef123456789',
        );

        expect(config.baseUrl, isNot(contains('\x00')));
        expect(config.baseUrl, isNot(contains('\x1F')));
        expect(config.baseUrl, isNot(contains('\x7F')));
      });

      test('should handle unicode control characters', () async {
        final config = await ConfluenceConfig.createSecure(
          enabled: true,
          baseUrl: 'https://company.atlassian.net\u0000\u001F',
          token: 'ATATT3xFfGF0abcdef123456789',
        );

        expect(config.baseUrl, isNot(contains('\u0000')));
        expect(config.baseUrl, isNot(contains('\u001F')));
      });
    });

    group('Security Edge Cases', () {
      test('should handle very long inputs', () async {
        final longUrl = 'https://company.atlassian.net/${'a' * 1000}';
        
        await expectLater(
          ConfluenceConfig.createSecure(
            enabled: true,
            baseUrl: longUrl,
            token: 'ATATT3xFfGF0abcdef123456789',
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('should handle empty secure token reference', () async {
        const config = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: '', // Empty token reference
          isValid: false,
        );

        final retrievedToken = await config.getSecureToken();
        expect(retrievedToken, isNull);
      });

      test('should handle corrupted token reference', () async {
        const config = ConfluenceConfig(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'secure_corrupted_reference',
          isValid: false,
        );

        // Mock corrupted storage
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'read') {
              throw PlatformException(code: 'DECRYPTION_ERROR', message: 'Cannot decrypt');
            }
            return null;
          },
        );

        final retrievedToken = await config.getSecureToken();
        expect(retrievedToken, isNull);
      });

      test('should handle concurrent token operations', () async {
        final config = await ConfluenceConfig.createSecure(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'ATATT3xFfGF0abcdef123456789',
        );

        // Simulate concurrent operations
        final futures = List.generate(5, (index) => config.getSecureToken());
        final results = await Future.wait(futures);

        // All should succeed and return the same token
        for (final result in results) {
          expect(result, isNotNull);
          expect(result, equals(results.first));
        }
      });

      test('should maintain security during copyWith operations', () async {
        final config = await ConfluenceConfig.createSecure(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'ATATT3xFfGF0abcdef123456789',
        );

        final copiedConfig = config.copyWith(enabled: false);
        
        // Token reference should be preserved
        expect(copiedConfig.token, equals(config.token));
        expect(copiedConfig.token, startsWith('secure_'));
      });
    });

    group('toString Security', () {
      test('should redact token in toString', () async {
        final config = await ConfluenceConfig.createSecure(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'ATATT3xFfGF0abcdef123456789',
        );

        final stringRepresentation = config.toString();
        
        expect(stringRepresentation, contains('[REDACTED]'));
        expect(stringRepresentation, isNot(contains('ATATT3xFfGF0abcdef123456789')));
        expect(stringRepresentation, isNot(contains('secure_')));
      });

      test('should not expose sensitive data in debug output', () async {
        final config = await ConfluenceConfig.createSecure(
          enabled: true,
          baseUrl: 'https://company.atlassian.net',
          token: 'ATATT3xFfGF0abcdef123456789',
        );

        // Verify that even the secure reference is not exposed
        final stringRepresentation = config.toString();
        expect(stringRepresentation, isNot(contains(config.token)));
      });
    });
  });
}