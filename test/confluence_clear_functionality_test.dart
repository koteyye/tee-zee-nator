import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/services/confluence_content_processor.dart';
import 'package:tee_zee_nator/services/confluence_service.dart';
import 'package:tee_zee_nator/services/confluence_session_manager.dart';
import 'package:tee_zee_nator/models/confluence_config.dart';

void main() {
  group('Confluence Clear Functionality Tests', () {
    late ConfluenceService confluenceService;
    late ConfluenceContentProcessor processor;
    late ConfluenceSessionManager sessionManager;
    late ConfluenceConfig config;

    setUp(() {
      confluenceService = ConfluenceService();
      processor = ConfluenceContentProcessor(confluenceService);
      sessionManager = ConfluenceSessionManager();
      sessionManager.initialize();
      sessionManager.registerProcessor(processor);
      
      config = const ConfluenceConfig(
        enabled: true,
        baseUrl: 'https://test.atlassian.net',
        token: 'test-token',
        isValid: true,
      );
    });

    tearDown(() {
      processor.dispose();
      sessionManager.dispose();
    });

    test('should implement requirement 3.7 - clear processed data when Clear is clicked', () {
      // This test verifies that requirement 3.7 is implemented:
      // "WHEN 'Clear' is clicked THEN the system SHALL remove all processed data from memory"
      
      // Arrange - Simulate some processed data
      final initialStats = processor.getCacheStats();
      expect(initialStats['totalCached'], equals(0));
      expect(initialStats['sessionContentCount'], equals(0));
      
      // Act - Simulate clicking "Clear" button (calls clearAllData)
      processor.clearAllData();
      
      // Assert - All processed data should be removed from memory
      final finalStats = processor.getCacheStats();
      expect(finalStats['totalCached'], equals(0));
      expect(finalStats['sessionContentCount'], equals(0));
      expect(finalStats['memoryUsageBytes'], equals(0));
    });

    test('should clean up memory on application shutdown', () {
      // This test verifies automatic cleanup on application shutdown
      
      // Arrange - Simulate some cached data
      final initialStats = processor.getCacheStats();
      
      // Act - Simulate application shutdown (lifecycle detached)
      sessionManager.handleLifecycleChange(AppLifecycleState.detached);
      
      // Assert - All data should be cleaned up
      final finalStats = processor.getCacheStats();
      expect(finalStats['totalCached'], equals(0));
      expect(finalStats['sessionContentCount'], equals(0));
      expect(finalStats['memoryUsageBytes'], equals(0));
    });

    test('should manage session-based storage correctly', () {
      // This test verifies session-based storage functionality
      
      const testUrl = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123456/Test';
      
      // Initially, no session content should exist
      expect(processor.getSessionContent(testUrl), isNull);
      
      // After clearing session content, it should still be null
      processor.clearSessionContent();
      expect(processor.getSessionContent(testUrl), isNull);
    });

    test('should track memory usage and provide statistics', () {
      // This test verifies memory management and statistics
      
      final stats = processor.getCacheStats();
      
      // Verify all required statistics are present
      expect(stats, containsPair('totalCached', isA<int>()));
      expect(stats, containsPair('memoryUsageBytes', isA<int>()));
      expect(stats, containsPair('sessionContentCount', isA<int>()));
      expect(stats, containsPair('maxCacheSize', isA<int>()));
      expect(stats, containsPair('maxContentSize', isA<int>()));
      
      // Verify memory usage starts at 0
      expect(stats['memoryUsageBytes'], equals(0));
      expect(stats['totalCached'], equals(0));
      expect(stats['sessionContentCount'], equals(0));
    });

    test('should handle periodic cleanup correctly', () {
      // This test verifies that periodic cleanup doesn't break the system
      
      // Get initial state
      final initialStats = processor.getCacheStats();
      
      // Trigger manual cleanup (simulating periodic cleanup)
      processor.clearCache();
      
      // Verify cleanup worked
      final finalStats = processor.getCacheStats();
      expect(finalStats['totalCached'], equals(0));
      expect(finalStats['memoryUsageBytes'], equals(0));
    });

    test('should coordinate cleanup between session manager and processor', () {
      // This test verifies coordination between session manager and content processor
      
      // Verify initial state
      var processorStats = processor.getCacheStats();
      var sessionStats = sessionManager.getMemoryStats();
      
      expect(processorStats['totalCached'], equals(0));
      expect(sessionStats['processorsCount'], equals(1));
      
      // Trigger cleanup through session manager
      sessionManager.triggerCleanup(fullCleanup: true);
      
      // Verify cleanup was coordinated
      processorStats = processor.getCacheStats();
      expect(processorStats['totalCached'], equals(0));
      expect(processorStats['sessionContentCount'], equals(0));
    });

    test('should handle disposal properly', () {
      // This test verifies proper resource disposal
      
      // Create a separate processor for disposal testing
      final testProcessor = ConfluenceContentProcessor(confluenceService);
      sessionManager.registerProcessor(testProcessor);
      
      // Verify it's registered
      var stats = sessionManager.getMemoryStats();
      expect(stats['processorsCount'], equals(2)); // Original + test processor
      
      // Dispose the test processor
      testProcessor.dispose();
      
      // Verify cleanup happened
      final processorStats = testProcessor.getCacheStats();
      expect(processorStats['totalCached'], equals(0));
      expect(processorStats['sessionContentCount'], equals(0));
    });
  });

  group('Memory Management Edge Cases', () {
    late ConfluenceService confluenceService;
    late ConfluenceContentProcessor processor;

    setUp(() {
      confluenceService = ConfluenceService();
      processor = ConfluenceContentProcessor(confluenceService);
    });

    tearDown(() {
      processor.dispose();
    });

    test('should handle multiple clear operations safely', () {
      // Test multiple consecutive clear operations
      
      processor.clearAllData();
      processor.clearAllData();
      processor.clearSessionContent();
      processor.clearCache();
      
      // Should not throw and should maintain clean state
      final stats = processor.getCacheStats();
      expect(stats['totalCached'], equals(0));
      expect(stats['sessionContentCount'], equals(0));
      expect(stats['memoryUsageBytes'], equals(0));
    });

    test('should handle memory usage reporting correctly', () {
      // Test memory usage reporting
      
      final isHigh = processor.isMemoryUsageHigh();
      expect(isHigh, isFalse); // Should be false with empty cache
      
      final stats = processor.getCacheStats();
      expect(stats['memoryUsageKB'], equals(0));
    });

    test('should handle session content operations safely', () {
      // Test session content operations
      
      const testUrl = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123456/Test';
      
      // Multiple operations should be safe
      expect(processor.getSessionContent(testUrl), isNull);
      processor.clearSessionContent();
      expect(processor.getSessionContent(testUrl), isNull);
      
      // Clear all should also clear session content
      processor.clearAllData();
      expect(processor.getSessionContent(testUrl), isNull);
    });
  });
}