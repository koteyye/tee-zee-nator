import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/services/confluence_service.dart';
import 'package:tee_zee_nator/models/confluence_config.dart';
import 'package:tee_zee_nator/exceptions/confluence_exceptions.dart';

void main() {
  group('ConfluenceService', () {
    late ConfluenceService confluenceService;
    late ConfluenceConfig testConfig;

    setUp(() {
      confluenceService = ConfluenceService();
      testConfig = const ConfluenceConfig(
        enabled: true,
        baseUrl: 'https://test.atlassian.net',
        token: 'test@example.com:test-token',
        isValid: true,
      );
    });

    tearDown(() {
      confluenceService.dispose();
    });

    group('Initialization and Configuration', () {
      test('should initialize with default state', () {
        expect(confluenceService.config, isNull);
        expect(confluenceService.isLoading, isFalse);
        expect(confluenceService.lastError, isNull);
        expect(confluenceService.isConfigured, isFalse);
        expect(confluenceService.isConnected, isFalse);
      });

      test('should initialize with configuration', () {
        confluenceService.initialize(testConfig);
        
        expect(confluenceService.config, equals(testConfig));
        expect(confluenceService.isConfigured, isTrue);
        expect(confluenceService.isConnected, isTrue);
        expect(confluenceService.lastError, isNull);
      });

      test('should handle incomplete configuration', () {
        final incompleteConfig = const ConfluenceConfig(
          enabled: true,
          baseUrl: '',
          token: 'test-token',
          isValid: false,
        );
        
        confluenceService.initialize(incompleteConfig);
        
        expect(confluenceService.isConfigured, isFalse);
        expect(confluenceService.isConnected, isFalse);
      });
    });

    group('Connection Testing', () {
      test('should validate input parameters', () async {
  final result1 = await confluenceService.testConnection('', '', 'token');
        expect(result1, isFalse);
        expect(confluenceService.lastError, contains('required'));

  final result2 = await confluenceService.testConnection('url', '', '');
        expect(result2, isFalse);
        expect(confluenceService.lastError, contains('required'));
      });

      test('should handle invalid base URL format', () async {
  final result = await confluenceService.testConnection('invalid-url', '', 'token');
        expect(result, isFalse);
        expect(confluenceService.lastError, isNotNull);
      });
    });

    group('Page Content Retrieval', () {
      test('should throw validation exception for empty page ID', () async {
        confluenceService.initialize(testConfig);

        expect(
          () => confluenceService.getPageContent(''),
          throwsA(isA<ConfluenceValidationException>()),
        );
      });

      test('should throw validation exception when not configured', () async {
        expect(
          () => confluenceService.getPageContent('123456'),
          throwsA(isA<ConfluenceValidationException>()),
        );
      });
    });

    group('Page Information Retrieval', () {
      test('should throw validation exception for empty URL', () async {
        confluenceService.initialize(testConfig);

        expect(
          () => confluenceService.getPageInfo(''),
          throwsA(isA<ConfluenceValidationException>()),
        );
      });

      test('should throw validation exception for invalid URL format', () async {
        confluenceService.initialize(testConfig);

        expect(
          () => confluenceService.getPageInfo('https://invalid-url.com'),
          throwsA(isA<ConfluenceValidationException>()),
        );
      });

      test('should throw validation exception when not configured', () async {
        expect(
          () => confluenceService.getPageInfo('https://test.atlassian.net/wiki/spaces/TEST/pages/123456/Test'),
          throwsA(isA<ConfluenceValidationException>()),
        );
      });
    });

    group('State Management', () {
      test('should notify listeners on state changes', () {
        bool notified = false;
        confluenceService.addListener(() {
          notified = true;
        });

        confluenceService.initialize(testConfig);
        expect(notified, isTrue);
      });

      test('should manage loading state during operations', () async {
        expect(confluenceService.isLoading, isFalse);
        
        // Test connection will set loading state
  final future = confluenceService.testConnection('invalid', '', 'token');
        
        await future;
        
        // Should be false after operation completes
        expect(confluenceService.isLoading, isFalse);
      });

      test('should clear errors on successful initialization', () async {
        // First, cause an error
  await confluenceService.testConnection('', '', '');
        expect(confluenceService.lastError, isNotNull);

        // Then, initialize successfully
        confluenceService.initialize(testConfig);
        expect(confluenceService.lastError, isNull);
      });
    });

    group('URL Validation and Processing', () {
      test('should validate Confluence page URLs correctly', () {
        confluenceService.initialize(testConfig);

        // Valid URLs should not throw immediately (will fail on network call)
        expect(
          () => confluenceService.getPageInfo('https://test.atlassian.net/wiki/spaces/TEST/pages/123456/Test'),
          throwsA(isA<ConfluenceException>()),
        );

        // Invalid URLs should throw validation exception
        expect(
          () => confluenceService.getPageInfo('not-a-url'),
          throwsA(isA<ConfluenceValidationException>()),
        );
      });
    });

    group('Error Handling', () {
      test('should handle configuration validation errors', () {
        final invalidConfig = const ConfluenceConfig(
          enabled: true,
          baseUrl: '',
          token: '',
          isValid: false,
        );
        
        confluenceService.initialize(invalidConfig);
        
        expect(confluenceService.isConfigured, isFalse);
        
        expect(
          () => confluenceService.getPageContent('123456'),
          throwsA(isA<ConfluenceValidationException>()),
        );
      });

      test('should provide meaningful error messages', () async {
        try {
          await confluenceService.getPageContent('123456');
          fail('Should have thrown an exception');
        } catch (e) {
          expect(e, isA<ConfluenceValidationException>());
          final exception = e as ConfluenceValidationException;
          expect(exception.message, contains('not configured'));
          expect(exception.recoveryAction, isNotNull);
        }
      });
    });
  });
}