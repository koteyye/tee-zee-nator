import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../lib/services/confluence_performance_optimizer.dart';
import '../lib/services/confluence_debouncer.dart';
import '../lib/services/confluence_content_processor.dart';
import '../lib/services/confluence_service.dart';
import '../lib/models/confluence_config.dart';

@GenerateMocks([ConfluenceService, ConfluenceContentProcessor])
import 'confluence_performance_test.mocks.dart';

void main() {
  group('ConfluencePerformanceOptimizer', () {
    late MockConfluenceService mockConfluenceService;
    late MockConfluenceContentProcessor mockContentProcessor;
    late ConfluencePerformanceOptimizer optimizer;
    late ConfluenceConfig testConfig;

    setUp(() {
      mockConfluenceService = MockConfluenceService();
      mockContentProcessor = MockConfluenceContentProcessor();
      optimizer = ConfluencePerformanceOptimizer(
        mockConfluenceService,
        mockContentProcessor,
        maxCacheSize: 10,
        maxMemoryMB: 1,
      );
      
      testConfig = ConfluenceConfig(
        enabled: true,
        baseUrl: 'https://test.atlassian.net',
        token: 'test-token',
        isValid: true,
      );
    });

    tearDown(() {
      optimizer.dispose();
    });

    group('Intelligent Caching', () {
      test('should cache processed content', () async {
        // Arrange
        const testText = 'Check this link: https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';
        const expectedContent = '@conf-cnt Test content@';
        
        when(mockContentProcessor.extractLinks(any, any))
            .thenReturn(['https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page']);
        when(mockContentProcessor.replaceLinksWithContent(any, any))
            .thenReturn(expectedContent);
        when(mockConfluenceService.getPageContent('123'))
            .thenAnswer((_) async => 'Test content');
        when(mockContentProcessor.sanitizeContent(any))
            .thenReturn('Test content');

        // Act - First call should hit the service
        final result1 = await optimizer.processTextOptimized(testText, testConfig);
        
        // Act - Second call should use cache
        final result2 = await optimizer.processTextOptimized(testText, testConfig);

        // Assert
        expect(result1, equals(expectedContent));
        expect(result2, equals(expectedContent));
        
        // Verify service was called only once (cached on second call)
        verify(mockConfluenceService.getPageContent('123')).called(1);
        
        final metrics = optimizer.getPerformanceMetrics();
        expect(metrics['cacheHits'], equals(1));
        expect(metrics['cacheMisses'], equals(1));
      });

      test('should evict least recently used entries when cache is full', () async {
        // Arrange - Create optimizer with small cache size
        final smallOptimizer = ConfluencePerformanceOptimizer(
          mockConfluenceService,
          mockContentProcessor,
          maxCacheSize: 2,
          maxMemoryMB: 1,
        );

        when(mockContentProcessor.extractLinks(any, any))
            .thenAnswer((invocation) {
          final text = invocation.positionalArguments[0] as String;
          if (text.contains('page1')) return ['https://test.atlassian.net/wiki/spaces/TEST/pages/1/Page1'];
          if (text.contains('page2')) return ['https://test.atlassian.net/wiki/spaces/TEST/pages/2/Page2'];
          if (text.contains('page3')) return ['https://test.atlassian.net/wiki/spaces/TEST/pages/3/Page3'];
          return [];
        });
        
        when(mockContentProcessor.replaceLinksWithContent(any, any))
            .thenAnswer((invocation) => invocation.positionalArguments[0] as String);
        
        when(mockConfluenceService.getPageContent(any))
            .thenAnswer((invocation) async => 'Content for ${invocation.positionalArguments[0]}');
        
        when(mockContentProcessor.sanitizeContent(any))
            .thenAnswer((invocation) => invocation.positionalArguments[0] as String);

        // Act - Fill cache beyond capacity
        await smallOptimizer.processTextOptimized('Text with page1', testConfig);
        await smallOptimizer.processTextOptimized('Text with page2', testConfig);
        await smallOptimizer.processTextOptimized('Text with page3', testConfig); // Should evict page1

        // Access page2 to make it recently used
        await smallOptimizer.processTextOptimized('Text with page2', testConfig);

        // Assert - Cache should contain page2 and page3, but not page1
        final stats = smallOptimizer.getCacheStatistics();
        expect(stats['totalEntries'], equals(2));

        smallOptimizer.dispose();
      });

      test('should respect TTL for cached entries', () async {
        // Arrange
        final shortTtlOptimizer = ConfluencePerformanceOptimizer(
          mockConfluenceService,
          mockContentProcessor,
          cacheTtl: const Duration(milliseconds: 10),
        );

        const testText = 'Check this link: https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';
        
        when(mockContentProcessor.extractLinks(any, any))
            .thenReturn(['https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page']);
        when(mockContentProcessor.replaceLinksWithContent(any, any))
            .thenReturn(testText);
        when(mockConfluenceService.getPageContent('123'))
            .thenAnswer((_) async => 'Test content');
        when(mockContentProcessor.sanitizeContent(any))
            .thenReturn('Test content');

        // Act - First call
        await shortTtlOptimizer.processTextOptimized(testText, testConfig);
        
        // Wait for TTL to expire
        await Future.delayed(const Duration(milliseconds: 20));
        
        // Second call should not use cache
        await shortTtlOptimizer.processTextOptimized(testText, testConfig);

        // Assert - Service should be called twice (cache expired)
        verify(mockConfluenceService.getPageContent('123')).called(2);

        shortTtlOptimizer.dispose();
      });
    });

    group('Batch Processing', () {
      test('should process multiple links in batches', () async {
        // Arrange
        const testText = '''
        Check these links:
        https://test.atlassian.net/wiki/spaces/TEST/pages/1/Page1
        https://test.atlassian.net/wiki/spaces/TEST/pages/2/Page2
        https://test.atlassian.net/wiki/spaces/TEST/pages/3/Page3
        ''';
        
        when(mockContentProcessor.extractLinks(any, any))
            .thenReturn([
          'https://test.atlassian.net/wiki/spaces/TEST/pages/1/Page1',
          'https://test.atlassian.net/wiki/spaces/TEST/pages/2/Page2',
          'https://test.atlassian.net/wiki/spaces/TEST/pages/3/Page3',
        ]);
        
        when(mockContentProcessor.replaceLinksWithContent(any, any))
            .thenReturn('Processed text with content');
        
        when(mockConfluenceService.getPageContent(any))
            .thenAnswer((invocation) async => 'Content for ${invocation.positionalArguments[0]}');
        
        when(mockContentProcessor.sanitizeContent(any))
            .thenAnswer((invocation) => invocation.positionalArguments[0] as String);

        // Act
        final result = await optimizer.processTextOptimized(
          testText, 
          testConfig,
          enableBatching: true,
        );

        // Assert
        expect(result, equals('Processed text with content'));
        
        // All pages should be processed
        verify(mockConfluenceService.getPageContent('1')).called(1);
        verify(mockConfluenceService.getPageContent('2')).called(1);
        verify(mockConfluenceService.getPageContent('3')).called(1);
      });

      test('should handle batch processing errors gracefully', () async {
        // Arrange
        const testText = '''
        https://test.atlassian.net/wiki/spaces/TEST/pages/1/Page1
        https://test.atlassian.net/wiki/spaces/TEST/pages/2/Page2
        ''';
        
        when(mockContentProcessor.extractLinks(any, any))
            .thenReturn([
          'https://test.atlassian.net/wiki/spaces/TEST/pages/1/Page1',
          'https://test.atlassian.net/wiki/spaces/TEST/pages/2/Page2',
        ]);
        
        when(mockContentProcessor.replaceLinksWithContent(any, any))
            .thenReturn('Processed text');
        
        // First page succeeds, second fails
        when(mockConfluenceService.getPageContent('1'))
            .thenAnswer((_) async => 'Content 1');
        when(mockConfluenceService.getPageContent('2'))
            .thenThrow(Exception('Network error'));
        
        when(mockContentProcessor.sanitizeContent(any))
            .thenAnswer((invocation) => invocation.positionalArguments[0] as String);

        // Act & Assert - Should not throw
        final result = await optimizer.processTextOptimized(testText, testConfig);
        expect(result, equals('Processed text'));
        
        final metrics = optimizer.getPerformanceMetrics();
        expect(metrics['errors'], equals(1));
      });
    });

    group('Request Deduplication', () {
      test('should deduplicate concurrent requests for same link', () async {
        // Arrange
        const testText = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';
        
        when(mockContentProcessor.extractLinks(any, any))
            .thenReturn(['https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page']);
        when(mockContentProcessor.replaceLinksWithContent(any, any))
            .thenReturn('Processed');
        when(mockConfluenceService.getPageContent('123'))
            .thenAnswer((_) async {
          // Simulate slow response
          await Future.delayed(const Duration(milliseconds: 100));
          return 'Test content';
        });
        when(mockContentProcessor.sanitizeContent(any))
            .thenReturn('Test content');

        // Act - Make concurrent requests
        final futures = List.generate(3, (_) => 
            optimizer.processTextOptimized(testText, testConfig));
        
        final results = await Future.wait(futures);

        // Assert - All should succeed with same result
        expect(results, everyElement(equals('Processed')));
        
        // Service should be called only once due to deduplication
        verify(mockConfluenceService.getPageContent('123')).called(1);
        
        final metrics = optimizer.getPerformanceMetrics();
        expect(metrics['deduplications'], equals(2));
      });
    });

    group('Memory Management', () {
      test('should track memory usage accurately', () async {
        // Arrange
        const testText = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';
        final largeContent = 'A' * 1000; // 1KB content
        
        when(mockContentProcessor.extractLinks(any, any))
            .thenReturn(['https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page']);
        when(mockContentProcessor.replaceLinksWithContent(any, any))
            .thenReturn('Processed');
        when(mockConfluenceService.getPageContent('123'))
            .thenAnswer((_) async => largeContent);
        when(mockContentProcessor.sanitizeContent(any))
            .thenReturn(largeContent);

        // Act
        await optimizer.processTextOptimized(testText, testConfig);

        // Assert
        final metrics = optimizer.getPerformanceMetrics();
        expect(int.parse(metrics['memoryUsageBytes'].toString()), greaterThan(0));
        expect(double.parse(metrics['memoryUsageMB'].toString()), greaterThan(0.0));
      });

      test('should not cache content that exceeds size limits', () async {
        // Arrange
        const testText = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';
        final veryLargeContent = 'A' * (1024 * 1024); // 1MB content
        
        when(mockContentProcessor.extractLinks(any, any))
            .thenReturn(['https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page']);
        when(mockContentProcessor.replaceLinksWithContent(any, any))
            .thenReturn('Processed');
        when(mockConfluenceService.getPageContent('123'))
            .thenAnswer((_) async => veryLargeContent);
        when(mockContentProcessor.sanitizeContent(any))
            .thenReturn(veryLargeContent);

        // Act
        await optimizer.processTextOptimized(testText, testConfig);
        
        // Make second request - should call service again (not cached)
        await optimizer.processTextOptimized(testText, testConfig);

        // Assert - Service called twice (large content not cached)
        verify(mockConfluenceService.getPageContent('123')).called(2);
      });
    });

    group('Performance Metrics', () {
      test('should track comprehensive performance metrics', () async {
        // Arrange
        const testText = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';
        
        when(mockContentProcessor.extractLinks(any, any))
            .thenReturn(['https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page']);
        when(mockContentProcessor.replaceLinksWithContent(any, any))
            .thenReturn('Processed');
        when(mockConfluenceService.getPageContent('123'))
            .thenAnswer((_) async => 'Content');
        when(mockContentProcessor.sanitizeContent(any))
            .thenReturn('Content');

        // Act
        await optimizer.processTextOptimized(testText, testConfig);
        await optimizer.processTextOptimized(testText, testConfig); // Cache hit

        // Assert
        final metrics = optimizer.getPerformanceMetrics();
        
        expect(metrics['totalRequests'], equals(2));
        expect(metrics['cacheHits'], equals(1));
        expect(metrics['cacheMisses'], equals(1));
        expect(metrics['cacheHitRate'], equals('50.0'));
        expect(metrics.containsKey('averageProcessingTimeMs'), isTrue);
        expect(metrics.containsKey('memoryUsageBytes'), isTrue);
      });
    });

    group('Configuration Updates', () {
      test('should update configuration and enforce new limits', () {
        // Arrange
        final initialMetrics = optimizer.getPerformanceMetrics();
        final initialMaxCache = initialMetrics['maxCacheSize'];
        final initialMaxMemory = initialMetrics['maxMemoryMB'];

        // Act
        optimizer.updateConfiguration(
          maxCacheSize: 50,
          maxMemoryMB: 10,
          cacheTtl: const Duration(minutes: 60),
        );

        // Assert
        final updatedMetrics = optimizer.getPerformanceMetrics();
        expect(updatedMetrics['maxCacheSize'], equals(50));
        expect(updatedMetrics['maxMemoryMB'], equals(10));
        expect(updatedMetrics['cacheTtlMinutes'], equals(60));
        
        // Verify limits changed
        expect(updatedMetrics['maxCacheSize'], isNot(equals(initialMaxCache)));
        expect(updatedMetrics['maxMemoryMB'], isNot(equals(initialMaxMemory)));
      });
    });
  });

  group('ConfluenceDebouncer', () {
    late ConfluenceDebouncer debouncer;

    setUp(() {
      debouncer = ConfluenceDebouncer();
    });

    tearDown(() {
      debouncer.dispose();
    });

    group('Basic Debouncing', () {
      test('should debounce function calls', () async {
        // Arrange
        int callCount = 0;
        Future<void> testCallback() async {
          callCount++;
        }

        // Act - Multiple rapid calls
        debouncer.debounce('test', testCallback);
        debouncer.debounce('test', testCallback);
        debouncer.debounce('test', testCallback);

        // Wait for debounce to complete
        await Future.delayed(const Duration(milliseconds: 600));

        // Assert - Should be called only once
        expect(callCount, equals(1));
      });

      test('should handle multiple debounced operations independently', () async {
        // Arrange
        int callCount1 = 0;
        int callCount2 = 0;
        
        Future<void> callback1() async { callCount1++; }
        Future<void> callback2() async { callCount2++; }

        // Act
        debouncer.debounce('test1', callback1);
        debouncer.debounce('test2', callback2);

        await Future.delayed(const Duration(milliseconds: 600));

        // Assert
        expect(callCount1, equals(1));
        expect(callCount2, equals(1));
      });
    });

    group('Adaptive Debouncing', () {
      test('should use shorter delay for short text', () {
        // Arrange
        const shortText = 'Short text';
        bool callbackExecuted = false;
        
        Future<void> testCallback() async {
          callbackExecuted = true;
        }

        // Act
        debouncer.adaptiveDebounce('test', shortText, testCallback);

        // Assert - Should be pending
        expect(debouncer.isPending('test'), isTrue);
      });

      test('should use longer delay for long text with many links', () {
        // Arrange
        final longTextWithLinks = '''
        This is a very long text with multiple Confluence links:
        https://test.atlassian.net/wiki/spaces/TEST/pages/1/Page1
        https://test.atlassian.net/wiki/spaces/TEST/pages/2/Page2
        https://test.atlassian.net/wiki/spaces/TEST/pages/3/Page3
        https://test.atlassian.net/wiki/spaces/TEST/pages/4/Page4
        And more content to make it longer...
        ''' * 10; // Make it very long
        
        bool callbackExecuted = false;
        Future<void> testCallback() async {
          callbackExecuted = true;
        }

        // Act
        debouncer.adaptiveDebounce('test', longTextWithLinks, testCallback);

        // Assert - Should be pending with longer delay
        expect(debouncer.isPending('test'), isTrue);
      });
    });

    group('Priority Debouncing', () {
      test('should use different delays for different priorities', () {
        // Arrange
        bool highPriorityExecuted = false;
        bool lowPriorityExecuted = false;
        
        Future<void> highCallback() async { highPriorityExecuted = true; }
        Future<void> lowCallback() async { lowPriorityExecuted = true; }

        // Act
        debouncer.priorityDebounce('high', highCallback, DebouncePriority.high);
        debouncer.priorityDebounce('low', lowCallback, DebouncePriority.low);

        // Assert - Both should be pending
        expect(debouncer.isPending('high'), isTrue);
        expect(debouncer.isPending('low'), isTrue);
      });
    });

    group('Cancellation', () {
      test('should cancel specific debounced operation', () async {
        // Arrange
        bool callbackExecuted = false;
        Future<void> testCallback() async {
          callbackExecuted = true;
        }

        // Act
        debouncer.debounce('test', testCallback);
        expect(debouncer.isPending('test'), isTrue);
        
        debouncer.cancel('test');
        
        await Future.delayed(const Duration(milliseconds: 600));

        // Assert
        expect(callbackExecuted, isFalse);
        expect(debouncer.isPending('test'), isFalse);
      });

      test('should cancel all debounced operations', () async {
        // Arrange
        bool callback1Executed = false;
        bool callback2Executed = false;
        
        Future<void> callback1() async { callback1Executed = true; }
        Future<void> callback2() async { callback2Executed = true; }

        // Act
        debouncer.debounce('test1', callback1);
        debouncer.debounce('test2', callback2);
        
        expect(debouncer.isPending('test1'), isTrue);
        expect(debouncer.isPending('test2'), isTrue);
        
        debouncer.cancelAll();
        
        await Future.delayed(const Duration(milliseconds: 600));

        // Assert
        expect(callback1Executed, isFalse);
        expect(callback2Executed, isFalse);
        expect(debouncer.isPending('test1'), isFalse);
        expect(debouncer.isPending('test2'), isFalse);
      });
    });

    group('Metrics', () {
      test('should track debouncing metrics', () async {
        // Arrange
        int callCount = 0;
        Future<void> testCallback() async {
          callCount++;
        }

        // Act
        debouncer.debounce('test', testCallback);
        debouncer.debounce('test', testCallback); // Should cancel previous
        
        await Future.delayed(const Duration(milliseconds: 600));

        // Assert
        final metrics = debouncer.getMetrics('test');
        expect(metrics['attempts'], equals(2));
        expect(metrics['successes'], equals(1));
        expect(metrics['cancellations'], equals(1));
      });

      test('should provide overall metrics', () async {
        // Arrange
        Future<void> callback1() async {}
        Future<void> callback2() async {}

        // Act
        debouncer.debounce('test1', callback1);
        debouncer.debounce('test2', callback2);
        
        await Future.delayed(const Duration(milliseconds: 600));

        // Assert
        final overallMetrics = debouncer.getOverallMetrics();
        expect(overallMetrics['totalOperations'], equals(2));
        expect(overallMetrics['totalAttempts'], equals(2));
        expect(overallMetrics['totalSuccesses'], equals(2));
      });
    });

    group('Error Handling', () {
      test('should handle callback errors gracefully', () async {
        // Arrange
        Future<void> errorCallback() async {
          throw Exception('Test error');
        }

        // Act & Assert - Should not throw
        debouncer.debounce('test', errorCallback);
        
        await Future.delayed(const Duration(milliseconds: 600));
        
        final metrics = debouncer.getMetrics('test');
        expect(metrics['errors'], equals(1));
      });
    });
  });

  group('Performance Benchmarks', () {
    test('should process single link within performance threshold', () async {
      // Arrange
      final mockService = MockConfluenceService();
      final mockProcessor = MockConfluenceContentProcessor();
      final optimizer = ConfluencePerformanceOptimizer(mockService, mockProcessor);
      
      const testText = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';
      final config = ConfluenceConfig(
        enabled: true,
        baseUrl: 'https://test.atlassian.net',
        token: 'test-token',
        isValid: true,
      );
      
      when(mockProcessor.extractLinks(any, any))
          .thenReturn(['https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page']);
      when(mockProcessor.replaceLinksWithContent(any, any))
          .thenReturn('Processed');
      when(mockService.getPageContent('123'))
          .thenAnswer((_) async => 'Content');
      when(mockProcessor.sanitizeContent(any))
          .thenReturn('Content');

      // Act
      final stopwatch = Stopwatch()..start();
      await optimizer.processTextOptimized(testText, config);
      stopwatch.stop();

      // Assert - Should complete within reasonable time (adjust threshold as needed)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      
      optimizer.dispose();
    });

    test('should handle batch processing efficiently', () async {
      // Arrange
      final mockService = MockConfluenceService();
      final mockProcessor = MockConfluenceContentProcessor();
      final optimizer = ConfluencePerformanceOptimizer(mockService, mockProcessor);
      
      final testText = List.generate(10, (i) => 
          'https://test.atlassian.net/wiki/spaces/TEST/pages/$i/Page$i').join('\n');
      
      final config = ConfluenceConfig(
        enabled: true,
        baseUrl: 'https://test.atlassian.net',
        token: 'test-token',
        isValid: true,
      );
      
      when(mockProcessor.extractLinks(any, any))
          .thenReturn(List.generate(10, (i) => 
              'https://test.atlassian.net/wiki/spaces/TEST/pages/$i/Page$i'));
      when(mockProcessor.replaceLinksWithContent(any, any))
          .thenReturn('Processed batch');
      when(mockService.getPageContent(any))
          .thenAnswer((invocation) async => 'Content ${invocation.positionalArguments[0]}');
      when(mockProcessor.sanitizeContent(any))
          .thenAnswer((invocation) => invocation.positionalArguments[0] as String);

      // Act
      final stopwatch = Stopwatch()..start();
      await optimizer.processTextOptimized(testText, config, enableBatching: true);
      stopwatch.stop();

      // Assert - Batch processing should be reasonably fast
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      
      final metrics = optimizer.getPerformanceMetrics();
      expect(int.parse(metrics['totalRequests'].toString()), equals(1));
      
      optimizer.dispose();
    });
  });
}