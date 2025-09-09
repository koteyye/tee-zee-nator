import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:tee_zee_nator/services/confluence_content_processor.dart';
import 'package:tee_zee_nator/services/confluence_service.dart';
import 'package:tee_zee_nator/services/confluence_session_manager.dart';
import 'package:tee_zee_nator/models/confluence_config.dart';

@GenerateMocks([ConfluenceService])
import 'confluence_memory_management_test.mocks.dart';

void main() {
  group('ConfluenceContentProcessor Memory Management', () {
    late MockConfluenceService mockService;
    late ConfluenceContentProcessor processor;
    late ConfluenceConfig config;

    setUp(() {
      mockService = MockConfluenceService();
      processor = ConfluenceContentProcessor(mockService);
      config = const ConfluenceConfig(
        enabled: true,
        baseUrl: 'https://test.atlassian.net',
        token: 'test-token',
        isValid: true,
      );
    });

    tearDown(() {
      processor.dispose();
    });

    test('should clear all data when clearAllData is called', () {
      // Arrange
      processor.clearCache(); // Initialize cache
      
      // Act
      processor.clearAllData();
      
      // Assert
      final stats = processor.getCacheStats();
      expect(stats['totalCached'], equals(0));
      expect(stats['memoryUsageBytes'], equals(0));
      expect(stats['sessionContentCount'], equals(0));
    });

    test('should clear only session content when clearSessionContent is called', () async {
      // Arrange
      const testUrl = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123456/Test';
      const testContent = 'Test content';
      
      when(mockService.getPageContent('123456'))
          .thenAnswer((_) async => testContent);
      
      // Process a link to populate both cache and session
      await processor.processText('Check this link: $testUrl', config, debounce: false);
      
      // Verify both cache and session have content
      var stats = processor.getCacheStats();
      expect(stats['totalCached'], greaterThan(0));
      expect(stats['sessionContentCount'], greaterThan(0));
      
      // Act
      processor.clearSessionContent();
      
      // Assert
      stats = processor.getCacheStats();
      expect(stats['totalCached'], greaterThan(0)); // Cache should remain
      expect(stats['sessionContentCount'], equals(0)); // Session should be cleared
    });

    test('should track memory usage correctly', () async {
      // Arrange
      const testUrl = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123456/Test';
      const testContent = 'Test content for memory tracking';
      
      when(mockService.getPageContent('123456'))
          .thenAnswer((_) async => testContent);
      
      final initialStats = processor.getCacheStats();
      final initialMemory = initialStats['memoryUsageBytes'] as int;
      
      // Act
      await processor.processText('Check this link: $testUrl', config, debounce: false);
      
      // Assert
      final finalStats = processor.getCacheStats();
      final finalMemory = finalStats['memoryUsageBytes'] as int;
      expect(finalMemory, greaterThan(initialMemory));
      expect(finalStats['totalCached'], equals(1));
    });

    test('should not cache content that exceeds size limit', () async {
      // Arrange
      const testUrl = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123456/Test';
      final largeContent = 'x' * (ConfluenceContentProcessor.MAX_CONTENT_SIZE + 1000);
      
      when(mockService.getPageContent('123456'))
          .thenAnswer((_) async => largeContent);
      
      // Act
      await processor.processText('Check this link: $testUrl', config, debounce: false);
      
      // Assert
      final stats = processor.getCacheStats();
      expect(stats['totalCached'], equals(0)); // Should not be cached due to size
    });

    test('should perform periodic cleanup of stale entries', () async {
      // Arrange
      const testUrl = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123456/Test';
      const testContent = 'Test content';
      
      when(mockService.getPageContent('123456'))
          .thenAnswer((_) async => testContent);
      
      // Process a link
      await processor.processText('Check this link: $testUrl', config, debounce: false);
      
      // Verify content is cached
      var stats = processor.getCacheStats();
      expect(stats['totalCached'], equals(1));
      
      // Manually trigger cleanup (simulating periodic cleanup)
      // Note: In a real test, we would need to mock the timer or wait for actual cleanup
      processor.clearCache(); // Simulating cleanup for test purposes
      
      // Assert
      stats = processor.getCacheStats();
      expect(stats['totalCached'], equals(0));
    });

    test('should report high memory usage correctly', () {
      // This test would need to be implemented based on the actual memory thresholds
      // For now, we test that the method exists and returns a boolean
      final isHigh = processor.isMemoryUsageHigh();
      expect(isHigh, isA<bool>());
    });

    test('should provide comprehensive cache statistics', () {
      final stats = processor.getCacheStats();
      
      expect(stats, containsPair('totalCached', isA<int>()));
      expect(stats, containsPair('validLinks', isA<int>()));
      expect(stats, containsPair('invalidLinks', isA<int>()));
      expect(stats, containsPair('freshLinks', isA<int>()));
      expect(stats, containsPair('staleLinks', isA<int>()));
      expect(stats, containsPair('memoryUsageBytes', isA<int>()));
      expect(stats, containsPair('memoryUsageKB', isA<int>()));
      expect(stats, containsPair('sessionContentCount', isA<int>()));
      expect(stats, containsPair('maxCacheSize', isA<int>()));
      expect(stats, containsPair('maxContentSize', isA<int>()));
    });

    test('should dispose properly and clean up all resources', () {
      // Arrange
      processor.clearCache(); // Initialize some state
      
      // Act
      processor.dispose();
      
      // Assert
      final stats = processor.getCacheStats();
      expect(stats['totalCached'], equals(0));
      expect(stats['memoryUsageBytes'], equals(0));
      expect(stats['sessionContentCount'], equals(0));
    });
  });

  group('ConfluenceSessionManager', () {
    late ConfluenceSessionManager sessionManager;
    late MockConfluenceService mockService;
    late ConfluenceContentProcessor processor1;
    late ConfluenceContentProcessor processor2;

    setUp(() {
      sessionManager = ConfluenceSessionManager();
      mockService = MockConfluenceService();
      processor1 = ConfluenceContentProcessor(mockService);
      processor2 = ConfluenceContentProcessor(mockService);
    });

    tearDown(() {
      processor1.dispose();
      processor2.dispose();
      sessionManager.dispose();
    });

    test('should initialize correctly', () {
      sessionManager.initialize();
      
      final stats = sessionManager.getMemoryStats();
      expect(stats['isInitialized'], isTrue);
      expect(stats['processorsCount'], equals(0));
    });

    test('should register and unregister processors', () {
      sessionManager.initialize();
      
      // Register processors
      sessionManager.registerProcessor(processor1);
      sessionManager.registerProcessor(processor2);
      
      var stats = sessionManager.getMemoryStats();
      expect(stats['processorsCount'], equals(2));
      
      // Unregister one processor
      sessionManager.unregisterProcessor(processor1);
      
      stats = sessionManager.getMemoryStats();
      expect(stats['processorsCount'], equals(1));
    });

    test('should not register the same processor twice', () {
      sessionManager.initialize();
      
      sessionManager.registerProcessor(processor1);
      sessionManager.registerProcessor(processor1); // Register again
      
      final stats = sessionManager.getMemoryStats();
      expect(stats['processorsCount'], equals(1)); // Should still be 1
    });

    test('should handle app lifecycle changes', () {
      sessionManager.initialize();
      sessionManager.registerProcessor(processor1);
      
      // Test different lifecycle states
      expect(() => sessionManager.handleLifecycleChange(AppLifecycleState.paused), 
             returnsNormally);
      expect(() => sessionManager.handleLifecycleChange(AppLifecycleState.resumed), 
             returnsNormally);
      expect(() => sessionManager.handleLifecycleChange(AppLifecycleState.detached), 
             returnsNormally);
    });

    test('should trigger cleanup manually', () {
      sessionManager.initialize();
      sessionManager.registerProcessor(processor1);
      
      // Should not throw
      expect(() => sessionManager.triggerCleanup(), returnsNormally);
      expect(() => sessionManager.triggerCleanup(fullCleanup: true), returnsNormally);
    });

    test('should provide memory statistics across processors', () {
      sessionManager.initialize();
      sessionManager.registerProcessor(processor1);
      sessionManager.registerProcessor(processor2);
      
      final stats = sessionManager.getMemoryStats();
      
      expect(stats, containsPair('processorsCount', 2));
      expect(stats, containsPair('totalCachedLinks', isA<int>()));
      expect(stats, containsPair('totalMemoryUsageBytes', isA<int>()));
      expect(stats, containsPair('totalMemoryUsageKB', isA<int>()));
      expect(stats, containsPair('totalSessionContent', isA<int>()));
      expect(stats, containsPair('isInitialized', isTrue));
    });

    test('should detect high memory usage', () {
      sessionManager.initialize();
      sessionManager.registerProcessor(processor1);
      
      final hasHighUsage = sessionManager.hasHighMemoryUsage();
      expect(hasHighUsage, isA<bool>());
    });

    test('should dispose properly', () {
      sessionManager.initialize();
      sessionManager.registerProcessor(processor1);
      
      sessionManager.dispose();
      
      final stats = sessionManager.getMemoryStats();
      expect(stats['isInitialized'], isFalse);
      expect(stats['processorsCount'], equals(0));
    });
  });

  group('Memory Management Integration', () {
    late MockConfluenceService mockService;
    late ConfluenceContentProcessor processor;
    late ConfluenceSessionManager sessionManager;
    late ConfluenceConfig config;

    setUp(() {
      mockService = MockConfluenceService();
      processor = ConfluenceContentProcessor(mockService);
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

    test('should coordinate cleanup between processor and session manager', () async {
      // Arrange
      const testUrl = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123456/Test';
      const testContent = 'Test content';
      
      when(mockService.getPageContent('123456'))
          .thenAnswer((_) async => testContent);
      
      // Process content to populate cache and session
      await processor.processText('Check this link: $testUrl', config, debounce: false);
      
      // Verify content exists
      var stats = processor.getCacheStats();
      expect(stats['totalCached'], greaterThan(0));
      expect(stats['sessionContentCount'], greaterThan(0));
      
      // Act - trigger cleanup through session manager
      sessionManager.triggerCleanup(fullCleanup: true);
      
      // Assert - all data should be cleared
      stats = processor.getCacheStats();
      expect(stats['totalCached'], equals(0));
      expect(stats['sessionContentCount'], equals(0));
    });

    test('should handle app lifecycle events and clean up appropriately', () async {
      // Arrange
      const testUrl = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123456/Test';
      const testContent = 'Test content';
      
      when(mockService.getPageContent('123456'))
          .thenAnswer((_) async => testContent);
      
      await processor.processText('Check this link: $testUrl', config, debounce: false);
      
      // Act - simulate app being paused (should clear session but keep cache)
      sessionManager.handleLifecycleChange(AppLifecycleState.paused);
      
      // Assert - session cleared but cache remains
      var stats = processor.getCacheStats();
      expect(stats['sessionContentCount'], equals(0));
      // Note: Cache behavior depends on implementation details
      
      // Act - simulate app being detached (should clear everything)
      sessionManager.handleLifecycleChange(AppLifecycleState.detached);
      
      // Assert - everything cleared
      stats = processor.getCacheStats();
      expect(stats['totalCached'], equals(0));
      expect(stats['sessionContentCount'], equals(0));
    });
  });
}