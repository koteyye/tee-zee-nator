import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/models/confluence_link.dart';

void main() {
  group('ConfluenceLink', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final processedAt = DateTime.now();
        final link = ConfluenceLink(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          extractedContent: 'Test content from page',
          processedAt: processedAt,
        );

        expect(link.originalUrl, contains('123456'));
        expect(link.pageId, equals('123456'));
        expect(link.extractedContent, equals('Test content from page'));
        expect(link.processedAt, equals(processedAt));
        expect(link.isValid, isTrue); // Default value
        expect(link.errorMessage, isNull);
      });

      test('creates instance with all fields', () {
        final processedAt = DateTime.now();
        final link = ConfluenceLink(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          extractedContent: 'Test content from page',
          processedAt: processedAt,
          isValid: false,
          errorMessage: 'Processing failed',
        );

        expect(link.isValid, isFalse);
        expect(link.errorMessage, equals('Processing failed'));
      });
    });

    group('factory constructors', () {
      test('failed() creates failed link with error information', () {
        final link = ConfluenceLink.failed(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          errorMessage: 'Page not found',
        );

        expect(link.originalUrl, contains('123456'));
        expect(link.pageId, equals('123456'));
        expect(link.extractedContent, isEmpty);
        expect(link.isValid, isFalse);
        expect(link.errorMessage, equals('Page not found'));
        expect(link.processedAt, isNotNull);
      });

      test('success() creates successful link with extracted content', () {
        final link = ConfluenceLink.success(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          extractedContent: 'Successfully extracted content',
        );

        expect(link.originalUrl, contains('123456'));
        expect(link.pageId, equals('123456'));
        expect(link.extractedContent, equals('Successfully extracted content'));
        expect(link.isValid, isTrue);
        expect(link.errorMessage, isNull);
        expect(link.processedAt, isNotNull);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = ConfluenceLink(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          extractedContent: 'Original content',
          processedAt: DateTime.now(),
          isValid: false,
        );

        final updated = original.copyWith(
          extractedContent: 'Updated content',
          isValid: true,
        );

        expect(updated.originalUrl, equals(original.originalUrl));
        expect(updated.pageId, equals(original.pageId));
        expect(updated.extractedContent, equals('Updated content'));
        expect(updated.isValid, isTrue);
        expect(updated.processedAt, equals(original.processedAt));
      });
    });

    group('isFresh', () {
      test('returns true for recently processed link', () {
        final link = ConfluenceLink(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          extractedContent: 'Test content',
          processedAt: DateTime.now().subtract(Duration(minutes: 5)),
        );

        expect(link.isFresh(), isTrue);
      });

      test('returns false for old processed link', () {
        final link = ConfluenceLink(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          extractedContent: 'Test content',
          processedAt: DateTime.now().subtract(Duration(hours: 2)),
        );

        expect(link.isFresh(), isFalse);
      });

      test('respects custom TTL', () {
        final link = ConfluenceLink(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          extractedContent: 'Test content',
          processedAt: DateTime.now().subtract(Duration(minutes: 45)),
        );

        expect(link.isFresh(ttl: Duration(minutes: 30)), isFalse);
        expect(link.isFresh(ttl: Duration(hours: 1)), isTrue);
      });
    });

    group('contentMarker', () {
      test('returns content marker for valid link', () {
        final link = ConfluenceLink(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          extractedContent: 'Test content from page',
          processedAt: DateTime.now(),
          isValid: true,
        );

        expect(link.contentMarker, equals('@conf-cnt Test content from page@'));
      });

      test('returns original URL for invalid link', () {
        final link = ConfluenceLink(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          extractedContent: '',
          processedAt: DateTime.now(),
          isValid: false,
        );

        expect(link.contentMarker, equals(link.originalUrl));
      });

      test('returns original URL for link with empty content', () {
        final link = ConfluenceLink(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          extractedContent: '',
          processedAt: DateTime.now(),
          isValid: true,
        );

        expect(link.contentMarker, equals(link.originalUrl));
      });
    });

    group('extractPageIdFromUrl', () {
      test('extracts page ID from valid Confluence URL', () {
        const url = 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page';
        final pageId = ConfluenceLink.extractPageIdFromUrl(url);
        expect(pageId, equals('123456'));
      });

      test('extracts page ID from URL without title', () {
        const url = 'https://example.atlassian.net/wiki/spaces/TEST/pages/789012/';
        final pageId = ConfluenceLink.extractPageIdFromUrl(url);
        expect(pageId, equals('789012'));
      });

      test('returns null for invalid URL format', () {
        const url = 'https://example.atlassian.net/wiki/spaces/TEST/invalid/123456';
        final pageId = ConfluenceLink.extractPageIdFromUrl(url);
        expect(pageId, isNull);
      });

      test('returns null for non-Confluence URL', () {
        const url = 'https://google.com/search?q=test';
        final pageId = ConfluenceLink.extractPageIdFromUrl(url);
        expect(pageId, isNull);
      });
    });

    group('isValidConfluenceUrl', () {
      test('returns true for valid Confluence URL with matching base URL', () {
        const url = 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page';
        const baseUrl = 'https://example.atlassian.net';
        
        expect(ConfluenceLink.isValidConfluenceUrl(url, baseUrl), isTrue);
      });

      test('returns false for URL with different domain', () {
        const url = 'https://different.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page';
        const baseUrl = 'https://example.atlassian.net';
        
        expect(ConfluenceLink.isValidConfluenceUrl(url, baseUrl), isFalse);
      });

      test('returns false for non-wiki URL', () {
        const url = 'https://example.atlassian.net/jira/browse/TEST-123';
        const baseUrl = 'https://example.atlassian.net';
        
        expect(ConfluenceLink.isValidConfluenceUrl(url, baseUrl), isFalse);
      });

      test('returns false for invalid URL format', () {
        const url = 'not-a-valid-url';
        const baseUrl = 'https://example.atlassian.net';
        
        expect(ConfluenceLink.isValidConfluenceUrl(url, baseUrl), isFalse);
      });

      test('returns false for URL without page ID', () {
        const url = 'https://example.atlassian.net/wiki/spaces/TEST/overview';
        const baseUrl = 'https://example.atlassian.net';
        
        expect(ConfluenceLink.isValidConfluenceUrl(url, baseUrl), isFalse);
      });

      test('handles base URL with trailing slash', () {
        const url = 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page';
        const baseUrl = 'https://example.atlassian.net/';
        
        expect(ConfluenceLink.isValidConfluenceUrl(url, baseUrl), isTrue);
      });
    });

    group('equality and hashCode', () {
      test('equal objects have same hashCode', () {
        final processedAt = DateTime.now();
        final link1 = ConfluenceLink(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          extractedContent: 'Test content',
          processedAt: processedAt,
          isValid: true,
        );

        final link2 = ConfluenceLink(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          extractedContent: 'Test content',
          processedAt: processedAt,
          isValid: true,
        );

        expect(link1, equals(link2));
        expect(link1.hashCode, equals(link2.hashCode));
      });

      test('different objects are not equal', () {
        final link1 = ConfluenceLink(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          extractedContent: 'Test content',
          processedAt: DateTime.now(),
        );

        final link2 = ConfluenceLink(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/789012/Test+Page',
          pageId: '789012',
          extractedContent: 'Test content',
          processedAt: DateTime.now(),
        );

        expect(link1, isNot(equals(link2)));
      });
    });

    group('toString', () {
      test('includes key information in string representation', () {
        final link = ConfluenceLink(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          extractedContent: 'Test content from page',
          processedAt: DateTime.now(),
          isValid: true,
        );

        final stringRepresentation = link.toString();

        expect(stringRepresentation, contains('123456'));
        expect(stringRepresentation, contains('isValid: true'));
        expect(stringRepresentation, contains('contentLength: 22'));
      });
    });

    group('JSON serialization', () {
      test('serializes to JSON correctly', () {
        final processedAt = DateTime.now();
        final link = ConfluenceLink(
          originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          extractedContent: 'Test content',
          processedAt: processedAt,
          isValid: true,
        );

        final json = link.toJson();

        expect(json['originalUrl'], contains('123456'));
        expect(json['pageId'], equals('123456'));
        expect(json['extractedContent'], equals('Test content'));
        expect(json['isValid'], isTrue);
        expect(json['processedAt'], isNotNull);
      });

      test('deserializes from JSON correctly', () {
        final json = {
          'originalUrl': 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          'pageId': '123456',
          'extractedContent': 'Test content',
          'processedAt': '2024-01-01T12:00:00.000Z',
          'isValid': true,
          'errorMessage': null,
        };

        final link = ConfluenceLink.fromJson(json);

        expect(link.originalUrl, contains('123456'));
        expect(link.pageId, equals('123456'));
        expect(link.extractedContent, equals('Test content'));
        expect(link.isValid, isTrue);
        expect(link.errorMessage, isNull);
        expect(link.processedAt, isNotNull);
      });

      test('handles error message in JSON', () {
        final json = {
          'originalUrl': 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          'pageId': '123456',
          'extractedContent': '',
          'processedAt': '2024-01-01T12:00:00.000Z',
          'isValid': false,
          'errorMessage': 'Page not found',
        };

        final link = ConfluenceLink.fromJson(json);

        expect(link.isValid, isFalse);
        expect(link.errorMessage, equals('Page not found'));
        expect(link.extractedContent, isEmpty);
      });
    });
  });
}