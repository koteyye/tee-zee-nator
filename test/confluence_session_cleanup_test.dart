import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/services/confluence_content_processor.dart';
import 'package:tee_zee_nator/services/confluence_service.dart';
import 'package:tee_zee_nator/services/confluence_session_manager.dart';
import 'package:tee_zee_nator/models/confluence_config.dart';

void main() {
  group('Confluence Session Cleanup', () {
    late ConfluenceService confluenceService;
    late ConfluenceContentProcessor processor;
    late ConfluenceSessionManager sessionManager;
    late ConfluenceConfig config;

    setUp(() {
      confluenceService = ConfluenceService();
      processor = ConfluenceContentProcessor(confluenceService);
      sessionManager = ConfluenceSessionManager();
      
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

    test('should clear all data when clearAllData is called', () {
      // Act
      processor.clearAllData();
      
      // Assert
      final stats = processor.getCacheStats();
      expect(stats['totalCached'], equals(0));
      expect(stats['memoryUsageBytes'], equals(0));
      expect(stats['sessionContentCount'], equals(0));
    });

    test('should clear only session content when clearSessionContent is called', () {
      // Act
      processor.clearSessionContent();
      
      // Assert
      final stats = processor.getCacheStats();
      expect(stats['sessionContentCount'], equals(0));
    });

    test('should track memory usage correctly', () {
      final initialStats = processor.getCacheStats();
      final initialMemory = initialStats['memoryUsageBytes'] as int;
      
      // Memory usage should start at 0
      expect(initialMemory, equals(0));
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
      // Arrange - initialize some state
      processor.clearCache();
      
      // Act
      processor.dispose();
      
      // Assert
      final stats = processor.getCacheStats();
      expect(stats['totalCached'], equals(0));
      expect(stats['memoryUsageBytes'], equals(0));
      expect(stats['sessionContentCount'], equals(0));
    });

    test('should report high memory usage correctly', () {
      final isHigh = processor.isMemoryUsageHigh();
      expect(isHigh, isA<bool>());
    });

    test('should get session content correctly', () {
      const testUrl = 'https://test.atlassian.net/wiki/spaces/TEST/pages/123456/Test';
      
      // Should return null for non-existent content
      final content = processor.getSessionContent(testUrl);
      expect(content, isNull);
    });
  });

  group('ConfluenceSessionManager Basic Tests', () {
    late ConfluenceSessionManager sessionManager;
    late ConfluenceService confluenceService;
    late ConfluenceContentProcessor processor1;
    late ConfluenceContentProcessor processor2;

    setUp(() {
      sessionManager = ConfluenceSessionManager();
      confluenceService = ConfluenceService();
      processor1 = ConfluenceContentProcessor(confluenceService);
      processor2 = ConfluenceContentProcessor(confluenceService);
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

    test('should handle app lifecycle changes without errors', () {
      sessionManager.initialize();
      sessionManager.registerProcessor(processor1);
      
      // Test different lifecycle states
      expect(() => sessionManager.handleLifecycleChange(AppLifecycleState.paused), 
             returnsNormally);
      expect(() => sessionManager.handleLifecycleChange(AppLifecycleState.resumed), 
             returnsNormally);
      expect(() => sessionManager.handleLifecycleChange(AppLifecycleState.detached), 
             returnsNormally);
      expect(() => sessionManager.handleLifecycleChange(AppLifecycleState.inactive), 
             returnsNormally);
      expect(() => sessionManager.handleLifecycleChange(AppLifecycleState.hidden), 
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
    late ConfluenceService confluenceService;
    late ConfluenceContentProcessor processor;
    late ConfluenceSessionManager sessionManager;

    setUp(() {
      confluenceService = ConfluenceService();
      processor = ConfluenceContentProcessor(confluenceService);
      sessionManager = ConfluenceSessionManager();
      sessionManager.initialize();
      sessionManager.registerProcessor(processor);
    });

    tearDown(() {
      processor.dispose();
      sessionManager.dispose();
    });

    test('should coordinate cleanup between processor and session manager', () {
      // Verify initial state
      var stats = processor.getCacheStats();
      expect(stats['totalCached'], equals(0));
      expect(stats['sessionContentCount'], equals(0));
      
      // Act - trigger cleanup through session manager
      sessionManager.triggerCleanup(fullCleanup: true);
      
      // Assert - all data should remain cleared
      stats = processor.getCacheStats();
      expect(stats['totalCached'], equals(0));
      expect(stats['sessionContentCount'], equals(0));
    });

    test('should handle app lifecycle events and clean up appropriately', () {
      // Act - simulate app being paused (should clear session but keep cache)
      sessionManager.handleLifecycleChange(AppLifecycleState.paused);
      
      // Assert - session cleared
      var stats = processor.getCacheStats();
      expect(stats['sessionContentCount'], equals(0));
      
      // Act - simulate app being detached (should clear everything)
      sessionManager.handleLifecycleChange(AppLifecycleState.detached);
      
      // Assert - everything cleared
      stats = processor.getCacheStats();
      expect(stats['totalCached'], equals(0));
      expect(stats['sessionContentCount'], equals(0));
    });
  });
}