import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/services/input_sanitizer.dart';

void main() {
  group('InputSanitizer', () {
    group('Base URL Sanitization', () {
      test('should sanitize valid Confluence URL', () {
        const validUrl = 'https://company.atlassian.net';
        final sanitized = InputSanitizer.sanitizeBaseUrl(validUrl);
        expect(sanitized, equals(validUrl));
      });

      test('should upgrade HTTP to HTTPS', () {
        const httpUrl = 'http://company.atlassian.net';
        final sanitized = InputSanitizer.sanitizeBaseUrl(httpUrl);
        expect(sanitized, equals('https://company.atlassian.net'));
      });

      test('should remove trailing slashes', () {
        const urlWithSlashes = 'https://company.atlassian.net///';
        final sanitized = InputSanitizer.sanitizeBaseUrl(urlWithSlashes);
        expect(sanitized, equals('https://company.atlassian.net'));
      });

      test('should remove control characters', () {
        const urlWithControlChars = 'https://company.atlassian.net\x00\x1F\x7F';
        final sanitized = InputSanitizer.sanitizeBaseUrl(urlWithControlChars);
        expect(sanitized, equals('https://company.atlassian.net'));
      });

      test('should reject invalid URL formats', () {
        const invalidUrls = [
          'not-a-url',
          'ftp://company.atlassian.net',
          'javascript:alert("xss")',
          'data:text/html,<script>alert("xss")</script>',
          '',
        ];

        for (final url in invalidUrls) {
          final sanitized = InputSanitizer.sanitizeBaseUrl(url);
          expect(sanitized, isEmpty, reason: 'URL $url should be rejected');
        }
      });

      test('should remove dangerous patterns', () {
        const dangerousUrl = 'https://company.atlassian.net<script>alert("xss")</script>';
        final sanitized = InputSanitizer.sanitizeBaseUrl(dangerousUrl);
        expect(sanitized, isNot(contains('<script>')));
        expect(sanitized, isNot(contains('alert')));
      });

      test('should handle whitespace correctly', () {
        const urlWithWhitespace = '  https://company.atlassian.net  ';
        final sanitized = InputSanitizer.sanitizeBaseUrl(urlWithWhitespace);
        expect(sanitized, equals('https://company.atlassian.net'));
      });
    });

    group('API Token Sanitization', () {
      test('should sanitize valid API token', () {
        const validToken = 'ATATT3xFfGF0abcdef123456789';
        final sanitized = InputSanitizer.sanitizeApiToken(validToken);
        expect(sanitized, equals(validToken));
      });

      test('should remove dangerous characters', () {
        const tokenWithDangerousChars = 'ATATT3xFfGF0<script>alert("xss")</script>';
        final sanitized = InputSanitizer.sanitizeApiToken(tokenWithDangerousChars);
        expect(sanitized, isNot(contains('<')));
        expect(sanitized, isNot(contains('>')));
        expect(sanitized, isNot(contains('"')));
        expect(sanitized, isNot(contains("'")));
      });

      test('should remove control characters', () {
        const tokenWithControlChars = 'ATATT3xFfGF0\x00\x1F\x7Fabcdef';
        final sanitized = InputSanitizer.sanitizeApiToken(tokenWithControlChars);
        expect(sanitized, isNot(contains('\x00')));
        expect(sanitized, isNot(contains('\x1F')));
        expect(sanitized, isNot(contains('\x7F')));
      });

      test('should remove whitespace', () {
        const tokenWithSpaces = 'ATATT3xFfGF0 abcdef 123456789';
        final sanitized = InputSanitizer.sanitizeApiToken(tokenWithSpaces);
        expect(sanitized, isNot(contains(' ')));
      });

      test('should reject invalid token formats', () {
        final invalidTokens = [
          'short', // Too short
          'a' * 501, // Too long
          'token with spaces',
          '',
        ];

        for (final token in invalidTokens) {
          final sanitized = InputSanitizer.sanitizeApiToken(token);
          expect(sanitized, anyOf(isEmpty, isNot(contains(' '))),
              reason: 'Token $token should be rejected or sanitized');
        }
      });

      test('should handle empty input', () {
        final sanitized = InputSanitizer.sanitizeApiToken('');
        expect(sanitized, isEmpty);
      });
    });

    group('Text Content Sanitization', () {
      test('should sanitize plain text content', () {
        const plainText = 'This is plain text content.';
        final sanitized = InputSanitizer.sanitizeTextContent(plainText);
        expect(sanitized, equals(plainText));
      });

      test('should remove script tags', () {
        const textWithScript = 'Hello <script>alert("xss")</script> world';
        final sanitized = InputSanitizer.sanitizeTextContent(textWithScript);
        expect(sanitized, isNot(contains('<script>')));
        expect(sanitized, isNot(contains('alert')));
      });

      test('should remove HTML tags by default', () {
        const textWithHtml = 'Hello <b>bold</b> and <i>italic</i> text';
        final sanitized = InputSanitizer.sanitizeTextContent(textWithHtml);
        expect(sanitized, isNot(contains('<b>')));
        expect(sanitized, isNot(contains('<i>')));
        expect(sanitized, contains('bold'));
        expect(sanitized, contains('italic'));
      });

      test('should allow safe HTML when specified', () {
        const textWithHtml = 'Hello <b>bold</b> text';
        final sanitized = InputSanitizer.sanitizeTextContent(textWithHtml, allowHtml: true);
        expect(sanitized, contains('<b>'));
        expect(sanitized, contains('</b>'));
      });

      test('should remove dangerous HTML even when allowing HTML', () {
        const textWithDangerousHtml = 'Hello <script>alert("xss")</script> <b>bold</b>';
        final sanitized = InputSanitizer.sanitizeTextContent(textWithDangerousHtml, allowHtml: true);
        expect(sanitized, isNot(contains('<script>')));
        expect(sanitized, contains('<b>'));
      });

      test('should remove SQL injection patterns', () {
        const textWithSql = 'Hello SELECT * FROM users WHERE id = 1';
        final sanitized = InputSanitizer.sanitizeTextContent(textWithSql);
        expect(sanitized, isNot(contains('SELECT')));
      });

      test('should remove command injection patterns', () {
        const textWithCommand = 'Hello; rm -rf /; echo "dangerous"';
        final sanitized = InputSanitizer.sanitizeTextContent(textWithCommand);
        expect(sanitized, isNot(contains(';')));
        expect(sanitized, isNot(contains('|')));
      });

      test('should normalize whitespace', () {
        const textWithExtraSpaces = 'Hello    world\n\n\nwith   spaces';
        final sanitized = InputSanitizer.sanitizeTextContent(textWithExtraSpaces);
        expect(sanitized, equals('Hello world with spaces'));
      });

      test('should handle empty input', () {
        final sanitized = InputSanitizer.sanitizeTextContent('');
        expect(sanitized, isEmpty);
      });
    });

    group('Page URL Sanitization', () {
      test('should sanitize valid Confluence page URL', () {
        const validUrl = 'https://company.atlassian.net/wiki/spaces/SPACE/pages/123456/Page+Title';
        final sanitized = InputSanitizer.sanitizePageUrl(validUrl);
        expect(sanitized, equals(validUrl));
      });

      test('should reject invalid page URL formats', () {
        const invalidUrls = [
          'not-a-url',
          'https://example.com/not-confluence',
          'javascript:alert("xss")',
          'data:text/html,<script>alert("xss")</script>',
          '',
        ];

        for (final url in invalidUrls) {
          final sanitized = InputSanitizer.sanitizePageUrl(url);
          expect(sanitized, anyOf(isEmpty, isNot(contains('javascript:'))),
              reason: 'URL $url should be rejected or sanitized');
        }
      });

      test('should remove dangerous patterns', () {
        const dangerousUrl = 'https://company.atlassian.net/wiki/spaces/SPACE/pages/123456<script>alert("xss")</script>';
        final sanitized = InputSanitizer.sanitizePageUrl(dangerousUrl);
        expect(sanitized, isNot(contains('<script>')));
      });

      test('should handle different Confluence URL formats', () {
        const validUrls = [
          'https://company.atlassian.net/wiki/spaces/SPACE/pages/123456/Page+Title',
          'https://company.atlassian.net/wiki/display/SPACE/Page+Title',
          'https://company.atlassian.net/pages/viewpage.action?pageId=123456',
        ];

        for (final url in validUrls) {
          final sanitized = InputSanitizer.sanitizePageUrl(url);
          expect(sanitized, isNotEmpty, reason: 'URL $url should be valid');
        }
      });
    });

    group('Confluence HTML Sanitization', () {
      test('should sanitize Confluence HTML content', () {
        const htmlContent = '<p>Hello <b>world</b></p>';
        final sanitized = InputSanitizer.sanitizeConfluenceHtml(htmlContent);
        expect(sanitized, equals('Hello world'));
      });

      test('should remove script tags from HTML', () {
        const htmlWithScript = '<p>Hello</p><script>alert("xss")</script><p>world</p>';
        final sanitized = InputSanitizer.sanitizeConfluenceHtml(htmlWithScript);
        expect(sanitized, isNot(contains('<script>')));
        expect(sanitized, contains('Hello'));
        expect(sanitized, contains('world'));
      });

      test('should decode HTML entities', () {
        const htmlWithEntities = '&lt;p&gt;Hello &amp; world&lt;/p&gt;';
        final sanitized = InputSanitizer.sanitizeConfluenceHtml(htmlWithEntities);
        expect(sanitized, contains('<p>'));
        expect(sanitized, contains('&'));
      });

      test('should remove all HTML tags', () {
        const complexHtml = '<div><p>Hello <b>bold</b> and <i>italic</i></p><ul><li>Item 1</li></ul></div>';
        final sanitized = InputSanitizer.sanitizeConfluenceHtml(complexHtml);
        expect(sanitized, isNot(contains('<')));
        expect(sanitized, isNot(contains('>')));
        expect(sanitized, contains('Hello'));
        expect(sanitized, contains('bold'));
        expect(sanitized, contains('italic'));
        expect(sanitized, contains('Item 1'));
      });

      test('should normalize whitespace in HTML', () {
        const htmlWithSpaces = '<p>Hello    world</p>\n\n<p>Another   paragraph</p>';
        final sanitized = InputSanitizer.sanitizeConfluenceHtml(htmlWithSpaces);
        expect(sanitized, equals('Hello world Another paragraph'));
      });

      test('should handle empty HTML', () {
        final sanitized = InputSanitizer.sanitizeConfluenceHtml('');
        expect(sanitized, isEmpty);
      });
    });

    group('File Path Sanitization', () {
      test('should sanitize valid file path', () {
        const validPath = 'documents/file.txt';
        final sanitized = InputSanitizer.sanitizeFilePath(validPath);
        expect(sanitized, equals(validPath));
      });

      test('should remove path traversal patterns', () {
        const dangerousPath = '../../../etc/passwd';
        final sanitized = InputSanitizer.sanitizeFilePath(dangerousPath);
        expect(sanitized, isEmpty);
      });

      test('should remove dangerous characters', () {
        const pathWithDangerousChars = 'file<>:"|?*.txt';
        final sanitized = InputSanitizer.sanitizeFilePath(pathWithDangerousChars);
        expect(sanitized, isNot(contains('<')));
        expect(sanitized, isNot(contains('>')));
        expect(sanitized, isNot(contains(':')));
        expect(sanitized, isNot(contains('"')));
        expect(sanitized, isNot(contains('|')));
        expect(sanitized, isNot(contains('?')));
        expect(sanitized, isNot(contains('*')));
      });

      test('should handle empty path', () {
        final sanitized = InputSanitizer.sanitizeFilePath('');
        expect(sanitized, isEmpty);
      });
    });

    group('Utility Functions', () {
      test('should validate input length', () {
        const shortInput = 'short';
        final longInput = 'a' * 10001;
        
        expect(InputSanitizer.isValidInputLength(shortInput), isTrue);
        expect(InputSanitizer.isValidInputLength(longInput), isFalse);
        expect(InputSanitizer.isValidInputLength(longInput, maxLength: 20000), isTrue);
      });

      test('should check for safe characters', () {
        const safeText = 'Hello world 123!';
        const unsafeText = 'Hello\x00world';
        
        expect(InputSanitizer.containsOnlySafeCharacters(safeText), isTrue);
        expect(InputSanitizer.containsOnlySafeCharacters(unsafeText), isFalse);
      });

      test('should escape text for display', () {
        const textWithSpecialChars = 'Hello <b>"world"</b> & \'test\'';
        final escaped = InputSanitizer.escapeForDisplay(textWithSpecialChars);
        
        expect(escaped, contains('&lt;'));
        expect(escaped, contains('&gt;'));
        expect(escaped, contains('&quot;'));
        expect(escaped, contains('&amp;'));
        expect(escaped, contains('&#39;'));
      });

      test('should sanitize JSON input', () {
        const validJson = '{"key": "value", "number": 123}';
        const invalidJson = '{"key": "value", invalid}';
        
        final sanitizedValid = InputSanitizer.sanitizeJsonInput(validJson);
        final sanitizedInvalid = InputSanitizer.sanitizeJsonInput(invalidJson);
        
        expect(sanitizedValid, isNotNull);
        expect(sanitizedInvalid, isNull);
      });
    });

    group('Security Edge Cases', () {
      test('should handle null bytes', () {
        const textWithNullBytes = 'Hello\x00world';
        final sanitized = InputSanitizer.sanitizeTextContent(textWithNullBytes);
        expect(sanitized, isNot(contains('\x00')));
      });

      test('should handle unicode control characters', () {
        const textWithUnicode = 'Hello\u0000\u001F\u007Fworld';
        final sanitized = InputSanitizer.sanitizeTextContent(textWithUnicode);
        expect(sanitized, isNot(contains(RegExp(r'[\u0000-\u001F\u007F]'))));
      });

      test('should handle mixed content attacks', () {
        const mixedContent = 'Hello <script>alert("xss")</script> SELECT * FROM users; rm -rf /';
        final sanitized = InputSanitizer.sanitizeTextContent(mixedContent);
        
        expect(sanitized, isNot(contains('<script>')));
        expect(sanitized, isNot(contains('SELECT')));
        expect(sanitized, isNot(contains(';')));
      });

      test('should handle very long input', () {
        final longInput = 'A' * 50000;
        final sanitized = InputSanitizer.sanitizeTextContent(longInput);
        
        // Should complete without throwing
        expect(sanitized, isA<String>());
      });

      test('should handle nested HTML attacks', () {
        const nestedHtml = '<div><script><div>alert("xss")</div></script></div>';
        final sanitized = InputSanitizer.sanitizeTextContent(nestedHtml);
        
        expect(sanitized, isNot(contains('<script>')));
        expect(sanitized, isNot(contains('alert')));
      });

      test('should handle encoded attacks', () {
        const encodedAttack = '&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;';
        final sanitized = InputSanitizer.sanitizeTextContent(encodedAttack);
        
        // Should not decode and then execute dangerous content
        expect(sanitized, isNot(contains('alert')));
      });
    });
  });
}