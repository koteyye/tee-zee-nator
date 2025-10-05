import 'package:json_annotation/json_annotation.dart';
import 'chat_message.dart';
import 'ai_generated_content.dart';

part 'chat_session.g.dart';

/// Режим работы AI чата
enum ChatMode {
  /// Создание нового технического задания
  newSpecification,

  /// Дополнения к существующему ТЗ
  amendments,

  /// Анализ существующего ТЗ
  analysis,
}

/// Модель сессии чата с AI
@JsonSerializable(explicitToJson: true)
class AIChatSession {
  /// Уникальный идентификатор сессии
  final String id;

  /// Режим работы чата
  final ChatMode mode;

  /// История сообщений
  final List<ChatMessage> messages;

  /// Дата создания сессии
  final DateTime createdAt;

  /// ID файла для контекста (опционально)
  String? contextFileId;

  /// Контент, ожидающий подтверждения (не сериализуется)
  @JsonKey(includeFromJson: false, includeToJson: false)
  AIGeneratedContent? pendingContent;

  AIChatSession({
    required this.id,
    required this.mode,
    required this.messages,
    required this.createdAt,
    this.contextFileId,
    this.pendingContent,
  });

  /// Создание из JSON
  factory AIChatSession.fromJson(Map<String, dynamic> json) =>
      _$AIChatSessionFromJson(json);

  /// Конвертация в JSON
  Map<String, dynamic> toJson() => _$AIChatSessionToJson(this);

  /// Добавить сообщение в историю
  void addMessage(ChatMessage message) {
    messages.add(message);
  }

  /// Добавить сообщение пользователя
  void addUserMessage(String content) {
    messages.add(ChatMessage(role: 'user', content: content));
  }

  /// Добавить сообщение ассистента
  void addAssistantMessage(String content) {
    messages.add(ChatMessage(role: 'assistant', content: content));
  }

  /// Очистить pending контент
  void clearPendingContent() {
    pendingContent = null;
  }

  /// Установить pending контент
  void setPendingContent(AIGeneratedContent content) {
    pendingContent = content;
  }

  /// Есть ли pending контент
  bool get hasPendingContent => pendingContent != null;

  /// Получить последнее сообщение
  ChatMessage? get lastMessage =>
      messages.isNotEmpty ? messages.last : null;

  /// Копирование с изменениями
  AIChatSession copyWith({
    String? id,
    ChatMode? mode,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    String? contextFileId,
    AIGeneratedContent? pendingContent,
  }) {
    return AIChatSession(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      contextFileId: contextFileId ?? this.contextFileId,
      pendingContent: pendingContent ?? this.pendingContent,
    );
  }

  @override
  String toString() {
    return 'AIChatSession(id: $id, mode: $mode, messages: ${messages.length}, hasPending: $hasPendingContent)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AIChatSession && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
