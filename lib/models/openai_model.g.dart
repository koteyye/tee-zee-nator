// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'openai_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OpenAIModel _$OpenAIModelFromJson(Map<String, dynamic> json) => OpenAIModel(
      id: json['id'] as String,
      object: json['object'] as String,
      created: (json['created'] as num).toInt(),
      ownedBy: json['owned_by'] as String,
    );

Map<String, dynamic> _$OpenAIModelToJson(OpenAIModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'object': instance.object,
      'created': instance.created,
      'owned_by': instance.ownedBy,
    };

OpenAIModelsResponse _$OpenAIModelsResponseFromJson(
        Map<String, dynamic> json) =>
    OpenAIModelsResponse(
      object: json['object'] as String,
      data: (json['data'] as List<dynamic>)
          .map((e) => OpenAIModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$OpenAIModelsResponseToJson(
        OpenAIModelsResponse instance) =>
    <String, dynamic>{
      'object': instance.object,
      'data': instance.data,
    };
