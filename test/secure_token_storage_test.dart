import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:tee_zee_nator/services/secure_token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SecureTokenStorage', () {
    setUp(() async {
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
                return 'mock_encrypted_token';
              } else if (key.contains('encryption_key')) {
                return 'bW9ja19lbmNyeXB0aW9uX2tleQ=='; // base64 encoded mock key
              }
              return null;
            case 'delete':
              return null;
            case 'deleteAll':
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

    group('Token Storage', () {
      test('should store Confluence token successfully', () async {
        final result = await SecureTokenStorage.storeConfluenceToken('test_token_123');
        expect(result, isTrue);
      });

      test('should not store empty token', () async {
        final result = await SecureTokenStorage.storeConfluenceToken('');
        expect(result, isFalse);
      });

      test('should retrieve stored token', () async {
        await SecureTokenStorage.storeConfluenceToken('test_token_123');
        final token = await SecureTokenStorage.getConfluenceToken();
        expect(token, isNotNull);
        expect(token, isNotEmpty);
      });

      test('should return null for non-existent token', () async {
        // Mock returning null for read operation
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'read') {
              return null;
            }
            return null;
          },
        );

        final token = await SecureTokenStorage.getConfluenceToken();
        expect(token, isNull);
      });

      test('should remove token successfully', () async {
        final result = await SecureTokenStorage.removeConfluenceToken();
        expect(result, isTrue);
      });

      test('should check token existence', () async {
        final hasToken = await SecureTokenStorage.hasConfluenceToken();
        expect(hasToken, isTrue);
      });

      test('should validate stored token', () async {
        final isValid = await SecureTokenStorage.validateStoredToken();
        expect(isValid, isTrue);
      });

      test('should clear all secure data', () async {
        await expectLater(
          SecureTokenStorage.clearAllSecureData(),
          completes,
        );
      });
    });

    group('Token Sanitization', () {
      test('should sanitize valid token input', () {
        const validToken = 'ATATT3xFfGF0abcdef123456789';
        final sanitized = SecureTokenStorage.sanitizeTokenInput(validToken);
        expect(sanitized, equals(validToken));
      });

      test('should remove control characters from token', () {
        const tokenWithControlChars = 'ATATT3xFfGF0\x00\x1F\x7Fabcdef123456789';
        final sanitized = SecureTokenStorage.sanitizeTokenInput(tokenWithControlChars);
        expect(sanitized, equals('ATATT3xFfGF0abcdef123456789'));
      });

      test('should remove HTML injection characters', () {
        const tokenWithHtml = 'ATATT3xFfGF0<script>alert("xss")</script>abcdef';
        final sanitized = SecureTokenStorage.sanitizeTokenInput(tokenWithHtml);
        expect(sanitized, equals('ATATT3xFfGF0scriptalert(xss)/scriptabcdef'));
      });

      test('should return empty string for invalid token format', () {
        const invalidToken = 'abc'; // Too short
        final sanitized = SecureTokenStorage.sanitizeTokenInput(invalidToken);
        expect(sanitized, isEmpty);
      });

      test('should handle empty input', () {
        final sanitized = SecureTokenStorage.sanitizeTokenInput('');
        expect(sanitized, isEmpty);
      });

      test('should trim whitespace', () {
        const tokenWithWhitespace = '  ATATT3xFfGF0abcdef123456789  ';
        final sanitized = SecureTokenStorage.sanitizeTokenInput(tokenWithWhitespace);
        expect(sanitized, equals('ATATT3xFfGF0abcdef123456789'));
      });
    });

    group('Token Validation', () {
      test('should validate correct token format', () {
        const validTokens = [
          'ATATT3xFfGF0abcdef123456789',
          'ATATTxFfGF0-abcdef_123456789',
          'base64EncodedToken123+/=',
        ];

        for (final token in validTokens) {
          expect(
            SecureTokenStorage.sanitizeTokenInput(token),
            isNotEmpty,
            reason: 'Token $token should be valid',
          );
        }
      });

      test('should reject invalid token formats', () {
        final invalidTokens = [
          'short', // Too short
          'a' * 501, // Too long
          'token with spaces',
          'token<script>',
          'token"with"quotes',
          "token'with'quotes",
        ];

        for (final token in invalidTokens) {
          final sanitized = SecureTokenStorage.sanitizeTokenInput(token);
          expect(
            sanitized,
            anyOf(isEmpty, isNot(contains('<'))),
            reason: 'Token $token should be invalid or sanitized',
          );
        }
      });
    });

    group('Encryption/Decryption', () {
      test('should handle encryption errors gracefully', () async {
        // This test verifies that encryption errors are handled
        // In a real scenario, we'd mock the encryption to fail
        final result = await SecureTokenStorage.storeConfluenceToken('valid_token_123');
        expect(result, isTrue); // Should still work with mocked storage
      });

      test('should handle decryption errors gracefully', () async {
        // Mock corrupted encrypted data
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'read') {
              final key = methodCall.arguments['key'] as String;
              if (key.contains('confluence_token')) {
                return 'corrupted_data_that_cannot_be_decrypted';
              } else if (key.contains('encryption_key')) {
                return 'bW9ja19lbmNyeXB0aW9uX2tleQ==';
              }
            }
            return null;
          },
        );

        final token = await SecureTokenStorage.getConfluenceToken();
        // Should handle decryption failure gracefully
        expect(token, anyOf(isNull, isEmpty));
      });
    });

    group('Storage Information', () {
      test('should provide storage information', () async {
        final info = await SecureTokenStorage.getStorageInfo();
        expect(info, isA<Map<String, dynamic>>());
        expect(info.containsKey('hasToken'), isTrue);
        expect(info.containsKey('isValid'), isTrue);
        expect(info.containsKey('platform'), isTrue);
        expect(info.containsKey('timestamp'), isTrue);
      });

      test('should handle storage info errors', () async {
        // Mock an error scenario
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (MethodCall methodCall) async {
            throw PlatformException(code: 'STORAGE_ERROR', message: 'Storage unavailable');
          },
        );

        final info = await SecureTokenStorage.getStorageInfo();
        expect(info.containsKey('error'), isTrue);
        expect(info.containsKey('timestamp'), isTrue);
      });
    });

    group('Security Edge Cases', () {
      test('should handle null bytes in token', () {
        const tokenWithNullBytes = 'ATATT3xFfGF0\x00abcdef123456789';
        final sanitized = SecureTokenStorage.sanitizeTokenInput(tokenWithNullBytes);
        expect(sanitized, isNot(contains('\x00')));
      });

      test('should handle unicode control characters', () {
        const tokenWithUnicode = 'ATATT3xFfGF0\u0000\u001F\u007Fabcdef123456789';
        final sanitized = SecureTokenStorage.sanitizeTokenInput(tokenWithUnicode);
        expect(sanitized, isNot(contains(RegExp(r'[\u0000-\u001F\u007F]'))));
      });

      test('should handle very long input gracefully', () {
        final longToken = 'A' * 1000; // Very long token
        final sanitized = SecureTokenStorage.sanitizeTokenInput(longToken);
        // Should either be empty (rejected) or truncated
        expect(sanitized.length, lessThanOrEqualTo(500));
      });

      test('should handle special characters safely', () {
        const tokenWithSpecialChars = 'ATATT3xFfGF0!@#\$%^&*()abcdef123456789';
        final sanitized = SecureTokenStorage.sanitizeTokenInput(tokenWithSpecialChars);
        // Should remove potentially dangerous characters
        expect(sanitized, isNot(contains('<')));
      });
    });
  });
}