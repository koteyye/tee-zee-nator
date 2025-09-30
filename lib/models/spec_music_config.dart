import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'spec_music_config.g.dart';

@HiveType(typeId: 2)
@JsonSerializable()
class SpecMusicConfig extends HiveObject {
  @HiveField(0)
  final bool enabled;

  @HiveField(1)
  @JsonKey(name: 'api_key')
  final String? apiKey;

  @HiveField(2)
  @JsonKey(name: 'last_validated')
  final DateTime? lastValidated;

  @HiveField(3)
  @JsonKey(name: 'is_valid')
  final bool isValid;

  @HiveField(4)
  @JsonKey(name: 'last_error')
  final String? lastError;

  @HiveField(5)
  @JsonKey(name: 'use_mock')
  final bool useMock;

  SpecMusicConfig({
    this.enabled = false,
    this.apiKey,
    this.lastValidated,
    this.isValid = false,
    this.lastError,
    this.useMock = false,
  });

  factory SpecMusicConfig.fromJson(Map<String, dynamic> json) =>
      _$SpecMusicConfigFromJson(json);

  Map<String, dynamic> toJson() => _$SpecMusicConfigToJson(this);

  SpecMusicConfig copyWith({
    bool? enabled,
    String? apiKey,
    DateTime? lastValidated,
    bool? isValid,
    String? lastError,
    bool? useMock,
  }) {
    return SpecMusicConfig(
      enabled: enabled ?? this.enabled,
      apiKey: apiKey ?? this.apiKey,
      lastValidated: lastValidated ?? this.lastValidated,
      isValid: isValid ?? this.isValid,
      lastError: lastError ?? this.lastError,
      useMock: useMock ?? this.useMock,
    );
  }
}