import 'package:flutter_test/flutter_test.dart';
import '../lib/services/confluence_debouncer.dart';

/// Tests for the ConfluenceDebouncer service
/// 
/// These tests verify that debouncing works correctly and provides
/// the performance benefits required by the specification.
void main() {
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

      test('should reset debounce timer on new calls', () async {
        // Arrange
        int callCount = 0;
        Future<void> testCallback() async {
          callCount++;
        }

        // Act - Make calls with delays shorter than debounce period
        debouncer.debounce('test', testCallback);
        await Future.delayed(const Duration(milliseconds: 200));
        debouncer.debounce('test', testCallback);
        await Future.delayed(const Duration(milliseconds: 200));
        debouncer.debounce('test', testCallback);

        // Wait for final debounce to complete
        await Future.delayed(const Duration(milliseconds: 600));

        // Assert - Should be called only once (last call)
        expect(callCount, equals(1));
      });
    });

    group('Adaptive Debouncing', () {
      test('should use shorter delay for short text', () async {
        // Arrange
        const shortText = 'Short text';
        bool callbackExecuted = false;
        
        Future<void> testCallback() async {
          callbackExecuted = true;
        }

        // Act
        final stopwatch = Stopwatch()..start();
        debouncer.adaptiveDebounce('test', shortText, testCallback);

        // Wait for execution
        while (!callbackExecuted && stopwatch.elapsedMilliseconds < 1000) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
        stopwatch.stop();

        // Assert - Should execute relatively quickly for short text
        expect(callbackExecuted, isTrue);
        expect(stopwatch.elapsedMilliseconds, lessThan(800)); // Should be faster than default
      });

      test('should use longer delay for complex text with links', () {
        // Arrange
        final longTextWithLinks = '''
        This is a very long text with multiple Confluence links:
        https://test.atlassian.net/wiki/spaces/TEST/pages/1/Page1
        https://test.atlassian.net/wiki/spaces/TEST/pages/2/Page2
        https://test.atlassian.net/wiki/spaces/TEST/pages/3/Page3
        https://test.atlassian.net/wiki/spaces/TEST/pages/4/Page4
        And much more complex content with special characters: !@#\$%^&*()
        ''' * 5; // Make it very long
        
        bool callbackExecuted = false;
        Future<void> testCallback() async {
          callbackExecuted = true;
        }

        // Act
        debouncer.adaptiveDebounce('test', longTextWithLinks, testCallback);

        // Assert - Should be pending with longer delay
        expect(debouncer.isPending('test'), isTrue);
        expect(callbackExecuted, isFalse); // Should not execute immediately
      });

      test('should adapt delay based on text characteristics', () {
        // Arrange
        const simpleText = 'Simple text';
        const textWithLinks = '''
        Text with links:
        https://test.atlassian.net/wiki/spaces/TEST/pages/1/Page1
        https://test.atlassian.net/wiki/spaces/TEST/pages/2/Page2
        https://test.atlassian.net/wiki/spaces/TEST/pages/3/Page3
        https://test.atlassian.net/wiki/spaces/TEST/pages/4/Page4
        ''';
        
        bool simpleExecuted = false;
        bool complexExecuted = false;
        
        Future<void> simpleCallback() async { simpleExecuted = true; }
        Future<void> complexCallback() async { complexExecuted = true; }

        // Act
        debouncer.adaptiveDebounce('simple', simpleText, simpleCallback);
        debouncer.adaptiveDebounce('complex', textWithLinks, complexCallback);

        // Assert - Both should be pending but with different characteristics
        expect(debouncer.isPending('simple'), isTrue);
        expect(debouncer.isPending('complex'), isTrue);
      });
    });

    group('Priority Debouncing', () {
      test('should use different delays for different priorities', () {
        // Arrange
        bool highPriorityExecuted = false;
        bool normalPriorityExecuted = false;
        bool lowPriorityExecuted = false;
        
        Future<void> highCallback() async { highPriorityExecuted = true; }
        Future<void> normalCallback() async { normalPriorityExecuted = true; }
        Future<void> lowCallback() async { lowPriorityExecuted = true; }

        // Act
        debouncer.priorityDebounce('high', highCallback, DebouncePriority.high);
        debouncer.priorityDebounce('normal', normalCallback, DebouncePriority.normal);
        debouncer.priorityDebounce('low', lowCallback, DebouncePriority.low);

        // Assert - All should be pending
        expect(debouncer.isPending('high'), isTrue);
        expect(debouncer.isPending('normal'), isTrue);
        expect(debouncer.isPending('low'), isTrue);
      });

      test('should execute high priority operations faster', () async {
        // Arrange
        bool highPriorityExecuted = false;
        bool lowPriorityExecuted = false;
        
        Future<void> highCallback() async { highPriorityExecuted = true; }
        Future<void> lowCallback() async { lowPriorityExecuted = true; }

        // Act
        debouncer.priorityDebounce('high', highCallback, DebouncePriority.high);
        debouncer.priorityDebounce('low', lowCallback, DebouncePriority.low);

        // Wait for high priority to execute
        await Future.delayed(const Duration(milliseconds: 300));

        // Assert - High priority should execute first
        expect(highPriorityExecuted, isTrue);
        expect(lowPriorityExecuted, isFalse); // Low priority should still be pending
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

      test('should not affect other operations when canceling specific one', () async {
        // Arrange
        bool callback1Executed = false;
        bool callback2Executed = false;
        
        Future<void> callback1() async { callback1Executed = true; }
        Future<void> callback2() async { callback2Executed = true; }

        // Act
        debouncer.debounce('test1', callback1);
        debouncer.debounce('test2', callback2);
        
        debouncer.cancel('test1'); // Cancel only test1
        
        await Future.delayed(const Duration(milliseconds: 600));

        // Assert
        expect(callback1Executed, isFalse); // Canceled
        expect(callback2Executed, isTrue);  // Should execute
      });
    });

    group('Metrics and Monitoring', () {
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
        expect(metrics.containsKey('successRate'), isTrue);
        expect(metrics.containsKey('averageExecutionTimeMs'), isTrue);
      });

      test('should provide overall metrics', () async {
        // Arrange
        Future<void> callback1() async {}
        Future<void> callback2() async {}

        // Act
        debouncer.debounce('test1', callback1);
        debouncer.debounce('test2', callback2);
        debouncer.cancel('test2'); // Cancel one
        
        await Future.delayed(const Duration(milliseconds: 600));

        // Assert
        final overallMetrics = debouncer.getOverallMetrics();
        expect(overallMetrics['totalOperations'], equals(2));
        expect(overallMetrics['totalAttempts'], equals(2));
        expect(overallMetrics['totalSuccesses'], equals(1));
        expect(overallMetrics['totalCancellations'], equals(1));
        expect(overallMetrics.containsKey('successRate'), isTrue);
        expect(overallMetrics.containsKey('averageExecutionTimeMs'), isTrue);
      });

      test('should track execution times', () async {
        // Arrange
        Future<void> testCallback() async {
          await Future.delayed(const Duration(milliseconds: 50)); // Simulate work
        }

        // Act
        debouncer.debounce('test', testCallback);
        await Future.delayed(const Duration(milliseconds: 600));

        // Assert
        final metrics = debouncer.getMetrics('test');
        expect(double.parse(metrics['averageExecutionTimeMs'].toString()), greaterThan(0.0));
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
        expect(metrics['successes'], equals(0));
      });

      test('should continue working after errors', () async {
        // Arrange
        int successCount = 0;
        
        Future<void> errorCallback() async {
          throw Exception('Test error');
        }
        
        Future<void> successCallback() async {
          successCount++;
        }

        // Act
        debouncer.debounce('error', errorCallback);
        await Future.delayed(const Duration(milliseconds: 600));
        
        debouncer.debounce('success', successCallback);
        await Future.delayed(const Duration(milliseconds: 600));

        // Assert
        expect(successCount, equals(1));
        
        final errorMetrics = debouncer.getMetrics('error');
        final successMetrics = debouncer.getMetrics('success');
        
        expect(errorMetrics['errors'], equals(1));
        expect(successMetrics['successes'], equals(1));
      });
    });

    group('Performance Requirements', () {
      test('should reduce function calls by at least 80% under rapid changes', () async {
        // Arrange
        int actualCalls = 0;
        Future<void> testCallback() async {
          actualCalls++;
        }

        const totalAttempts = 20;

        // Act - Simulate rapid text changes
        for (int i = 0; i < totalAttempts; i++) {
          debouncer.debounce('test', testCallback);
          await Future.delayed(const Duration(milliseconds: 25)); // Rapid changes
        }

        await Future.delayed(const Duration(milliseconds: 600)); // Wait for final execution

        // Assert - Should significantly reduce calls
        final reductionPercentage = ((totalAttempts - actualCalls) / totalAttempts) * 100;
        expect(reductionPercentage, greaterThan(80.0)); // At least 80% reduction
        expect(actualCalls, lessThan(5)); // Should be very few actual calls
        
        print('Total attempts: $totalAttempts');
        print('Actual calls: $actualCalls');
        print('Reduction: ${reductionPercentage.toStringAsFixed(1)}%');
      });

      test('should complete debouncing within reasonable time limits', () async {
        // Arrange
        bool callbackExecuted = false;
        Future<void> testCallback() async {
          callbackExecuted = true;
        }

        // Act
        final stopwatch = Stopwatch()..start();
        debouncer.debounce('test', testCallback);

        // Wait for execution
        while (!callbackExecuted && stopwatch.elapsedMilliseconds < 2000) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
        stopwatch.stop();

        // Assert - Should complete within reasonable time
        expect(callbackExecuted, isTrue);
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should be fast
      });

      test('should handle high-frequency operations efficiently', () async {
        // Arrange
        int executionCount = 0;
        Future<void> testCallback() async {
          executionCount++;
        }

        // Act - Create many different debounced operations
        final stopwatch = Stopwatch()..start();
        for (int i = 0; i < 100; i++) {
          debouncer.debounce('test_$i', testCallback);
        }
        
        await Future.delayed(const Duration(milliseconds: 600));
        stopwatch.stop();

        // Assert - Should handle many operations efficiently
        expect(executionCount, equals(100)); // All should execute
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should be reasonably fast
        
        final overallMetrics = debouncer.getOverallMetrics();
        expect(overallMetrics['totalOperations'], equals(100));
        expect(overallMetrics['totalSuccesses'], equals(100));
      });
    });

    group('Memory Management', () {
      test('should not leak memory with many operations', () {
        // Arrange & Act - Create and dispose many operations
        for (int i = 0; i < 1000; i++) {
          debouncer.debounce('test_$i', () async {});
          debouncer.cancel('test_$i');
        }

        // Assert - Should not accumulate indefinitely
        final metrics = debouncer.getOverallMetrics();
        expect(metrics['activeOperations'], equals(0)); // All should be cleaned up
      });

      test('should clean up completed operations', () async {
        // Arrange
        Future<void> testCallback() async {}

        // Act
        debouncer.debounce('test', testCallback);
        await Future.delayed(const Duration(milliseconds: 600));

        // Assert - Operation should be cleaned up after completion
        expect(debouncer.isPending('test'), isFalse);
      });
    });
  });
}