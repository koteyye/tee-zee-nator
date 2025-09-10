import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/services/confluence_content_processor.dart';
import 'package:tee_zee_nator/services/confluence_service.dart';
import 'package:tee_zee_nator/models/confluence_config.dart';

/// Mock ConfluenceService for testing
class MockConfluenceService extends ConfluenceService {
  final Map<String, String> _mockResponses = {};
  final Map<String, Exception> _mockErrors = {};
  
  void setMockResponse(String pageId, String content) {
    _mockResponses[pageId] = content;
  }
  
  void setMockError(String pageId, Exception error) {
    _mockErrors[pageId] = error;
  }
  
  void clearMocks() {
    _mockResponses.clear();
    _mockErrors.clear();
  }
  
  @override
  Future<String> getPageContent(String pageId) async {
    if (_mockErrors.containsKey(pageId)) {
      throw _mockErrors[pageId]!;
    }
    
    if (_mockResponses.containsKey(pageId)) {
      return _mockResponses[pageId]!;
    }
    
    throw Exception('No mock response configured for page ID: $pageId');
  }
}

void main() {
  group('ConfluenceContentProcessor', () {
    late ConfluenceContentProcessor processor;
    late MockConfluenceService mockConfluenceService;
    late ConfluenceConfig testConfig;

    setUp(() {
      mockConfluenceService = MockConfluenceService();
      processor = ConfluenceContentProcessor(mockConfluenceService);
      testConfig = const ConfluenceConfig(
        enabled: true,
        baseUrl: 'https://example.atlassian.net',
        token: 'test-token',
        isValid: true,
      );
    });

    tearDown(() {
      processor.dispose();
    });

    group('extractLinks', () {
      test('should extract valid Confluence URLs from text', () {
        const text = '''
        Check out this page: https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page
        And this one too: https://example.atlassian.net/wiki/spaces/DOCS/pages/789012/Another+Page
        This is not a Confluence link: https://google.com
        ''';

        final links = processor.extractLinks(text, testConfig.sanitizedBaseUrl);

        expect(links, hasLength(2));
        expect(links, contains('https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page'));
        expect(links, contains('https://example.atlassian.net/wiki/spaces/DOCS/pages/789012/Another+Page'));
        expect(links, isNot(contains('https://google.com')));
      });

      test('should handle URLs with trailing punctuation', () {
        const text = '''
        Check this link: https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page.
        And this one: https://example.atlassian.net/wiki/spaces/DOCS/pages/789012/Another+Page,
        Also this: https://example.atlassian.net/wiki/spaces/TEST/pages/345678/Third+Page!
        ''';

        final links = processor.extractLinks(text, testConfig.sanitizedBaseUrl);

        expect(links, hasLength(3));
        expect(links, contains('https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page'));
        expect(links, contains('https://example.atlassian.net/wiki/spaces/DOCS/pages/789012/Another+Page'));
        expect(links, contains('https://example.atlassian.net/wiki/spaces/TEST/pages/345678/Third+Page'));
      });

      test('should return empty list for text without Confluence links', () {
        const text = '''
        This is just regular text with some URLs:
        https://google.com
        https://github.com/user/repo
        https://stackoverflow.com/questions/123
        ''';

        final links = processor.extractLinks(text, testConfig.sanitizedBaseUrl);

        expect(links, isEmpty);
      });

      test('should return empty list for empty text', () {
        final links = processor.extractLinks('', testConfig.sanitizedBaseUrl);
        expect(links, isEmpty);
      });

      test('should return empty list for empty base URL', () {
        const text = 'https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page';
        final links = processor.extractLinks(text, '');
        expect(links, isEmpty);
      });

      test('should handle different domain formats', () {
        const text = '''
        HTTP link: http://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page
        HTTPS link: https://example.atlassian.net/wiki/spaces/DEV/pages/789012/Another+Page
        ''';

        final links = processor.extractLinks(text, testConfig.sanitizedBaseUrl);

        expect(links, hasLength(2));
        expect(links, contains('http://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page'));
        expect(links, contains('https://example.atlassian.net/wiki/spaces/DEV/pages/789012/Another+Page'));
      });

      test('should not extract duplicate links', () {
        const text = '''
        Same link twice: https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page
        And again: https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page
        ''';

        final links = processor.extractLinks(text, testConfig.sanitizedBaseUrl);

        expect(links, hasLength(1));
        expect(links.first, equals('https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page'));
      });
    });

    group('sanitizeContent', () {
      test('should remove HTML tags and normalize whitespace', () {
        const htmlContent = '''
        <h1>Title</h1>
        <p>This is a <strong>paragraph</strong> with <em>emphasis</em>.</p>
        <ul>
          <li>Item 1</li>
          <li>Item 2</li>
        </ul>
        <div>Some content in a div</div>
        ''';

        final sanitized = processor.sanitizeContent(htmlContent);

        expect(sanitized, equals('Title This is a paragraph with emphasis . Item 1 Item 2 Some content in a div'));
        expect(sanitized, isNot(contains('<')));
        expect(sanitized, isNot(contains('>')));
      });

      test('should remove script and style tags completely', () {
        const htmlContent = '''
        <p>Visible content</p>
        <script>alert('malicious code');</script>
        <style>body { color: red; }</style>
        <p>More visible content</p>
        ''';

        final sanitized = processor.sanitizeContent(htmlContent);

        expect(sanitized, equals('Visible content More visible content'));
        expect(sanitized, isNot(contains('alert')));
        expect(sanitized, isNot(contains('color: red')));
      });

      test('should decode HTML entities', () {
        const htmlContent = '''
        <p>Text with &amp; entities &lt;like&gt; &quot;quotes&quot; and &nbsp; spaces.</p>
        <p>Also &mdash; dashes &ndash; and &hellip; ellipsis.</p>
        <p>Copyright &copy; and trademark &trade; symbols.</p>
        ''';

        final sanitized = processor.sanitizeContent(htmlContent);

        expect(sanitized, contains('&'));
        expect(sanitized, contains('<like>'));
        expect(sanitized, contains('"quotes"'));
        expect(sanitized, contains('—'));
        expect(sanitized, contains('–'));
        expect(sanitized, contains('…'));
        expect(sanitized, contains('©'));
        expect(sanitized, contains('™'));
      });

      test('should normalize excessive whitespace and line breaks', () {
        const htmlContent = '''
        <p>Line 1</p>


        <p>Line 2</p>



        <p>Line 3</p>
        ''';

        final sanitized = processor.sanitizeContent(htmlContent);

        expect(sanitized, equals('Line 1 Line 2 Line 3'));
        expect(sanitized, isNot(contains('\n')));
      });

      test('should handle empty content', () {
        final sanitized = processor.sanitizeContent('');
        expect(sanitized, equals(''));
      });

      test('should handle content with only whitespace', () {
        const htmlContent = '   \n\t   \n   ';
        final sanitized = processor.sanitizeContent(htmlContent);
        expect(sanitized, equals(''));
      });

      test('should handle malformed HTML gracefully', () {
        const htmlContent = '<p>Unclosed paragraph<div>Nested <span>content</div>';
        final sanitized = processor.sanitizeContent(htmlContent);
        expect(sanitized, equals('Unclosed paragraph Nested content'));
      });
    });

    group('replaceLinksWithContent', () {
      test('should replace links with content markers', () {
        const text = '''
        Check out this page: https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page
        And this documentation: https://example.atlassian.net/wiki/spaces/DOCS/pages/789012/Another+Page
        ''';

        final linkContentMap = {
          'https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page': '@conf-cnt Test page content@',
          'https://example.atlassian.net/wiki/spaces/DOCS/pages/789012/Another+Page': '@conf-cnt Documentation content@',
        };

        final result = processor.replaceLinksWithContent(text, linkContentMap);

        expect(result, contains('@conf-cnt Test page content@'));
        expect(result, contains('@conf-cnt Documentation content@'));
        expect(result, isNot(contains('https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page')));
        expect(result, isNot(contains('https://example.atlassian.net/wiki/spaces/DOCS/pages/789012/Another+Page')));
      });

      test('should handle overlapping URLs correctly by processing longest first', () {
        const text = '''
        Short URL: https://example.atlassian.net/wiki/spaces/DEV/pages/123
        Long URL: https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page
        ''';

        final linkContentMap = {
          'https://example.atlassian.net/wiki/spaces/DEV/pages/123': '@conf-cnt Short content@',
          'https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page': '@conf-cnt Long content@',
        };

        final result = processor.replaceLinksWithContent(text, linkContentMap);

        expect(result, contains('@conf-cnt Short content@'));
        expect(result, contains('@conf-cnt Long content@'));
      });

      test('should handle empty link content map', () {
        const text = 'Some text with https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page';
        final result = processor.replaceLinksWithContent(text, {});
        expect(result, equals(text));
      });

      test('should handle text without links', () {
        const text = 'Just some regular text without any links.';
        final linkContentMap = {
          'https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page': '@conf-cnt Content@',
        };
        final result = processor.replaceLinksWithContent(text, linkContentMap);
        expect(result, equals(text));
      });
    });

    group('processText', () {
      test('should process text with Confluence links successfully', () async {
        const text = '''
        Check out this page: https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page
        ''';

        mockConfluenceService.setMockResponse('123456', '<p>Test page content</p>');

        final result = await processor.processText(text, testConfig, debounce: false);

        expect(result, contains('@conf-cnt Test page content@'));
        expect(result, isNot(contains('https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page')));
      });

      test('should handle API errors gracefully', () async {
        const text = '''
        Check out this page: https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page
        ''';

        mockConfluenceService.setMockError('123456', Exception('Page not found'));

        final result = await processor.processText(text, testConfig, debounce: false);

        // Should keep original URL when processing fails
        expect(result, contains('https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page'));
        expect(result, isNot(contains('@conf-cnt')));
      });

      test('should return original text when configuration is incomplete', () async {
        const text = '''
        Check out this page: https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page
        ''';

        final incompleteConfig = const ConfluenceConfig(
          enabled: false,
          baseUrl: '',
          token: '',
          isValid: false,
        );

        final result = await processor.processText(text, incompleteConfig, debounce: false);

        expect(result, equals(text));
      });

      test('should return original text when no Confluence links found', () async {
        const text = '''
        This is just regular text with some URLs:
        https://google.com
        https://github.com/user/repo
        ''';

        final result = await processor.processText(text, testConfig, debounce: false);

        expect(result, equals(text));
      });

      test('should handle empty text', () async {
        final result = await processor.processText('', testConfig, debounce: false);
        expect(result, equals(''));
      });

      test('should cache processed links', () async {
        const text = '''
        Same link twice: https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page
        And again: https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page
        ''';

        mockConfluenceService.setMockResponse('123456', '<p>Test page content</p>');

        await processor.processText(text, testConfig, debounce: false);

        // Process again - should use cache
        final result = await processor.processText(text, testConfig, debounce: false);

        // Should contain processed content
        expect(result, contains('@conf-cnt Test page content@'));
      });

      test('should handle multiple different links', () async {
        const text = '''
        First page: https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page
        Second page: https://example.atlassian.net/wiki/spaces/DOCS/pages/789012/Another+Page
        ''';

        mockConfluenceService.setMockResponse('123456', '<p>First page content</p>');
        mockConfluenceService.setMockResponse('789012', '<p>Second page content</p>');

        final result = await processor.processText(text, testConfig, debounce: false);

        expect(result, contains('@conf-cnt First page content@'));
        expect(result, contains('@conf-cnt Second page content@'));
      });
    });

    group('debounce functionality', () {
      test('should apply debounce when enabled', () async {
        const text = '''
        Check out this page: https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page
        ''';

        mockConfluenceService.setMockResponse('123456', '<p>Test page content</p>');

        // Start processing with debounce
        final future = processor.processText(text, testConfig, debounce: true);

        // Wait for debounce to complete
        final result = await future;

        expect(result, contains('@conf-cnt Test page content@'));
      });

      test('should cancel previous debounce when new request comes in', () async {
        const text1 = '''
        First page: https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page
        ''';
        const text2 = '''
        Second page: https://example.atlassian.net/wiki/spaces/DOCS/pages/789012/Another+Page
        ''';

        mockConfluenceService.setMockResponse('123456', '<p>First page content</p>');
        mockConfluenceService.setMockResponse('789012', '<p>Second page content</p>');

        // Start first request
        processor.processText(text1, testConfig, debounce: true);
        
        // Start second request immediately (should cancel first)
        final result2 = await processor.processText(text2, testConfig, debounce: true);

        // The second request should complete successfully
        expect(result2, contains('@conf-cnt Second page content@'));
      });
    });

    group('cache management', () {
      test('should provide cache statistics', () {
        // Initially empty
        var stats = processor.getCacheStats();
        expect(stats['totalCached'], equals(0));
        expect(stats['validLinks'], equals(0));
        expect(stats['invalidLinks'], equals(0));
        expect(stats['freshLinks'], equals(0));
        expect(stats['staleLinks'], equals(0));
      });

      test('should clear cache', () async {
        const text = '''
        Check out this page: https://example.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page
        ''';

        mockConfluenceService.setMockResponse('123456', '<p>Test page content</p>');

        await processor.processText(text, testConfig, debounce: false);

        var stats = processor.getCacheStats();
        expect(stats['totalCached'], equals(1));

        processor.clearCache();

        stats = processor.getCacheStats();
        expect(stats['totalCached'], equals(0));
      });

      test('should cancel debounce timer', () {
        processor.cancelDebounce();
        // Should not throw any errors
      });
    });

    group('edge cases', () {
      test('should handle invalid page IDs in URLs', () async {
        const text = '''
        Invalid URL: https://example.atlassian.net/wiki/spaces/DEV/pages/invalid/Test+Page
        ''';

        final result = await processor.processText(text, testConfig, debounce: false);

        // Should keep original URL since page ID extraction fails
        expect(result, equals(text));
      });

      test('should handle URLs from different domains', () async {
        const text = '''
        Different domain: https://other.atlassian.net/wiki/spaces/DEV/pages/123456/Test+Page
        ''';

        final result = await processor.processText(text, testConfig, debounce: false);

        // Should keep original URL since domain doesn't match
        expect(result, equals(text));
      });

      test('should handle very long content', () {
        final longContent = 'A' * 10000;
        final htmlContent = '<p>$longContent</p>';
        
        final sanitized = processor.sanitizeContent(htmlContent);
        
        expect(sanitized, equals(longContent));
        expect(sanitized.length, equals(10000));
      });

      test('should handle content with special characters', () {
        const htmlContent = '''
        <p>Content with émojis 🚀 and spëcial chàracters ñ</p>
        <p>Unicode: ∑ ∆ ∏ ∫ ∂</p>
        ''';

        final sanitized = processor.sanitizeContent(htmlContent);

        expect(sanitized, contains('émojis 🚀'));
        expect(sanitized, contains('spëcial chàracters ñ'));
        expect(sanitized, contains('∑ ∆ ∏ ∫ ∂'));
      });
    });
  });
}