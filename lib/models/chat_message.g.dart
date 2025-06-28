// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatMessage _$ChatMessageFromJson(Map<String, dynamic> json) => ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
    );

Map<String, dynamic> _$ChatMessageToJson(ChatMessage instance) =>
    <String, dynamic>{
      'role': instance.role,
      'content': instance.content,
    };

ChatRequest _$ChatRequestFromJson(Map<String, dynamic> json) => ChatRequest(
      model: json['model'] as String,
      messages: (json['messages'] as List<dynamic>)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
      maxTokens: (json['max_tokens'] as num?)?.toInt(),
      temperature: (json['temperature'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$ChatRequestToJson(ChatRequest instance) =>
    <String, dynamic>{
      'model': instance.model,
      'messages': instance.messages,
      'max_tokens': instance.maxTokens,
      'temperature': instance.temperature,
    };

ChatChoice _$ChatChoiceFromJson(Map<String, dynamic> json) => ChatChoice(
      index: (json['index'] as num).toInt(),
      message: ChatMessage.fromJson(json['message'] as Map<String, dynamic>),
      finishReason: json['finish_reason'] as String?,
    );

Map<String, dynamic> _$ChatChoiceToJson(ChatChoice instance) =>
    <String, dynamic>{
      'index': instance.index,
      'message': instance.message,
      'finish_reason': instance.finishReason,
    };

ChatResponse _$ChatResponseFromJson(Map<String, dynamic> json) => ChatResponse(
      id: json['id'] as String,
      object: json['object'] as String,
      created: (json['created'] as num).toInt(),
      model: json['model'] as String,
      choices: (json['choices'] as List<dynamic>)
          .map((e) => ChatChoice.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ChatResponseToJson(ChatResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'object': instance.object,
      'created': instance.created,
      'model': instance.model,
      'choices': instance.choices,
    };
