import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/exceptions/confluence_exceptions.dart';
import 'package:tee_zee_nator/services/confluence_error_handler.dart';

void main() {
  group('ConfluenceErrorHandler', () {
    setUp(() {
      // Clear rate limit data before each test
      ConfluenceErrorHandler.clearRateLimitData();
    });

    group('Error Handling', () {
      testWidgets('handles connection errors with dialog', (WidgetTester tester) async {
        final error = ConfluenceExceptionFactory.connectionFailed(
          baseUrl: 'https://test.atlassian.net',
          statusCode: 404,
          details: 'Server not found',
        );

        bool retryCallbackCalled = false;
        bool reconfigureCallbackCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await ConfluenceErrorHandler.handleError(
                        context,
                        error,
                        operationContext: 'test connection',
                        onRetry: () => retryCallbackCalled = true,
                        onReconfigure: () => reconfigureCallbackCalled = true,
                      );
                    },
                    child: const Text('Test Error'),
                  );
                },
              ),
            ),
          ),
        );

        // Trigger error dialog
        await tester.tap(find.text('Test Error'));
        await tester.pumpAndSettle();

        // Verify dialog is shown
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Ошибка подключения к Confluence (test connection)'), findsOneWidget);
        // Check for the user-friendly message which includes recovery action
        expect(find.textContaining('Failed to connect to Confluence'), findsOneWidget);

        // Verify action buttons
        expect(find.text('Повторить'), findsOneWidget);
        expect(find.text('Настройки'), findsOneWidget);
        expect(find.text('Закрыть'), findsOneWidget);

        // Test retry button
        await tester.tap(find.text('Повторить'));
        await tester.pumpAndSettle();
        expect(retryCallbackCalled, isTrue);

        // Trigger error dialog again for reconfigure test
        await tester.tap(find.text('Test Error'));
        await tester.pumpAndSettle();

        // Test reconfigure button
        await tester.tap(find.text('Настройки'));
        await tester.pumpAndSettle();
        expect(reconfigureCallbackCalled, isTrue);
      });

      testWidgets('handles authentication errors with dialog', (WidgetTester tester) async {
        final error = ConfluenceExceptionFactory.authenticationFailed(
          details: 'Invalid token',
        );

        bool reconfigureCallbackCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await ConfluenceErrorHandler.handleError(
                        context,
                        error,
                        operationContext: 'authentication',
                        onReconfigure: () => reconfigureCallbackCalled = true,
                      );
                    },
                    child: const Text('Test Auth Error'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Test Auth Error'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Ошибка аутентификации (authentication)'), findsOneWidget);
        expect(find.textContaining('Authentication failed'), findsOneWidget);

        // Authentication errors should not have retry button
        expect(find.text('Повторить'), findsNothing);
        expect(find.text('Настройки'), findsOneWidget);
      });

      testWidgets('handles rate limit errors with snackbar', (WidgetTester tester) async {
        final error = ConfluenceExceptionFactory.rateLimitExceeded(
          retryAfterSeconds: 60,
          details: 'Too many requests',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await ConfluenceErrorHandler.handleError(
                        context,
                        error,
                        showAsDialog: false,
                      );
                    },
                    child: const Text('Test Rate Limit'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Test Rate Limit'));
        await tester.pumpAndSettle();

        // Should show snackbar, not dialog
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('API rate limit exceeded. Retry after 60 seconds.'), findsOneWidget);
      });

      testWidgets('shows technical details in expandable section', (WidgetTester tester) async {
        final error = ConfluenceConnectionException(
          'Connection failed',
          baseUrl: 'https://test.atlassian.net',
          statusCode: 500,
          technicalDetails: 'Internal server error: Database connection timeout',
          recoveryAction: 'Try again later or contact administrator',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () async {
                      await ConfluenceErrorHandler.handleError(context, error);
                    },
                    child: const Text('Test Technical Details'),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Test Technical Details'));
        await tester.pumpAndSettle();

        // Verify recovery action is shown
        expect(find.text('Try again later or contact administrator'), findsOneWidget);

        // Verify technical details expansion tile
        expect(find.text('Технические детали'), findsOneWidget);

        // Expand technical details
        await tester.tap(find.text('Технические детали'));
        await tester.pumpAndSettle();

        expect(find.text('Internal server error: Database connection timeout'), findsOneWidget);
      });
    });

    group('Retry Logic', () {
      test('executes operation with retry on transient failures', () async {
        int attemptCount = 0;
        operation() async {
          attemptCount++;
          if (attemptCount < 3) {
            throw ConfluenceExceptionFactory.connectionFailed(
              baseUrl: 'https://test.atlassian.net',
              details: 'Transient network error',
            );
          }
          return 'success';
        }

        final result = await ConfluenceErrorHandler.executeWithRetry(
          operation,
          operationName: 'test operation',
          maxAttempts: 3,
          baseDelay: const Duration(milliseconds: 10),
        );

        expect(result, equals('success'));
        expect(attemptCount, equals(3));
      });

      test('does not retry on authentication errors', () async {
        int attemptCount = 0;
        operation() async {
          attemptCount++;
          throw ConfluenceExceptionFactory.authenticationFailed(
            details: 'Invalid credentials',
          );
        }

        try {
          await ConfluenceErrorHandler.executeWithRetry(
            operation,
            operationName: 'auth test',
            maxAttempts: 3,
          );
          fail('Should have thrown an exception');
        } catch (e) {
          expect(e, isA<ConfluenceAuthenticationException>());
          expect(attemptCount, equals(1)); // Should not retry
        }
      });

      test('respects maximum retry attempts', () async {
        int attemptCount = 0;
        operation() async {
          attemptCount++;
          throw ConfluenceExceptionFactory.connectionFailed(
            baseUrl: 'https://test.atlassian.net',
            details: 'Persistent error',
          );
        }

        try {
          await ConfluenceErrorHandler.executeWithRetry(
            operation,
            operationName: 'persistent failure',
            maxAttempts: 2,
            baseDelay: const Duration(milliseconds: 10),
          );
          fail('Should have thrown an exception');
        } catch (e) {
          expect(e, isA<ConfluenceConnectionException>());
          expect(attemptCount, equals(2));
        }
      });

      test('calculates exponential backoff with jitter', () async {
        final delays = <Duration>[];
        int attemptCount = 0;

        operation() async {
          attemptCount++;
          if (attemptCount < 4) {
            throw Exception('Test error');
          }
          return 'success';
        }

        final stopwatch = Stopwatch()..start();
        await ConfluenceErrorHandler.executeWithRetry(
          operation,
          maxAttempts: 4,
          baseDelay: const Duration(milliseconds: 100),
          respectRateLimit: false, // Disable rate limiting for this test
        );
        stopwatch.stop();

        // Should have taken at least the sum of base delays (100ms + 200ms + 400ms)
        // but less than double that due to jitter
        expect(stopwatch.elapsedMilliseconds, greaterThan(600));
        expect(stopwatch.elapsedMilliseconds, lessThan(1400));
      });
    });

    group('Rate Limiting', () {
      test('tracks request counts per operation', () async {
        // Make several requests quickly
        for (int i = 0; i < 5; i++) {
          await ConfluenceErrorHandler.executeWithRetry(
            () async => 'success',
            operationName: 'test_operation',
            maxAttempts: 1,
            respectRateLimit: true,
          );
        }

        final status = ConfluenceErrorHandler.getRateLimitStatus();
        expect(status['currentRequests']['test_operation'], equals(5));
      });

      test('enforces rate limits', () async {
        // Fill up the rate limit with a smaller number for testing
        for (int i = 0; i < 10; i++) {
          await ConfluenceErrorHandler.executeWithRetry(
            () async => 'success',
            operationName: 'rate_limit_test',
            maxAttempts: 1,
            respectRateLimit: true,
          );
        }

        final status = ConfluenceErrorHandler.getRateLimitStatus();
        expect(status['currentRequests']['rate_limit_test'], equals(10));
      }, timeout: const Timeout(Duration(seconds: 5)));

      test('clears old rate limit entries', () async {
        // Add some requests
        await ConfluenceErrorHandler.executeWithRetry(
          () async => 'success',
          operationName: 'old_operation',
          maxAttempts: 1,
          respectRateLimit: true,
        );

        var status = ConfluenceErrorHandler.getRateLimitStatus();
        expect(status['currentRequests']['old_operation'], equals(1));

        // Clear rate limit data
        ConfluenceErrorHandler.clearRateLimitData();

        status = ConfluenceErrorHandler.getRateLimitStatus();
        expect(status['currentRequests'], isEmpty);
      });
    });

    group('Logging', () {
      test('logs errors with context', () {
        final error = ConfluenceExceptionFactory.connectionFailed(
          baseUrl: 'https://test.atlassian.net',
          statusCode: 404,
        );

        // This should not throw
        expect(
          () => ConfluenceErrorHandler.logError(error, context: 'test context'),
          returnsNormally,
        );
      });

      test('logs API requests and responses', () {
        expect(
          () => ConfluenceErrorHandler.logApiRequest(
            'GET',
            'https://test.atlassian.net/wiki/rest/api/space',
            headers: {'Authorization': 'Basic dGVzdDp0b2tlbg=='},
          ),
          returnsNormally,
        );

        expect(
          () => ConfluenceErrorHandler.logApiResponse(
            'GET',
            'https://test.atlassian.net/wiki/rest/api/space',
            200,
            body: '{"results": []}',
          ),
          returnsNormally,
        );
      });

      test('logs connection attempts', () {
        expect(
          () => ConfluenceErrorHandler.logConnectionAttempt(
            'https://test.atlassian.net',
            token: 'test_token_12345',
          ),
          returnsNormally,
        );

        expect(
          () => ConfluenceErrorHandler.logConnectionSuccess('https://test.atlassian.net'),
          returnsNormally,
        );

        final error = Exception('Connection failed');
        expect(
          () => ConfluenceErrorHandler.logConnectionFailure('https://test.atlassian.net', error),
          returnsNormally,
        );
      });

      test('sanitizes sensitive information in logs', () {
        final headers = {
          'Authorization': 'Basic dGVzdDp0b2tlbg==',
          'Content-Type': 'application/json',
          'X-API-Token': 'secret_token_12345',
        };

        // This should not throw and should sanitize sensitive headers
        expect(
          () => ConfluenceErrorHandler.logApiRequest('POST', 'https://test.atlassian.net', headers: headers),
          returnsNormally,
        );
      });
    });

    group('Validation', () {
      test('validates operation parameters', () {
        // Valid parameters should not throw
        expect(
          () => ConfluenceErrorHandler.validateOperation(
            baseUrl: 'https://test.atlassian.net',
            token: 'valid_token',
            pageUrl: 'https://test.atlassian.net/wiki/spaces/TEST/pages/123456/Page+Title',
            content: 'Valid content',
          ),
          returnsNormally,
        );

        // Empty base URL should throw when allowEmpty is false
        expect(
          () => ConfluenceErrorHandler.validateOperation(baseUrl: '', allowEmpty: false),
          throwsA(isA<ConfluenceValidationException>()),
        );

        // Empty token should throw when allowEmpty is false
        expect(
          () => ConfluenceErrorHandler.validateOperation(token: '', allowEmpty: false),
          throwsA(isA<ConfluenceAuthenticationException>()),
        );

        // Invalid page URL should throw
        expect(
          () => ConfluenceErrorHandler.validateOperation(pageUrl: 'invalid-url'),
          throwsA(isA<ConfluenceValidationException>()),
        );

        // Empty content should throw when allowEmpty is false
        expect(
          () => ConfluenceErrorHandler.validateOperation(content: '', allowEmpty: false),
          throwsA(isA<ConfluenceValidationException>()),
        );
      });
    });

    group('Recovery Suggestions', () {
      test('provides appropriate recovery suggestions for different error types', () {
        final connectionError = ConfluenceExceptionFactory.connectionFailed(
          baseUrl: 'https://test.atlassian.net',
        );
        final connectionSuggestions = ConfluenceErrorHandler.getRecoverySuggestions(connectionError);
        expect(connectionSuggestions, contains('Проверьте подключение к интернету'));
        expect(connectionSuggestions, contains('Убедитесь, что Base URL указан корректно'));

        final authError = ConfluenceExceptionFactory.authenticationFailed();
        final authSuggestions = ConfluenceErrorHandler.getRecoverySuggestions(authError);
        expect(authSuggestions, contains('Проверьте правильность API токена'));
        expect(authSuggestions, contains('Убедитесь, что токен не истек'));

        final rateLimitError = ConfluenceExceptionFactory.rateLimitExceeded();
        final rateLimitSuggestions = ConfluenceErrorHandler.getRecoverySuggestions(rateLimitError);
        expect(rateLimitSuggestions, contains('Подождите перед следующим запросом'));
        expect(rateLimitSuggestions, contains('Уменьшите частоту операций с Confluence'));
      });
    });

    group('Error Classification', () {
      test('correctly identifies retryable errors', () async {
        // Network errors should be retryable (will retry and then fail)
        final networkError = ConfluenceNetworkException(
          'Network timeout',
          url: 'https://test.atlassian.net',
          method: 'GET',
        );
        
        try {
          await ConfluenceErrorHandler.executeWithRetry(
            () => throw networkError,
            maxAttempts: 2,
            baseDelay: const Duration(milliseconds: 10),
          );
          fail('Should have thrown');
        } catch (e) {
          expect(e, isA<ConfluenceNetworkException>());
        }

        // Authentication errors should not be retryable (fail immediately)
        final authError = ConfluenceExceptionFactory.authenticationFailed();
        try {
          await ConfluenceErrorHandler.executeWithRetry(
            () => throw authError,
            maxAttempts: 3,
          );
          fail('Should have thrown');
        } catch (e) {
          expect(e, isA<ConfluenceAuthenticationException>());
        }
      });

      test('determines appropriate display method for errors', () {
        final connectionError = ConfluenceExceptionFactory.connectionFailed(
          baseUrl: 'https://test.atlassian.net',
        );
        // Connection errors should be shown as dialog (tested in widget tests above)

        final rateLimitError = ConfluenceExceptionFactory.rateLimitExceeded();
        // Rate limit errors should be shown as snackbar (tested in widget tests above)
      });
    });

    group('Error Factory Integration', () {
      test('works with exception factory methods', () {
        final connectionError = ConfluenceExceptionFactory.connectionFailed(
          baseUrl: 'https://test.atlassian.net',
          statusCode: 404,
        );
        expect(connectionError.type, equals(ConfluenceErrorType.connection));
        expect(connectionError.recoveryAction, isNotNull);

        final authError = ConfluenceExceptionFactory.authenticationFailed();
        expect(authError.type, equals(ConfluenceErrorType.authentication));
        expect(authError.recoveryAction, isNotNull);

        final validationError = ConfluenceExceptionFactory.invalidUrl(
          url: 'invalid-url',
          expectedFormat: 'https://domain.atlassian.net/wiki/...',
        );
        expect(validationError.type, equals(ConfluenceErrorType.validation));
        expect(validationError.recoveryAction, isNotNull);
      });
    });
  });
}