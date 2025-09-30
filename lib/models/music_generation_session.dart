import 'package:json_annotation/json_annotation.dart';

part 'music_generation_session.g.dart';

enum MusicGenerationStatus {
  idle,
  starting,
  generating,
  downloading,
  completed,
  failed,
  cancelled,
  insufficientFunds,
}

@JsonSerializable()
class MusicGenerationSession {
  @JsonKey(name: 'session_id')
  final String sessionId;

  @JsonKey(name: 'requirements_hash')
  final String requirementsHash;

  @JsonKey(name: 'request_id')
  final String? requestId;

  final MusicGenerationStatus status;

  @JsonKey(name: 'file_path')
  final String? _filePath;

  @JsonKey(name: 'file_paths')
  final List<String>? filePaths;

  /// Возвращает путь к первому файлу (для обратной совместимости)
  String? get filePath {
    if (_filePath != null) return _filePath;
    if (filePaths != null && filePaths!.isNotEmpty) {
      return filePaths!.first;
    }
    return null;
  }

  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;

  @JsonKey(name: 'error_message')
  final String? errorMessage;

  @JsonKey(name: 'progress_message')
  final String? progressMessage;

  const MusicGenerationSession({
    required this.sessionId,
    required this.requirementsHash,
    this.requestId,
    this.status = MusicGenerationStatus.idle,
    String? filePath,
    this.filePaths,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
    this.progressMessage,
  }) : _filePath = filePath;

  factory MusicGenerationSession.fromJson(Map<String, dynamic> json) =>
      _$MusicGenerationSessionFromJson(json);

  Map<String, dynamic> toJson() => _$MusicGenerationSessionToJson(this);

  MusicGenerationSession copyWith({
    String? sessionId,
    String? requirementsHash,
    String? requestId,
    MusicGenerationStatus? status,
    String? filePath,
    List<String>? filePaths,
    DateTime? createdAt,
    DateTime? completedAt,
    String? errorMessage,
    String? progressMessage,
  }) {
    return MusicGenerationSession(
      sessionId: sessionId ?? this.sessionId,
      requirementsHash: requirementsHash ?? this.requirementsHash,
      requestId: requestId ?? this.requestId,
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      filePaths: filePaths ?? this.filePaths,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      progressMessage: progressMessage ?? this.progressMessage,
    );
  }
}