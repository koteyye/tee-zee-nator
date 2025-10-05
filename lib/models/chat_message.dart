import 'package:json_annotation/json_annotation.dart';

part 'chat_message.g.dart';

@JsonSerializable()
class ChatMessage {
  final String role;
  final String content;
  final DateTime? timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);
  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);
}

@JsonSerializable()
class ChatRequest {
  final String model;
  final List<ChatMessage> messages;
  @JsonKey(name: 'max_tokens')
  final int? maxTokens;
  final double? temperature;
  
  ChatRequest({
    required this.model,
    required this.messages,
    this.maxTokens,
    this.temperature,
  });
  
  factory ChatRequest.fromJson(Map<String, dynamic> json) => _$ChatRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ChatRequestToJson(this);
}

@JsonSerializable()
class ChatChoice {
  final int index;
  final ChatMessage message;
  @JsonKey(name: 'finish_reason')
  final String? finishReason;
  
  ChatChoice({
    required this.index,
    required this.message,
    this.finishReason,
  });
  
  factory ChatChoice.fromJson(Map<String, dynamic> json) => _$ChatChoiceFromJson(json);
  Map<String, dynamic> toJson() => _$ChatChoiceToJson(this);
}

@JsonSerializable()
class ChatResponse {
  final String id;
  final String object;
  final int created;
  final String model;
  final List<ChatChoice> choices;
  
  ChatResponse({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
  });
  
  factory ChatResponse.fromJson(Map<String, dynamic> json) => _$ChatResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ChatResponseToJson(this);
}
