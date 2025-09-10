import 'package:json_annotation/json_annotation.dart';

part 'publish_result.g.dart';

const _undefined = Object();

@JsonSerializable()
class PublishResult {
  final bool success;
  final String? pageUrl;
  final String? pageId;
  final String? errorMessage;
  final PublishOperation operation;
  final DateTime publishedAt;
  final String? title;

  const PublishResult({
    required this.success,
    this.pageUrl,
    this.pageId,
    this.errorMessage,
    required this.operation,
    required this.publishedAt,
    this.title,
  });

  factory PublishResult.fromJson(Map<String, dynamic> json) => 
      _$PublishResultFromJson(json);
  
  Map<String, dynamic> toJson() => _$PublishResultToJson(this);

  /// Creates a successful publish result
  factory PublishResult.success({
    required PublishOperation operation,
    required String pageUrl,
    required String pageId,
    String? title,
  }) {
    return PublishResult(
      success: true,
      pageUrl: pageUrl,
      pageId: pageId,
      operation: operation,
      publishedAt: DateTime.now(),
      title: title,
    );
  }

  /// Creates a failed publish result
  factory PublishResult.failure({
    required PublishOperation operation,
    required String errorMessage,
  }) {
    return PublishResult(
      success: false,
      errorMessage: errorMessage,
      operation: operation,
      publishedAt: DateTime.now(),
    );
  }

  /// Creates a copy with updated fields
  PublishResult copyWith({
    bool? success,
    String? pageUrl,
    String? pageId,
    Object? errorMessage = _undefined,
    PublishOperation? operation,
    DateTime? publishedAt,
    Object? title = _undefined,
  }) {
    return PublishResult(
      success: success ?? this.success,
      pageUrl: pageUrl ?? this.pageUrl,
      pageId: pageId ?? this.pageId,
      errorMessage: errorMessage == _undefined ? this.errorMessage : errorMessage as String?,
      operation: operation ?? this.operation,
      publishedAt: publishedAt ?? this.publishedAt,
      title: title == _undefined ? this.title : title as String?,
    );
  }

  /// Returns a user-friendly status message
  String get statusMessage {
    if (success) {
      switch (operation) {
        case PublishOperation.create:
          return 'Page successfully created';
        case PublishOperation.update:
          return 'Page successfully updated';
      }
    } else {
      return errorMessage ?? 'Publishing failed';
    }
  }

  /// Returns a detailed result message
  String get detailedMessage {
    if (success) {
      final operationText = operation == PublishOperation.create ? 'created' : 'updated';
      final titleText = title != null ? ' "$title"' : '';
      return 'Page$titleText successfully $operationText at $pageUrl';
    } else {
      return 'Failed to ${operation.name} page: ${errorMessage ?? 'Unknown error'}';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PublishResult &&
        other.success == success &&
        other.pageUrl == pageUrl &&
        other.pageId == pageId &&
        other.errorMessage == errorMessage &&
        other.operation == operation &&
        other.publishedAt == publishedAt &&
        other.title == title;
  }

  @override
  int get hashCode {
    return Object.hash(
      success,
      pageUrl,
      pageId,
      errorMessage,
      operation,
      publishedAt,
      title,
    );
  }

  @override
  String toString() {
    return 'PublishResult(success: $success, operation: ${operation.name}, '
           'pageUrl: $pageUrl, publishedAt: $publishedAt)';
  }
}

@JsonEnum()
enum PublishOperation {
  @JsonValue('create')
  create,
  
  @JsonValue('update')
  update;

  /// Returns a human-readable name for the operation
  String get displayName {
    switch (this) {
      case PublishOperation.create:
        return 'Create New Page';
      case PublishOperation.update:
        return 'Update Existing Page';
    }
  }

  /// Returns a verb form of the operation
  String get verb {
    switch (this) {
      case PublishOperation.create:
        return 'creating';
      case PublishOperation.update:
        return 'updating';
    }
  }
}

@JsonSerializable()
class PublishProgress {
  final String step;
  final String message;
  final double progress; // 0.0 to 1.0
  final bool isComplete;
  final String? errorMessage;

  const PublishProgress({
    required this.step,
    required this.message,
    required this.progress,
    this.isComplete = false,
    this.errorMessage,
  });

  factory PublishProgress.fromJson(Map<String, dynamic> json) => 
      _$PublishProgressFromJson(json);
  
  Map<String, dynamic> toJson() => _$PublishProgressToJson(this);

  /// Creates a progress step
  factory PublishProgress.step({
    required String step,
    required String message,
    required double progress,
  }) {
    return PublishProgress(
      step: step,
      message: message,
      progress: progress,
    );
  }

  /// Creates a completion step
  factory PublishProgress.complete({
    required String step,
    required String message,
  }) {
    return PublishProgress(
      step: step,
      message: message,
      progress: 1.0,
      isComplete: true,
    );
  }

  /// Creates an error step
  factory PublishProgress.error({
    required String step,
    required String message,
    required String errorMessage,
  }) {
    return PublishProgress(
      step: step,
      message: message,
      progress: 0.0,
      errorMessage: errorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PublishProgress &&
        other.step == step &&
        other.message == message &&
        other.progress == progress &&
        other.isComplete == isComplete &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return Object.hash(
      step,
      message,
      progress,
      isComplete,
      errorMessage,
    );
  }

  @override
  String toString() {
    return 'PublishProgress(step: $step, message: $message, '
           'progress: ${(progress * 100).toStringAsFixed(1)}%, '
           'isComplete: $isComplete)';
  }
}