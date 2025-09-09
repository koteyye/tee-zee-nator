import 'package:json_annotation/json_annotation.dart';

part 'agent_action.g.dart';

enum AgentActionType {
  @JsonValue('generate_content')
  generateContent,
  @JsonValue('validate_requirements')
  validateRequirements,
  @JsonValue('suggest_improvements')
  suggestImprovements,
  @JsonValue('create_structure')
  createStructure,
  @JsonValue('update_section')
  updateSection,
}

@JsonSerializable()
class AgentAction {
  final AgentActionType type;
  final String? section;
  final String? content;
  final List<String>? suggestions;
  final Map<String, dynamic>? metadata;
  @JsonKey(name: 'progress_message')
  final String? progressMessage;

  const AgentAction({
    required this.type,
    this.section,
    this.content,
    this.suggestions,
    this.metadata,
    this.progressMessage,
  });

  factory AgentAction.fromJson(Map<String, dynamic> json) =>
      _$AgentActionFromJson(json);

  Map<String, dynamic> toJson() => _$AgentActionToJson(this);
}