import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/models/confluence_page.dart';

void main() {
  group('ConfluencePage', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final page = ConfluencePage(
          id: '123456',
          title: 'Test Page',
          url: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          version: 1,
          spaceKey: 'TEST',
        );

        expect(page.id, equals('123456'));
        expect(page.title, equals('Test Page'));
        expect(page.url, contains('123456'));
        expect(page.version, equals(1));
        expect(page.spaceKey, equals('TEST'));
        expect(page.content, isNull);
        expect(page.ancestors, isNull);
      });

      test('creates instance with all fields', () {
        final content = ConfluencePageContent(
          value: '<p>Test content</p>',
          representation: 'storage',
        );
        final ancestors = ConfluencePageAncestors(
          results: [
            ConfluencePageAncestor(id: '111', title: 'Parent Page'),
          ],
        );

        final page = ConfluencePage(
          id: '123456',
          title: 'Test Page',
          url: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          version: 2,
          spaceKey: 'TEST',
          content: content,
          ancestors: ancestors,
        );

        expect(page.content, equals(content));
        expect(page.ancestors, equals(ancestors));
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = ConfluencePage(
          id: '123456',
          title: 'Original Title',
          url: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Original',
          version: 1,
          spaceKey: 'TEST',
        );

        final updated = original.copyWith(
          title: 'Updated Title',
          version: 2,
        );

        expect(updated.id, equals(original.id));
        expect(updated.title, equals('Updated Title'));
        expect(updated.url, equals(original.url));
        expect(updated.version, equals(2));
        expect(updated.spaceKey, equals(original.spaceKey));
      });
    });

    group('extractPageIdFromUrl', () {
      test('extracts page ID from valid Confluence URL', () {
        const url = 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page';
        final pageId = ConfluencePage.extractPageIdFromUrl(url);
        expect(pageId, equals('123456'));
      });

      test('extracts page ID from URL without title', () {
        const url = 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/';
        final pageId = ConfluencePage.extractPageIdFromUrl(url);
        expect(pageId, equals('123456'));
      });

      test('extracts page ID from URL without trailing slash', () {
        const url = 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456';
        final pageId = ConfluencePage.extractPageIdFromUrl(url);
        expect(pageId, equals('123456'));
      });

      test('returns null for invalid URL format', () {
        const url = 'https://example.atlassian.net/wiki/spaces/TEST/invalid/123456';
        final pageId = ConfluencePage.extractPageIdFromUrl(url);
        expect(pageId, isNull);
      });

      test('returns null for non-Confluence URL', () {
        const url = 'https://google.com/search?q=test';
        final pageId = ConfluencePage.extractPageIdFromUrl(url);
        expect(pageId, isNull);
      });

      test('handles complex page titles with special characters', () {
        const url = 'https://example.atlassian.net/wiki/spaces/TEST/pages/789012/Complex%20Title%20With%20Spaces';
        final pageId = ConfluencePage.extractPageIdFromUrl(url);
        expect(pageId, equals('789012'));
      });
    });

    group('isValidConfluencePageUrl', () {
      test('returns true for valid Confluence page URL', () {
        const url = 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page';
        expect(ConfluencePage.isValidConfluencePageUrl(url), isTrue);
      });

      test('returns false for invalid URL format', () {
        const url = 'https://example.atlassian.net/wiki/spaces/TEST/invalid/123456';
        expect(ConfluencePage.isValidConfluencePageUrl(url), isFalse);
      });

      test('returns false for non-Confluence URL', () {
        const url = 'https://google.com/search?q=test';
        expect(ConfluencePage.isValidConfluencePageUrl(url), isFalse);
      });
    });

    group('equality and hashCode', () {
      test('equal objects have same hashCode', () {
        final page1 = ConfluencePage(
          id: '123456',
          title: 'Test Page',
          url: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          version: 1,
          spaceKey: 'TEST',
        );

        final page2 = ConfluencePage(
          id: '123456',
          title: 'Test Page',
          url: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          version: 1,
          spaceKey: 'TEST',
        );

        expect(page1, equals(page2));
        expect(page1.hashCode, equals(page2.hashCode));
      });

      test('different objects are not equal', () {
        final page1 = ConfluencePage(
          id: '123456',
          title: 'Test Page',
          url: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          version: 1,
          spaceKey: 'TEST',
        );

        final page2 = ConfluencePage(
          id: '789012',
          title: 'Test Page',
          url: 'https://example.atlassian.net/wiki/spaces/TEST/pages/789012/Test+Page',
          version: 1,
          spaceKey: 'TEST',
        );

        expect(page1, isNot(equals(page2)));
      });
    });

    group('JSON serialization', () {
      test('serializes to JSON correctly', () {
        final page = ConfluencePage(
          id: '123456',
          title: 'Test Page',
          url: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          version: 1,
          spaceKey: 'TEST',
        );

        final json = page.toJson();

        expect(json['id'], equals('123456'));
        expect(json['title'], equals('Test Page'));
        expect(json['version'], equals(1));
        expect(json['spaceKey'], equals('TEST'));
      });

      test('deserializes from JSON correctly', () {
        final json = {
          'id': '123456',
          'title': 'Test Page',
          'url': 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          'version': 1,
          'spaceKey': 'TEST',
        };

        final page = ConfluencePage.fromJson(json);

        expect(page.id, equals('123456'));
        expect(page.title, equals('Test Page'));
        expect(page.version, equals(1));
        expect(page.spaceKey, equals('TEST'));
      });
    });
  });

  group('ConfluencePageContent', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final content = ConfluencePageContent(
          value: '<p>Test content</p>',
          representation: 'storage',
        );

        expect(content.value, equals('<p>Test content</p>'));
        expect(content.representation, equals('storage'));
      });
    });

    group('equality and hashCode', () {
      test('equal objects have same hashCode', () {
        final content1 = ConfluencePageContent(
          value: '<p>Test content</p>',
          representation: 'storage',
        );

        final content2 = ConfluencePageContent(
          value: '<p>Test content</p>',
          representation: 'storage',
        );

        expect(content1, equals(content2));
        expect(content1.hashCode, equals(content2.hashCode));
      });

      test('different objects are not equal', () {
        final content1 = ConfluencePageContent(
          value: '<p>Test content</p>',
          representation: 'storage',
        );

        final content2 = ConfluencePageContent(
          value: '<p>Different content</p>',
          representation: 'storage',
        );

        expect(content1, isNot(equals(content2)));
      });
    });

    group('toString', () {
      test('truncates long content in string representation', () {
        final longContent = 'A' * 200;
        final content = ConfluencePageContent(
          value: longContent,
          representation: 'storage',
        );

        final stringRepresentation = content.toString();

        expect(stringRepresentation, contains('storage'));
        expect(stringRepresentation, contains('...'));
        expect(stringRepresentation.length, lessThan(longContent.length + 100));
      });

      test('shows full content for short content', () {
        final content = ConfluencePageContent(
          value: '<p>Short content</p>',
          representation: 'storage',
        );

        final stringRepresentation = content.toString();

        expect(stringRepresentation, contains('storage'));
        expect(stringRepresentation, contains('<p>Short content</p>'));
        expect(stringRepresentation, isNot(contains('...')));
      });
    });

    group('JSON serialization', () {
      test('serializes to JSON correctly', () {
        final content = ConfluencePageContent(
          value: '<p>Test content</p>',
          representation: 'storage',
        );

        final json = content.toJson();

        expect(json['value'], equals('<p>Test content</p>'));
        expect(json['representation'], equals('storage'));
      });

      test('deserializes from JSON correctly', () {
        final json = {
          'value': '<p>Test content</p>',
          'representation': 'storage',
        };

        final content = ConfluencePageContent.fromJson(json);

        expect(content.value, equals('<p>Test content</p>'));
        expect(content.representation, equals('storage'));
      });
    });
  });

  group('ConfluencePageAncestors', () {
    group('constructor', () {
      test('creates instance with ancestor list', () {
        final ancestors = ConfluencePageAncestors(
          results: [
            ConfluencePageAncestor(id: '111', title: 'Parent Page'),
            ConfluencePageAncestor(id: '222', title: 'Grandparent Page'),
          ],
        );

        expect(ancestors.results, hasLength(2));
        expect(ancestors.results[0].id, equals('111'));
        expect(ancestors.results[1].id, equals('222'));
      });
    });

    group('JSON serialization', () {
      test('serializes to JSON correctly', () {
        final ancestors = ConfluencePageAncestors(
          results: [
            ConfluencePageAncestor(id: '111', title: 'Parent Page'),
          ],
        );

        final json = ancestors.toJson();

        expect(json['results'], isA<List>());
        final firstResult = (json['results'] as List)[0] as ConfluencePageAncestor;
        expect(firstResult.id, equals('111'));
        expect(firstResult.title, equals('Parent Page'));
      });

      test('deserializes from JSON correctly', () {
        final json = {
          'results': [
            {'id': '111', 'title': 'Parent Page'},
            {'id': '222', 'title': 'Grandparent Page'},
          ],
        };

        final ancestors = ConfluencePageAncestors.fromJson(json);

        expect(ancestors.results, hasLength(2));
        expect(ancestors.results[0].id, equals('111'));
        expect(ancestors.results[1].title, equals('Grandparent Page'));
      });
    });
  });

  group('ConfluencePageAncestor', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final ancestor = ConfluencePageAncestor(
          id: '111',
          title: 'Parent Page',
        );

        expect(ancestor.id, equals('111'));
        expect(ancestor.title, equals('Parent Page'));
      });
    });

    group('equality and hashCode', () {
      test('equal objects have same hashCode', () {
        final ancestor1 = ConfluencePageAncestor(
          id: '111',
          title: 'Parent Page',
        );

        final ancestor2 = ConfluencePageAncestor(
          id: '111',
          title: 'Parent Page',
        );

        expect(ancestor1, equals(ancestor2));
        expect(ancestor1.hashCode, equals(ancestor2.hashCode));
      });
    });

    group('JSON serialization', () {
      test('serializes to JSON correctly', () {
        final ancestor = ConfluencePageAncestor(
          id: '111',
          title: 'Parent Page',
        );

        final json = ancestor.toJson();

        expect(json['id'], equals('111'));
        expect(json['title'], equals('Parent Page'));
      });

      test('deserializes from JSON correctly', () {
        final json = {
          'id': '111',
          'title': 'Parent Page',
        };

        final ancestor = ConfluencePageAncestor.fromJson(json);

        expect(ancestor.id, equals('111'));
        expect(ancestor.title, equals('Parent Page'));
      });
    });
  });
}