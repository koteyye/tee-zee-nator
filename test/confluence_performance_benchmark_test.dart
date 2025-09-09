import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:tee_zee_nator/services/confluence_performance_optimizer.dart';
import 'package:tee_zee_nator/services/confluence_content_processor.dart';
import 'package:tee_zee_nator/services/confluence_service.dart';
import 'package:tee_zee_nator/models/confluence_config.dart';

@GenerateMocks([ConfluenceService])
import 'confluence_performance_benchmark_test.mocks.dart';

/// Performance benchmark tests for Confluence optimization features
/// 
/// These tests measure actual performance improvements and ensure
/// optimizations meet performance requirements from the specification.
void main() {
  group('Confluence Performance Benchmarks', () {
    late MockConfluenceService mockService;
    late ConfluenceConfig testConfig;

    setUp(() {
      mockService = MockConfluenceService();
      testConfig = ConfluenceConfig(
        enabled: true,
        baseUrl: 'https://test.atlassian.net',
        token: 'test-token',
        isValid: true,
      );
    });

    group('Caching Performance', () {
      test('should demonstrate significant performance improvement with caching', () async {
        // Arrange
        final processor = ConfluenceContentProcessor(mockService);
        final optimizer = ConfluencePerformanceOptimizer(mockService, processor);
        
        const testText = '''
        Check these important links:
        https://test.atlassian.net/wiki/spaces/TEST/pages/1/Page1
        https://test.atlassian.net/wiki/spaces/TEST/pages/2/Page2
        https://test.atlassian.net/wiki/spaces/TEST/pages/3/Page3
        ''';
        
        // Mock service with realistic delay
        when(mockService.getPageContent(any)).thenAnswer((invocation) async {
          await Future.delayed(const Duration(milliseconds: 100)); // Simulate network delay
          return 'Content for page ${invocation.positionalArguments[0]}';
        });

        // Act - First run (cold cache)
        final stopwatch1 = Stopwatch()..start();
        await optimizer.processTextOptimized(testText, testConfig);
        stopwatch1.stop();
        final coldCacheTime = stopwatch1.elapsedMilliseconds;

        // Act - Second run (warm cache)
        final stopwatch2 = Stopwatch()..start();
        await optimizer.processTextOptimized(testText, testConfig);
        stopwatch2.stop();
        final warmCacheTime = stopwatch2.elapsedMilliseconds;

        // Assert - Warm cache should be significantly faster
        expect(warmCacheTime, lessThan(coldCacheTime * 0.1)); // At least 90% improvement
        expect(coldCacheTime, greaterThan(200)); // Should take time for network calls
        expect(warmCacheTime, lessThan(50)); // Should be very fast from cache

        print('Cold cache time: ${coldCacheTime}ms');
        print('Warm cache time: ${warmCacheTime}ms');
        print('Performance improvement: ${((coldCacheTime - warmCacheTime) / coldCacheTime * 100).toStringAsFixed(1)}%');

        final metrics = optimizer.getPerformanceMetrics();
        expect(double.parse(metrics['cacheHitRate'].toString().replaceAll('%', '')), greaterThan(50.0));

        processor.dispose();
        optimizer.dispose();
      });

      test('should maintain performance with large cache', () async {
        // Arrange
        final processor = ConfluenceContentProcessor(mockService);
        final optimizer = ConfluencePerformanceOptimizer(
          mockService, 
          processor,
          maxCacheSize: 1000,
        );
        
        when(mockService.getPageContent(any)).thenAnswer((invocation) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 'Content for page ${invocation.positionalArguments[0]}';
        });

        // Act - Fill cache with many entries
        final times = <int>[];
        for (int i = 0; i < 100; i++) {
          final text = 'https://test.atlassian.net/wiki/spaces/TEST/pages/$i/Page$i';
          
          final stopwatch = Stopwatch()..start();
          await optimizer.processTextOptimized(text, testConfig);
          stopwatch.stop();
          
          times.add(stopwatch.elapsedMilliseconds);
        }

        // Assert - Performance should remain consistent
        final averageTime = times.reduce((a, b) => a + b) / times.length;
        final maxTime = times.reduce((a, b) => a > b ? a : b);
        final minTime = times.reduce((a, b) => a < b ? a : b);
        
        expect(maxTime - minTime, lessThan(averageTime * 2)); // Variance should be reasonable
        expect(averageTime, lessThan(100)); // Should be fast on average

        print('Average processing time: ${averageTime.toStringAsFixed(1)}ms');
        print('Min time: ${minTime}ms, Max time: ${maxTime}ms');

        processor.dispose();
        optimizer.dispose();
      });
    });

    group('Batch Processing Performance', () {
      test('should demonstrate batch processing efficiency', () async {
        // Arrange
        final processor = ConfluenceContentProcessor(mockService);
        final optimizerWithBatch = ConfluencePerformanceOptimizer(mockService, processor);
        final optimizerWithoutBatch = ConfluencePerformanceOptimizer(mockService, processor);
        
        final testText = List.generate(10, (i) => 
            'https://test.atlassian.net/wiki/spaces/TEST/pages/$i/Page$i').join('\n');
        
        when(mockService.getPageContent(any)).thenAnswer((invocation) async {
          await Future.delayed(const Duration(milliseconds: 50)); // Simulate network delay
          return 'Content for page ${invocation.positionalArguments[0]}';
        });

        // Act - With batch processing
        final stopwatch1 = Stopwatch()..start();
        await optimizerWithBatch.processTextOptimized(
          testText, 
          testConfig, 
          enableBatching: true,
        );
        stopwatch1.stop();
        final batchTime = stopwatch1.elapsedMilliseconds;

        // Clear cache for fair comparison
        optimizerWithoutBatch.clearCache();

        // Act - Without batch processing (sequential)
        final stopwatch2 = Stopwatch()..start();
        await optimizerWithoutBatch.processTextOptimized(
          testText, 
          testConfig, 
          enableBatching: false,
        );
        stopwatch2.stop();
        final sequentialTime = stopwatch2.elapsedMilliseconds;

        // Assert - Batch processing should be faster
        expect(batchTime, lessThan(sequentialTime * 0.8)); // At least 20% improvement
        
        print('Batch processing time: ${batchTime}ms');
        print('Sequential processing time: ${sequentialTime}ms');
        print('Batch improvement: ${((sequentialTime - batchTime) / sequentialTime * 100).toStringAsFixed(1)}%');

        processor.dispose();
        optimizerWithBatch.dispose();
        optimizerWithoutBatch.dispose();
      });

      test('should handle concurrent batch requests efficiently', () async {
        // Arrange
        final processor = ConfluenceContentProcessor(mockService);
        final optimizer = ConfluencePerformanceOptimizer(mockService, processor);
        
        when(mockService.getPageContent(any)).thenAnswer((invocation) async {
          await Future.delayed(const Duration(milliseconds: 30));
          return 'Content for page ${invocation.positionalArguments[0]}';
        });

        // Act - Make multiple concurrent batch requests
        final futures = List.generate(5, (batchIndex) {
          final text = List.generate(5, (i) => 
              'https://test.atlassian.net/wiki/spaces/TEST/pages/${batchIndex * 5 + i}/Page${batchIndex * 5 + i}').join('\n');
          return optimizer.processTextOptimized(text, testConfig);
        });

        final stopwatch = Stopwatch()..start();
        await Future.wait(futures);
        stopwatch.stop();

        // Assert - Should complete in reasonable time despite concurrency
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should be much faster than sequential
        
        final metrics = optimizer.getPerformanceMetrics();
        expect(int.parse(metrics['deduplications'].toString()), greaterThan(0));

        print('Concurrent batch processing time: ${stopwatch.elapsedMilliseconds}ms');
        print('Deduplications: ${metrics['deduplications']}');

        processor.dispose();
        optimizer.dispose();
      });
    });

    group('Debouncing Performance', () {
      test('should reduce API calls through effective debouncing', () async {
        // Arrange
        final processor = ConfluenceContentProcessor(mockService);
        int apiCallCount = 0;
        
        when(mockService.getPageContent(any)).thenAnswer((invocation) async {
          apiCallCount++;
          await Future.delayed(const Duration(milliseconds: 10));
          return 'Content for page ${invocation.positionalArguments[0]}';
        });

        const testText = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123/Page';

        // Act - Simulate rapid text changes (like user typing)
        final futures = <Future<String>>[];
        for (int i = 0; i < 10; i++) {
          futures.add(processor.processText(testText, testConfig, debounce: true));
          await Future.delayed(const Duration(milliseconds: 50)); // Rapid changes
        }

        await Future.wait(futures);

        // Assert - Should make fewer API calls due to debouncing
        expect(apiCallCount, lessThan(5)); // Should be significantly reduced
        expect(apiCallCount, greaterThan(0)); // But should make at least one call

        print('API calls made: $apiCallCount out of 10 potential calls');
        print('API call reduction: ${((10 - apiCallCount) / 10 * 100).toStringAsFixed(1)}%');

        processor.dispose();
      });
    });

    group('Memory Usage Performance', () {
      test('should maintain reasonable memory usage under load', () async {
        // Arrange
        final processor = ConfluenceContentProcessor(mockService);
        final optimizer = ConfluencePerformanceOptimizer(
          mockService, 
          processor,
          maxMemoryMB: 10,
        );
        
        when(mockService.getPageContent(any)).thenAnswer((invocation) async {
          return 'A' * 1000; // 1KB content per page
        });

        // Act - Process many different pages
        for (int i = 0; i < 100; i++) {
          final text = 'https://test.atlassian.net/wiki/spaces/TEST/pages/$i/Page$i';
          await optimizer.processTextOptimized(text, testConfig);
        }

        // Assert - Memory usage should be within limits
        final metrics = optimizer.getPerformanceMetrics();
        final memoryUsageMB = double.parse(metrics['memoryUsageMB'].toString());
        final memoryUtilization = double.parse(metrics['memoryUtilization'].toString().replaceAll('%', ''));
        
        expect(memoryUsageMB, lessThan(10.0)); // Should not exceed limit
        expect(memoryUtilization, lessThan(100.0)); // Should not be at 100%
        
        print('Memory usage: ${memoryUsageMB}MB ($memoryUtilization% utilization)');
        print('Cache size: ${metrics['cacheSize']} entries');

        processor.dispose();
        optimizer.dispose();
      });

      test('should perform efficient cache eviction', () async {
        // Arrange
        final processor = ConfluenceContentProcessor(mockService);
        final optimizer = ConfluencePerformanceOptimizer(
          mockService, 
          processor,
          maxCacheSize: 50,
          maxMemoryMB: 1,
        );
        
        when(mockService.getPageContent(any)).thenAnswer((invocation) async {
          return 'Content for page ${invocation.positionalArguments[0]}';
        });

        // Act - Fill cache beyond capacity
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          final text = 'https://test.atlassian.net/wiki/spaces/TEST/pages/$i/Page$i';
          await optimizer.processTextOptimized(text, testConfig);
        }
        stopwatch.stop();

        // Assert - Should maintain performance despite evictions
        final metrics = optimizer.getPerformanceMetrics();
        final cacheSize = int.parse(metrics['cacheSize'].toString());
        
        expect(cacheSize, lessThanOrEqualTo(50)); // Should not exceed max size
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // Should complete in reasonable time
        
        print('Final cache size: $cacheSize entries');
        print('Total processing time: ${stopwatch.elapsedMilliseconds}ms');

        processor.dispose();
        optimizer.dispose();
      });
    });

    group('Overall System Performance', () {
      test('should meet performance requirements under realistic load', () async {
        // Arrange - Simulate realistic usage scenario
        final processor = ConfluenceContentProcessor(mockService);
        final optimizer = ConfluencePerformanceOptimizer(mockService, processor);
        
        when(mockService.getPageContent(any)).thenAnswer((invocation) async {
          // Simulate variable network delays
          final delay = 50 + (invocation.positionalArguments[0].hashCode % 100);
          await Future.delayed(Duration(milliseconds: delay));
          return 'Content for page ${invocation.positionalArguments[0]}';
        });

        // Realistic text with mixed content
        const realisticText = '''
        Please review the following requirements:
        
        1. User authentication: https://test.atlassian.net/wiki/spaces/AUTH/pages/123/Authentication
        2. Data validation: https://test.atlassian.net/wiki/spaces/DATA/pages/456/Validation
        3. Error handling: https://test.atlassian.net/wiki/spaces/ERROR/pages/789/Handling
        
        Additional considerations from:
        https://test.atlassian.net/wiki/spaces/ARCH/pages/101/Architecture
        https://test.atlassian.net/wiki/spaces/SEC/pages/202/Security
        ''';

        // Act - Process realistic workload
        final stopwatch = Stopwatch()..start();
        
        // First processing (cold cache)
        await optimizer.processTextOptimized(realisticText, testConfig);
        
        // Simulate user making changes and reprocessing
        for (int i = 0; i < 5; i++) {
          final modifiedText = '$realisticText\nAdditional note $i';
          await optimizer.processTextOptimized(modifiedText, testConfig);
        }
        
        stopwatch.stop();

        // Assert - Should meet performance requirements
        final totalTime = stopwatch.elapsedMilliseconds;
        final metrics = optimizer.getPerformanceMetrics();
        
        expect(totalTime, lessThan(3000)); // Should complete within 3 seconds
        expect(double.parse(metrics['cacheHitRate'].toString().replaceAll('%', '')), greaterThan(60.0)); // Good cache hit rate
        expect(double.parse(metrics['averageProcessingTimeMs'].toString()), lessThan(500)); // Fast average processing
        
        print('Total processing time: ${totalTime}ms');
        print('Cache hit rate: ${metrics['cacheHitRate']}');
        print('Average processing time: ${metrics['averageProcessingTimeMs']}ms');
        print('Total requests: ${metrics['totalRequests']}');
        print('Deduplications: ${metrics['deduplications']}');

        processor.dispose();
        optimizer.dispose();
      });
    });
  });
}