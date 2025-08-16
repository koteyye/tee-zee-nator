import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import '../lib/services/confluence_content_processor.dart';
import '../lib/services/confluence_service.dart';
import '../lib/services/confluence_debouncer.dart';
import '../lib/models/confluence_config.dart';

@GenerateMocks([ConfluenceService])
import 'confluence_performance_integration_test.mocks.dart';

/// Integration tests for Confluence performance optimizations
/// 
/// These tests verify that the performance optimizations work correctly
/// with the existing Confluence integration infrastructure.
void main() {
  group('Confluence Performance Integration', () {
    late MockConfluenceService mockService;
    late ConfluenceContentProcessor processor;
    late ConfluenceConfig testConfig;

    setUp(() {
      mockService = MockConfluenceService();
      processor = ConfluenceContentProcessor(mockService);
      testConfig = ConfluenceConfig(
        enabled: true,
        baseUrl: 'https://test.atlassian.net',
        token: 'test-token',
        isValid: true,
      );
    });

    tearDown(() {
      processor.dispose();
    });

    group('Enhanced Content Processing', () {
      test('should process text with performance optimizations enabled', () async {
        // Arrange
        const testText = 'Check this link: https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';
        
        when(mockService.getPageContent('123'))
            .thenAnswer((_) async => 'Test content from Confluence');

        // Act - Process with optimizations enabled
        final result = await processor.processText(
          testText,
          testConfig,
          debounce: false,
          enableOptimizations: true,
        );

        // Assert
        expect(result, contains('@conf-cnt'));
        expect(result, contains('Test content from Confluence'));
        verify(mockService.getPageContent('123')).called(1);
      });

      test('should cache processed content for repeated requests', () async {
        // Arrange
        const testText = 'Check this link: https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';
        
        when(mockService.getPageContent('123'))
            .thenAnswer((_) async => 'Test content from Confluence');

        // Act - Process same text multiple times
        await processor.processText(testText, testConfig, debounce: false, enableOptimizations: true);
        await processor.processText(testText, testConfig, debounce: false, enableOptimizations: true);
        await processor.processText(testText, testConfig, debounce: false, enableOptimizations: true);

        // Assert - Service should be called only once due to caching
        verify(mockService.getPageContent('123')).called(1);
      });

      test('should handle multiple links efficiently', () async {
        // Arrange
        const testText = '''
        Check these links:
        https://test.atlassian.net/wiki/spaces/TEST/pages/1/Page1
        https://test.atlassian.net/wiki/spaces/TEST/pages/2/Page2
        https://test.atlassian.net/wiki/spaces/TEST/pages/3/Page3
        ''';
        
        when(mockService.getPageContent('1'))
            .thenAnswer((_) async => 'Content 1');
        when(mockService.getPageContent('2'))
            .thenAnswer((_) async => 'Content 2');
        when(mockService.getPageContent('3'))
            .thenAnswer((_) async => 'Content 3');

        // Act
        final stopwatch = Stopwatch()..start();
        final result = await processor.processText(
          testText,
          testConfig,
          debounce: false,
          enableOptimizations: true,
        );
        stopwatch.stop();

        // Assert
        expect(result, contains('@conf-cnt'));
        expect(result, contains('Content 1'));
        expect(result, contains('Content 2'));
        expect(result, contains('Content 3'));
        
        // Should complete in reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
        
        // All pages should be processed
        verify(mockService.getPageContent('1')).called(1);
        verify(mockService.getPageContent('2')).called(1);
        verify(mockService.getPageContent('3')).called(1);
      });

      test('should provide cache statistics', () async {
        // Arrange
        const testText = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';
        
        when(mockService.getPageContent('123'))
            .thenAnswer((_) async => 'Test content');

        // Act
        await processor.processText(testText, testConfig, debounce: false, enableOptimizations: true);
        
        // Assert
        final stats = processor.getCacheStats();
        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('performanceOptimizer'), isTrue);
        expect(stats.containsKey('debouncer'), isTrue);
        
        final optimizerStats = stats['performanceOptimizer'] as Map<String, dynamic>;
        expect(optimizerStats['totalRequests'], equals(1));
        expect(optimizerStats.containsKey('cacheSize'), isTrue);
        expect(optimizerStats.containsKey('memoryUsageBytes'), isTrue);
      });
    });

    group('Debouncing Performance', () {
      test('should handle rapid text changes efficiently', () async {
        // Arrange
        const baseText = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';
        int apiCallCount = 0;
        
        when(mockService.getPageContent('123')).thenAnswer((_) async {
          apiCallCount++;
          await Future.delayed(const Duration(milliseconds: 10));
          return 'Test content';
        });

        // Act - Simulate rapid text changes
        final futures = <Future<String>>[];
        for (int i = 0; i < 5; i++) {
          final text = '$baseText?v=$i'; // Slightly different each time
          futures.add(processor.processText(text, testConfig, debounce: true));
          await Future.delayed(const Duration(milliseconds: 50));
        }

        await Future.wait(futures);

        // Assert - Should make fewer API calls due to debouncing
        expect(apiCallCount, lessThan(5));
        expect(apiCallCount, greaterThan(0));
      });
    });

    group('Memory Management', () {
      test('should clear cache when requested', () async {
        // Arrange
        const testText = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';
        
        when(mockService.getPageContent('123'))
            .thenAnswer((_) async => 'Test content');

        // Act - Process and cache content
        await processor.processText(testText, testConfig, debounce: false, enableOptimizations: true);
        
        // Verify content is cached
        final statsBefore = processor.getCacheStats();
        final optimizerStatsBefore = statsBefore['performanceOptimizer'] as Map<String, dynamic>;
        expect(int.parse(optimizerStatsBefore['cacheSize'].toString()), greaterThan(0));
        
        // Clear cache
        processor.clearCache();
        
        // Assert - Cache should be empty
        final statsAfter = processor.getCacheStats();
        final optimizerStatsAfter = statsAfter['performanceOptimizer'] as Map<String, dynamic>;
        expect(int.parse(optimizerStatsAfter['cacheSize'].toString()), equals(0));
      });

      test('should clear all data when requested', () async {
        // Arrange
        const testText = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';
        
        when(mockService.getPageContent('123'))
            .thenAnswer((_) async => 'Test content');

        // Act - Process content
        await processor.processText(testText, testConfig, debounce: false, enableOptimizations: true);
        
        // Clear all data
        processor.clearAllData();
        
        // Assert - All caches should be empty
        final stats = processor.getCacheStats();
        final legacyStats = stats['legacy'] as Map<String, dynamic>;
        final optimizerStats = stats['performanceOptimizer'] as Map<String, dynamic>;
        
        expect(legacyStats['totalCached'], equals(0));
        expect(legacyStats['sessionContentCount'], equals(0));
        expect(int.parse(optimizerStats['cacheSize'].toString()), equals(0));
      });
    });

    group('Error Handling', () {
      test('should handle API errors gracefully with optimizations', () async {
        // Arrange
        const testText = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';
        
        when(mockService.getPageContent('123'))
            .thenThrow(Exception('Network error'));

        // Act & Assert - Should not throw
        final result = await processor.processText(
          testText,
          testConfig,
          debounce: false,
          enableOptimizations: true,
        );
        
        // Should return original text on error
        expect(result, equals(testText));
      });

      test('should track errors in performance metrics', () async {
        // Arrange
        const testText = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';
        
        when(mockService.getPageContent('123'))
            .thenThrow(Exception('Network error'));

        // Act
        await processor.processText(testText, testConfig, debounce: false, enableOptimizations: true);
        
        // Assert
        final stats = processor.getCacheStats();
        final optimizerStats = stats['performanceOptimizer'] as Map<String, dynamic>;
        expect(int.parse(optimizerStats['errors'].toString()), greaterThan(0));
      });
    });

    group('Fallback Behavior', () {
      test('should fallback to original implementation when optimizations disabled', () async {
        // Arrange
        const testText = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';
        
        when(mockService.getPageContent('123'))
            .thenAnswer((_) async => 'Test content');

        // Act - Process with optimizations disabled
        final result = await processor.processText(
          testText,
          testConfig,
          debounce: false,
          enableOptimizations: false,
        );

        // Assert - Should still work
        expect(result, contains('@conf-cnt'));
        expect(result, contains('Test content'));
        verify(mockService.getPageContent('123')).called(1);
      });
    });
  });

  group('ConfluenceDebouncer Standalone', () {
    late ConfluenceDebouncer debouncer;

    setUp(() {
      debouncer = ConfluenceDebouncer();
    });

    tearDown(() {
      debouncer.dispose();
    });

    test('should debounce function calls effectively', () async {
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

    test('should adapt debounce delay based on text complexity', () {
      // Arrange
      const shortText = 'Short';
      final longComplexText = List.filled(5, '''
      This is a very long text with multiple Confluence links:
      https://test.atlassian.net/wiki/spaces/TEST/pages/1/Page1
      https://test.atlassian.net/wiki/spaces/TEST/pages/2/Page2
      https://test.atlassian.net/wiki/spaces/TEST/pages/3/Page3
      And much more complex content with special characters: !@#\$%^&*()
      ''').join();
      
      bool shortTextProcessed = false;
      bool longTextProcessed = false;
      
      Future<void> shortCallback() async { shortTextProcessed = true; }
      Future<void> longCallback() async { longTextProcessed = true; }

      // Act
      debouncer.adaptiveDebounce('short', shortText, shortCallback);
      debouncer.adaptiveDebounce('long', longComplexText, longCallback);

      // Assert - Both should be pending but with different delays
      expect(debouncer.isPending('short'), isTrue);
      expect(debouncer.isPending('long'), isTrue);
    });

    test('should provide comprehensive metrics', () async {
      // Arrange
      int callCount = 0;
      Future<void> testCallback() async {
        callCount++;
      }

      // Act
      debouncer.debounce('test1', testCallback);
      debouncer.debounce('test2', testCallback);
      debouncer.cancel('test2'); // Cancel one
      
      await Future.delayed(const Duration(milliseconds: 600));

      // Assert
      final overallMetrics = debouncer.getOverallMetrics();
      expect(overallMetrics['totalOperations'], equals(2));
      expect(overallMetrics['totalAttempts'], equals(2));
      expect(overallMetrics['totalSuccesses'], equals(1));
      expect(overallMetrics['totalCancellations'], equals(1));
      
      final test1Metrics = debouncer.getMetrics('test1');
      expect(test1Metrics['successes'], equals(1));
      
      final test2Metrics = debouncer.getMetrics('test2');
      expect(test2Metrics['cancellations'], equals(1));
    });

    test('should handle priority-based debouncing', () {
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
}