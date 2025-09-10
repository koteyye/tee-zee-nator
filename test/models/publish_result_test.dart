import 'package:flutter_test/flutter_test.dart';
import 'package:tee_zee_nator/models/publish_result.dart';

void main() {
  group('PublishResult', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final publishedAt = DateTime.now();
        final result = PublishResult(
          success: true,
          operation: PublishOperation.create,
          publishedAt: publishedAt,
        );

        expect(result.success, isTrue);
        expect(result.operation, equals(PublishOperation.create));
        expect(result.publishedAt, equals(publishedAt));
        expect(result.pageUrl, isNull);
        expect(result.pageId, isNull);
        expect(result.errorMessage, isNull);
        expect(result.title, isNull);
      });

      test('creates instance with all fields', () {
        final publishedAt = DateTime.now();
        final result = PublishResult(
          success: true,
          pageUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          operation: PublishOperation.update,
          publishedAt: publishedAt,
          title: 'Test Page',
        );

        expect(result.pageUrl, contains('123456'));
        expect(result.pageId, equals('123456'));
        expect(result.title, equals('Test Page'));
      });
    });

    group('factory constructors', () {
      test('success() creates successful publish result', () {
        final result = PublishResult.success(
          operation: PublishOperation.create,
          pageUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          title: 'Test Page',
        );

        expect(result.success, isTrue);
        expect(result.operation, equals(PublishOperation.create));
        expect(result.pageUrl, contains('123456'));
        expect(result.pageId, equals('123456'));
        expect(result.title, equals('Test Page'));
        expect(result.errorMessage, isNull);
        expect(result.publishedAt, isNotNull);
      });

      test('failure() creates failed publish result', () {
        final result = PublishResult.failure(
          operation: PublishOperation.update,
          errorMessage: 'Insufficient permissions',
        );

        expect(result.success, isFalse);
        expect(result.operation, equals(PublishOperation.update));
        expect(result.errorMessage, equals('Insufficient permissions'));
        expect(result.pageUrl, isNull);
        expect(result.pageId, isNull);
        expect(result.publishedAt, isNotNull);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = PublishResult(
          success: false,
          operation: PublishOperation.create,
          publishedAt: DateTime.now(),
          errorMessage: 'Original error',
        );

        final updated = original.copyWith(
          success: true,
          pageUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          errorMessage: null,
        );

        expect(updated.success, isTrue);
        expect(updated.pageUrl, contains('123456'));
        expect(updated.errorMessage, isNull);
        expect(updated.operation, equals(original.operation));
        expect(updated.publishedAt, equals(original.publishedAt));
      });
    });

    group('statusMessage', () {
      test('returns success message for create operation', () {
        final result = PublishResult.success(
          operation: PublishOperation.create,
          pageUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
        );

        expect(result.statusMessage, equals('Page successfully created'));
      });

      test('returns success message for update operation', () {
        final result = PublishResult.success(
          operation: PublishOperation.update,
          pageUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
        );

        expect(result.statusMessage, equals('Page successfully updated'));
      });

      test('returns error message for failed operation', () {
        final result = PublishResult.failure(
          operation: PublishOperation.create,
          errorMessage: 'Insufficient permissions',
        );

        expect(result.statusMessage, equals('Insufficient permissions'));
      });

      test('returns default error message when errorMessage is null', () {
        final result = PublishResult(
          success: false,
          operation: PublishOperation.create,
          publishedAt: DateTime.now(),
        );

        expect(result.statusMessage, equals('Publishing failed'));
      });
    });

    group('detailedMessage', () {
      test('returns detailed success message with title for create operation', () {
        final result = PublishResult.success(
          operation: PublishOperation.create,
          pageUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          title: 'Test Page',
        );

        expect(result.detailedMessage, 
               equals('Page "Test Page" successfully created at https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page'));
      });

      test('returns detailed success message without title for update operation', () {
        final result = PublishResult.success(
          operation: PublishOperation.update,
          pageUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
        );

        expect(result.detailedMessage, 
               equals('Page successfully updated at https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page'));
      });

      test('returns detailed error message for failed operation', () {
        final result = PublishResult.failure(
          operation: PublishOperation.create,
          errorMessage: 'Insufficient permissions',
        );

        expect(result.detailedMessage, equals('Failed to create page: Insufficient permissions'));
      });

      test('returns detailed error message with unknown error', () {
        final result = PublishResult(
          success: false,
          operation: PublishOperation.update,
          publishedAt: DateTime.now(),
        );

        expect(result.detailedMessage, equals('Failed to update page: Unknown error'));
      });
    });

    group('equality and hashCode', () {
      test('equal objects have same hashCode', () {
        final publishedAt = DateTime.now();
        final result1 = PublishResult(
          success: true,
          operation: PublishOperation.create,
          publishedAt: publishedAt,
          pageUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
        );

        final result2 = PublishResult(
          success: true,
          operation: PublishOperation.create,
          publishedAt: publishedAt,
          pageUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
        );

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('different objects are not equal', () {
        final result1 = PublishResult(
          success: true,
          operation: PublishOperation.create,
          publishedAt: DateTime.now(),
        );

        final result2 = PublishResult(
          success: false,
          operation: PublishOperation.create,
          publishedAt: DateTime.now(),
        );

        expect(result1, isNot(equals(result2)));
      });
    });

    group('JSON serialization', () {
      test('serializes to JSON correctly', () {
        final publishedAt = DateTime.now();
        final result = PublishResult(
          success: true,
          pageUrl: 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          pageId: '123456',
          operation: PublishOperation.create,
          publishedAt: publishedAt,
          title: 'Test Page',
        );

        final json = result.toJson();

        expect(json['success'], isTrue);
        expect(json['pageUrl'], contains('123456'));
        expect(json['pageId'], equals('123456'));
        expect(json['operation'], equals('create'));
        expect(json['title'], equals('Test Page'));
        expect(json['publishedAt'], isNotNull);
      });

      test('deserializes from JSON correctly', () {
        final json = {
          'success': true,
          'pageUrl': 'https://example.atlassian.net/wiki/spaces/TEST/pages/123456/Test+Page',
          'pageId': '123456',
          'errorMessage': null,
          'operation': 'create',
          'publishedAt': '2024-01-01T12:00:00.000Z',
          'title': 'Test Page',
        };

        final result = PublishResult.fromJson(json);

        expect(result.success, isTrue);
        expect(result.pageUrl, contains('123456'));
        expect(result.pageId, equals('123456'));
        expect(result.operation, equals(PublishOperation.create));
        expect(result.title, equals('Test Page'));
        expect(result.publishedAt, isNotNull);
      });
    });
  });

  group('PublishOperation', () {
    group('displayName', () {
      test('returns correct display name for create operation', () {
        expect(PublishOperation.create.displayName, equals('Create New Page'));
      });

      test('returns correct display name for update operation', () {
        expect(PublishOperation.update.displayName, equals('Update Existing Page'));
      });
    });

    group('verb', () {
      test('returns correct verb for create operation', () {
        expect(PublishOperation.create.verb, equals('creating'));
      });

      test('returns correct verb for update operation', () {
        expect(PublishOperation.update.verb, equals('updating'));
      });
    });

    group('JSON serialization', () {
      test('serializes create operation correctly', () {
        expect(PublishOperation.create.name, equals('create'));
      });

      test('serializes update operation correctly', () {
        expect(PublishOperation.update.name, equals('update'));
      });
    });
  });

  group('PublishProgress', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final progress = PublishProgress(
          step: 'validation',
          message: 'Validating page content',
          progress: 0.5,
        );

        expect(progress.step, equals('validation'));
        expect(progress.message, equals('Validating page content'));
        expect(progress.progress, equals(0.5));
        expect(progress.isComplete, isFalse); // Default value
        expect(progress.errorMessage, isNull);
      });
    });

    group('factory constructors', () {
      test('step() creates progress step', () {
        final progress = PublishProgress.step(
          step: 'validation',
          message: 'Validating page content',
          progress: 0.3,
        );

        expect(progress.step, equals('validation'));
        expect(progress.message, equals('Validating page content'));
        expect(progress.progress, equals(0.3));
        expect(progress.isComplete, isFalse);
        expect(progress.errorMessage, isNull);
      });

      test('complete() creates completion step', () {
        final progress = PublishProgress.complete(
          step: 'publishing',
          message: 'Page successfully published',
        );

        expect(progress.step, equals('publishing'));
        expect(progress.message, equals('Page successfully published'));
        expect(progress.progress, equals(1.0));
        expect(progress.isComplete, isTrue);
        expect(progress.errorMessage, isNull);
      });

      test('error() creates error step', () {
        final progress = PublishProgress.error(
          step: 'validation',
          message: 'Validation failed',
          errorMessage: 'Invalid page format',
        );

        expect(progress.step, equals('validation'));
        expect(progress.message, equals('Validation failed'));
        expect(progress.progress, equals(0.0));
        expect(progress.isComplete, isFalse);
        expect(progress.errorMessage, equals('Invalid page format'));
      });
    });

    group('equality and hashCode', () {
      test('equal objects have same hashCode', () {
        final progress1 = PublishProgress(
          step: 'validation',
          message: 'Validating page content',
          progress: 0.5,
        );

        final progress2 = PublishProgress(
          step: 'validation',
          message: 'Validating page content',
          progress: 0.5,
        );

        expect(progress1, equals(progress2));
        expect(progress1.hashCode, equals(progress2.hashCode));
      });

      test('different objects are not equal', () {
        final progress1 = PublishProgress(
          step: 'validation',
          message: 'Validating page content',
          progress: 0.5,
        );

        final progress2 = PublishProgress(
          step: 'publishing',
          message: 'Publishing page content',
          progress: 0.5,
        );

        expect(progress1, isNot(equals(progress2)));
      });
    });

    group('toString', () {
      test('includes key information in string representation', () {
        final progress = PublishProgress(
          step: 'validation',
          message: 'Validating page content',
          progress: 0.75,
          isComplete: false,
        );

        final stringRepresentation = progress.toString();

        expect(stringRepresentation, contains('validation'));
        expect(stringRepresentation, contains('Validating page content'));
        expect(stringRepresentation, contains('75.0%'));
        expect(stringRepresentation, contains('isComplete: false'));
      });
    });

    group('JSON serialization', () {
      test('serializes to JSON correctly', () {
        final progress = PublishProgress(
          step: 'validation',
          message: 'Validating page content',
          progress: 0.5,
          isComplete: false,
        );

        final json = progress.toJson();

        expect(json['step'], equals('validation'));
        expect(json['message'], equals('Validating page content'));
        expect(json['progress'], equals(0.5));
        expect(json['isComplete'], isFalse);
        expect(json['errorMessage'], isNull);
      });

      test('deserializes from JSON correctly', () {
        final json = {
          'step': 'validation',
          'message': 'Validating page content',
          'progress': 0.5,
          'isComplete': false,
          'errorMessage': null,
        };

        final progress = PublishProgress.fromJson(json);

        expect(progress.step, equals('validation'));
        expect(progress.message, equals('Validating page content'));
        expect(progress.progress, equals(0.5));
        expect(progress.isComplete, isFalse);
        expect(progress.errorMessage, isNull);
      });

      test('handles error message in JSON', () {
        final json = {
          'step': 'validation',
          'message': 'Validation failed',
          'progress': 0.0,
          'isComplete': false,
          'errorMessage': 'Invalid page format',
        };

        final progress = PublishProgress.fromJson(json);

        expect(progress.errorMessage, equals('Invalid page format'));
      });
    });
  });
}