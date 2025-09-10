import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/exceptions/confluence_exceptions.dart';

void main() {
  group('ConfluenceException', () {
    group('base functionality', () {
      test('toString returns formatted message', () {
        final exception = ConfluenceConnectionException(
          'Connection failed',
          baseUrl: 'https://example.atlassian.net',
        );

        expect(exception.toString(), equals('ConfluenceConnectionException: Connection failed'));
      });

      test('getUserFriendlyMessage returns message with recovery action', () {
        final exception = ConfluenceConnectionException(
          'Connection failed',
          baseUrl: 'https://example.atlassian.net',
          recoveryAction: 'Check your internet connection',
        );

        final userMessage = exception.getUserFriendlyMessage();

        expect(userMessage, contains('Connection failed'));
        expect(userMessage, contains('Рекомендуемое действие: Check your internet connection'));
      });

      test('getUserFriendlyMessage returns only message when no recovery action', () {
        final exception = ConfluenceConnectionException(
          'Connection failed',
          baseUrl: 'https://example.atlassian.net',
        );

        final userMessage = exception.getUserFriendlyMessage();

        expect(userMessage, equals('Connection failed'));
        expect(userMessage, isNot(contains('Рекомендуемое действие')));
      });

      test('getTechnicalDetails returns technical details', () {
        final exception = ConfluenceConnectionException(
          'Connection failed',
          baseUrl: 'https://example.atlassian.net',
          technicalDetails: 'HTTP 500 Internal Server Error',
        );

        expect(exception.getTechnicalDetails(), equals('HTTP 500 Internal Server Error'));
      });
    });
  });

  group('ConfluenceConnectionException', () {
    test('creates instance with all fields', () {
      final exception = ConfluenceConnectionException(
        'Connection failed',
        baseUrl: 'https://example.atlassian.net',
        statusCode: 500,
        technicalDetails: 'Server error',
        recoveryAction: 'Try again later',
      );

      expect(exception.message, equals('Connection failed'));
      expect(exception.type, equals(ConfluenceErrorType.connection));
      expect(exception.baseUrl, equals('https://example.atlassian.net'));
      expect(exception.statusCode, equals(500));
      expect(exception.technicalDetails, equals('Server error'));
      expect(exception.recoveryAction, equals('Try again later'));
    });

    test('toString returns specific exception type', () {
      final exception = ConfluenceConnectionException('Connection failed');

      expect(exception.toString(), equals('ConfluenceConnectionException: Connection failed'));
    });
  });

  group('ConfluenceAuthenticationException', () {
    test('creates instance with token information', () {
      final exception = ConfluenceAuthenticationException(
        'Invalid token',
        token: 'masked-token',
        recoveryAction: 'Check your API token',
      );

      expect(exception.message, equals('Invalid token'));
      expect(exception.type, equals(ConfluenceErrorType.authentication));
      expect(exception.token, equals('masked-token'));
      expect(exception.recoveryAction, equals('Check your API token'));
    });
  });

  group('ConfluenceAuthorizationException', () {
    test('creates instance with permission information', () {
      final exception = ConfluenceAuthorizationException(
        'Insufficient permissions',
        requiredPermission: 'WRITE',
        pageId: '123456',
        recoveryAction: 'Contact administrator',
      );

      expect(exception.message, equals('Insufficient permissions'));
      expect(exception.type, equals(ConfluenceErrorType.authorization));
      expect(exception.requiredPermission, equals('WRITE'));
      expect(exception.pageId, equals('123456'));
    });
  });

  group('ConfluenceContentProcessingException', () {
    test('creates instance with content processing information', () {
      final exception = ConfluenceContentProcessingException(
        'Failed to process content',
        originalUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456',
        pageId: '123456',
        technicalDetails: 'HTML parsing error',
      );

      expect(exception.message, equals('Failed to process content'));
      expect(exception.type, equals(ConfluenceErrorType.contentProcessing));
      expect(exception.originalUrl, contains('123456'));
      expect(exception.pageId, equals('123456'));
    });
  });

  group('ConfluencePublishingException', () {
    test('creates instance with publishing information', () {
      final exception = ConfluencePublishingException(
        'Failed to publish page',
        pageId: '123456',
        parentPageId: '789012',
        operation: 'create',
        recoveryAction: 'Check permissions',
      );

      expect(exception.message, equals('Failed to publish page'));
      expect(exception.type, equals(ConfluenceErrorType.publishing));
      expect(exception.pageId, equals('123456'));
      expect(exception.parentPageId, equals('789012'));
      expect(exception.operation, equals('create'));
    });
  });

  group('ConfluenceRateLimitException', () {
    test('creates instance with rate limit information', () {
      final exception = ConfluenceRateLimitException(
        'Rate limit exceeded',
        retryAfterSeconds: 60,
        remainingRequests: 0,
        recoveryAction: 'Wait before retrying',
      );

      expect(exception.message, equals('Rate limit exceeded'));
      expect(exception.type, equals(ConfluenceErrorType.rateLimit));
      expect(exception.retryAfterSeconds, equals(60));
      expect(exception.remainingRequests, equals(0));
    });
  });

  group('ConfluenceValidationException', () {
    test('creates instance with validation information', () {
      final exception = ConfluenceValidationException(
        'Invalid URL format',
        fieldName: 'baseUrl',
        invalidValue: 'not-a-url',
        recoveryAction: 'Enter a valid URL',
      );

      expect(exception.message, equals('Invalid URL format'));
      expect(exception.type, equals(ConfluenceErrorType.validation));
      expect(exception.fieldName, equals('baseUrl'));
      expect(exception.invalidValue, equals('not-a-url'));
    });
  });

  group('ConfluenceNetworkException', () {
    test('creates instance with network information', () {
      final exception = ConfluenceNetworkException(
        'Network request failed',
        url: 'https://example.atlassian.net/wiki/rest/api/space',
        method: 'GET',
        statusCode: 404,
        technicalDetails: 'Not Found',
      );

      expect(exception.message, equals('Network request failed'));
      expect(exception.type, equals(ConfluenceErrorType.network));
      expect(exception.url, contains('space'));
      expect(exception.method, equals('GET'));
      expect(exception.statusCode, equals(404));
    });
  });

  group('ConfluenceParsingException', () {
    test('creates instance with parsing information', () {
      final exception = ConfluenceParsingException(
        'Failed to parse response',
        rawResponse: '{"invalid": json}',
        expectedFormat: 'Valid JSON',
        technicalDetails: 'JSON syntax error',
      );

      expect(exception.message, equals('Failed to parse response'));
      expect(exception.type, equals(ConfluenceErrorType.parsing));
      expect(exception.rawResponse, equals('{"invalid": json}'));
      expect(exception.expectedFormat, equals('Valid JSON'));
    });
  });

  group('ConfluenceExceptionFactory', () {
    group('connectionFailed', () {
      test('creates connection exception with recovery action', () {
        final exception = ConfluenceExceptionFactory.connectionFailed(
          baseUrl: 'https://example.atlassian.net',
          statusCode: 500,
          details: 'Server error',
        );

        expect(exception.message, contains('Failed to connect to Confluence'));
        expect(exception.baseUrl, equals('https://example.atlassian.net'));
        expect(exception.statusCode, equals(500));
        expect(exception.technicalDetails, equals('Server error'));
        expect(exception.recoveryAction, contains('Check your internet connection'));
      });
    });

    group('authenticationFailed', () {
      test('creates authentication exception with recovery action', () {
        final exception = ConfluenceExceptionFactory.authenticationFailed(
          details: 'Invalid token format',
        );

        expect(exception.message, contains('Authentication failed'));
        expect(exception.technicalDetails, equals('Invalid token format'));
        expect(exception.recoveryAction, contains('Verify your API token'));
      });
    });

    group('authorizationFailed', () {
      test('creates authorization exception with recovery action', () {
        final exception = ConfluenceExceptionFactory.authorizationFailed(
          operation: 'create page',
          pageId: '123456',
          details: 'Missing WRITE permission',
        );

        expect(exception.message, contains('Insufficient permissions to create page'));
        expect(exception.requiredPermission, equals('create page'));
        expect(exception.pageId, equals('123456'));
        expect(exception.technicalDetails, equals('Missing WRITE permission'));
        expect(exception.recoveryAction, contains('Contact your Confluence administrator'));
      });
    });

    group('rateLimitExceeded', () {
      test('creates rate limit exception with retry information', () {
        final exception = ConfluenceExceptionFactory.rateLimitExceeded(
          retryAfterSeconds: 120,
          details: 'Too many requests',
        );

        expect(exception.message, contains('API rate limit exceeded'));
        expect(exception.message, contains('Retry after 120 seconds'));
        expect(exception.retryAfterSeconds, equals(120));
        expect(exception.technicalDetails, equals('Too many requests'));
        expect(exception.recoveryAction, contains('Wait before making additional requests'));
      });

      test('creates rate limit exception without retry time', () {
        final exception = ConfluenceExceptionFactory.rateLimitExceeded(
          details: 'Too many requests',
        );

        expect(exception.message, equals('API rate limit exceeded.'));
        expect(exception.retryAfterSeconds, isNull);
      });
    });

    group('invalidUrl', () {
      test('creates validation exception for invalid URL', () {
        final exception = ConfluenceExceptionFactory.invalidUrl(
          url: 'not-a-valid-url',
          expectedFormat: 'https://domain.atlassian.net/wiki/...',
        );

        expect(exception.message, equals('Invalid Confluence URL format'));
        expect(exception.fieldName, equals('url'));
        expect(exception.invalidValue, equals('not-a-valid-url'));
        expect(exception.technicalDetails, contains('Expected format'));
        expect(exception.recoveryAction, contains('Ensure the URL follows the correct'));
      });
    });

    group('contentProcessingFailed', () {
      test('creates content processing exception with recovery action', () {
        final exception = ConfluenceExceptionFactory.contentProcessingFailed(
          url: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456',
          pageId: '123456',
          details: 'HTML parsing failed',
        );

        expect(exception.message, contains('Failed to process content'));
        expect(exception.originalUrl, contains('123456'));
        expect(exception.pageId, equals('123456'));
        expect(exception.technicalDetails, equals('HTML parsing failed'));
        expect(exception.recoveryAction, contains('Verify the page exists'));
      });
    });

    group('publishingFailed', () {
      test('creates publishing exception with recovery action', () {
        final exception = ConfluenceExceptionFactory.publishingFailed(
          operation: 'create page',
          pageId: '123456',
          details: 'Invalid parent page',
        );

        expect(exception.message, contains('Failed to create page'));
        expect(exception.operation, equals('create page'));
        expect(exception.pageId, equals('123456'));
        expect(exception.technicalDetails, equals('Invalid parent page'));
        expect(exception.recoveryAction, contains('Check your permissions'));
      });
    });
  });

  group('ConfluenceErrorType', () {
    test('has all expected error types', () {
      final errorTypes = ConfluenceErrorType.values;

      expect(errorTypes, contains(ConfluenceErrorType.connection));
      expect(errorTypes, contains(ConfluenceErrorType.authentication));
      expect(errorTypes, contains(ConfluenceErrorType.authorization));
      expect(errorTypes, contains(ConfluenceErrorType.contentProcessing));
      expect(errorTypes, contains(ConfluenceErrorType.publishing));
      expect(errorTypes, contains(ConfluenceErrorType.rateLimit));
      expect(errorTypes, contains(ConfluenceErrorType.validation));
      expect(errorTypes, contains(ConfluenceErrorType.network));
      expect(errorTypes, contains(ConfluenceErrorType.parsing));
    });
  });
}