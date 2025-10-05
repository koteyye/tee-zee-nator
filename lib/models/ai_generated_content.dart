import 'package:json_annotation/json_annotation.dart';

part 'ai_generated_content.g.dart';

/// Статус сгенерированного AI контента
enum AIContentStatus {
  /// Ожидает подтверждения пользователя
  pending,

  /// Принято и применено
  accepted,

  /// Отклонено пользователем
  rejected,
}

/// Модель сгенерированного AI контента, ожидающего подтверждения
@JsonSerializable()
class AIGeneratedContent {
  /// Контент для записи в файл
  final String fileContent;

  /// Сообщение пользователю в чате
  final String userMessage;

  /// ID целевого файла для записи
  final String targetFileId;

  /// Дата генерации
  final DateTime generatedAt;

  /// Статус контента
  AIContentStatus status;

  AIGeneratedContent({
    required this.fileContent,
    required this.userMessage,
    required this.targetFileId,
    required this.generatedAt,
    this.status = AIContentStatus.pending,
  });

  /// Создание из JSON
  factory AIGeneratedContent.fromJson(Map<String, dynamic> json) =>
      _$AIGeneratedContentFromJson(json);

  /// Конвертация в JSON
  Map<String, dynamic> toJson() => _$AIGeneratedContentToJson(this);

  /// Является ли контент в ожидании
  bool get isPending => status == AIContentStatus.pending;

  /// Был ли контент принят
  bool get isAccepted => status == AIContentStatus.accepted;

  /// Был ли контент отклонен
  bool get isRejected => status == AIContentStatus.rejected;

  /// Принять контент
  void accept() {
    status = AIContentStatus.accepted;
  }

  /// Отклонить контент
  void reject() {
    status = AIContentStatus.rejected;
  }

  /// Копирование с изменениями
  AIGeneratedContent copyWith({
    String? fileContent,
    String? userMessage,
    String? targetFileId,
    DateTime? generatedAt,
    AIContentStatus? status,
  }) {
    return AIGeneratedContent(
      fileContent: fileContent ?? this.fileContent,
      userMessage: userMessage ?? this.userMessage,
      targetFileId: targetFileId ?? this.targetFileId,
      generatedAt: generatedAt ?? this.generatedAt,
      status: status ?? this.status,
    );
  }

  @override
  String toString() {
    return 'AIGeneratedContent(targetFileId: $targetFileId, status: $status, contentLength: ${fileContent.length})';
  }
}
