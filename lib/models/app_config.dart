import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'app_config.g.dart';

@HiveType(typeId: 0)
@JsonSerializable()
class AppConfig {
  @HiveField(0)
  final String apiUrl;
  
  @HiveField(1)
  final String apiToken;
  
  @HiveField(2)
  final String? selectedModel;
  
  AppConfig({
    required this.apiUrl,
    required this.apiToken,
    this.selectedModel,
  });
  
  factory AppConfig.fromJson(Map<String, dynamic> json) => _$AppConfigFromJson(json);
  Map<String, dynamic> toJson() => _$AppConfigToJson(this);
  
  AppConfig copyWith({
    String? apiUrl,
    String? apiToken,
    String? selectedModel,
  }) {
    return AppConfig(
      apiUrl: apiUrl ?? this.apiUrl,
      apiToken: apiToken ?? this.apiToken,
      selectedModel: selectedModel ?? this.selectedModel,
    );
  }
}
