import 'package:json_annotation/json_annotation.dart';

part 'technical_specification.g.dart';

enum SpecStatus {
  @JsonValue('draft')
  draft,
  @JsonValue('generating')
  generating,
  @JsonValue('review')
  review,
  @JsonValue('completed')
  completed,
}

@JsonSerializable()
class SpecMetadata {
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;
  
  final String version;
  final SpecStatus status;
  @JsonKey(name: 'progress_percentage')
  final double progressPercentage;

  const SpecMetadata({
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.status,
    this.progressPercentage = 0.0,
  });

  factory SpecMetadata.fromJson(Map<String, dynamic> json) =>
      _$SpecMetadataFromJson(json);

  Map<String, dynamic> toJson() => _$SpecMetadataToJson(this);

  SpecMetadata copyWith({
    DateTime? createdAt,
    DateTime? updatedAt,
    String? version,
    SpecStatus? status,
    double? progressPercentage,
  }) {
    return SpecMetadata(
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      status: status ?? this.status,
      progressPercentage: progressPercentage ?? this.progressPercentage,
    );
  }
}

@JsonSerializable()
class TechnicalSpecification {
  final String title;
  final Map<String, String> sections;
  final SpecMetadata metadata;
  @JsonKey(name: 'generation_steps')
  final List<String> generationSteps;

  const TechnicalSpecification({
    required this.title,
    required this.sections,
    required this.metadata,
    this.generationSteps = const [],
  });

  factory TechnicalSpecification.fromJson(Map<String, dynamic> json) =>
      _$TechnicalSpecificationFromJson(json);

  Map<String, dynamic> toJson() => _$TechnicalSpecificationToJson(this);

  TechnicalSpecification copyWith({
    String? title,
    Map<String, String>? sections,
    SpecMetadata? metadata,
    List<String>? generationSteps,
  }) {
    return TechnicalSpecification(
      title: title ?? this.title,
      sections: sections ?? Map<String, String>.from(this.sections),
      metadata: metadata ?? this.metadata,
      generationSteps: generationSteps ?? List<String>.from(this.generationSteps),
    );
  }

  factory TechnicalSpecification.empty() {
    final now = DateTime.now();
    return TechnicalSpecification(
      title: 'Новое техническое задание',
      sections: {},
      metadata: SpecMetadata(
        createdAt: now,
        updatedAt: now,
        version: '1.0.0',
        status: SpecStatus.draft,
        progressPercentage: 0.0,
      ),
      generationSteps: [],
    );
  }
}