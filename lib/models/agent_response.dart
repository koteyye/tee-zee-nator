import 'package:json_annotation/json_annotation.dart';
import 'agent_action.dart';

part 'agent_response.g.dart';

@JsonSerializable()
class AgentResponse {
  @JsonKey(name: 'user_message')
  final String userMessage;
  
  final List<AgentAction>? actions;
  
  @JsonKey(name: 'template_update')
  final Map<String, String>? templateUpdate;
  
  @JsonKey(name: 'specification_sections')
  final Map<String, String>? specificationSections;

  const AgentResponse({
    required this.userMessage,
    this.actions,
    this.templateUpdate,
    this.specificationSections,
  });

  factory AgentResponse.fromJson(Map<String, dynamic> json) =>
      _$AgentResponseFromJson(json);

  Map<String, dynamic> toJson() => _$AgentResponseToJson(this);
}