import 'package:json_annotation/json_annotation.dart';

part 'openai_model.g.dart';

@JsonSerializable()
class OpenAIModel {
  final String id;
  final String object;
  final int created;
  @JsonKey(name: 'owned_by')
  final String ownedBy;
  
  OpenAIModel({
    required this.id,
    required this.object,
    required this.created,
    required this.ownedBy,
  });
  
  factory OpenAIModel.fromJson(Map<String, dynamic> json) => _$OpenAIModelFromJson(json);
  Map<String, dynamic> toJson() => _$OpenAIModelToJson(this);
}

@JsonSerializable()
class OpenAIModelsResponse {
  final String object;
  final List<OpenAIModel> data;
  
  OpenAIModelsResponse({
    required this.object,
    required this.data,
  });
  
  factory OpenAIModelsResponse.fromJson(Map<String, dynamic> json) => _$OpenAIModelsResponseFromJson(json);
  Map<String, dynamic> toJson() => _$OpenAIModelsResponseToJson(this);
}
