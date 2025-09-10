import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'output_format.dart';
import 'confluence_config.dart';

part 'app_config.g.dart';

@HiveType(typeId: 10) // Полностью новый typeId для избежания конфликтов с legacy адаптерами
@JsonSerializable()
class AppConfig {
  @HiveField(0)
  final String apiUrl;
  
  @HiveField(1)
  final String apiToken;
  
  @HiveField(2)
  final String? defaultModel; // Переименовали selectedModel в defaultModel
  
  @HiveField(3)
  final String? reviewModel; // Модель для ревью шаблонов
  
  @HiveField(4)
  final String? selectedTemplateId; // ID активного шаблона
  
  @HiveField(5)
  final String provider; // Провайдер LLM: 'openai' или 'llmops'
  
  @HiveField(6)
  final String? llmopsBaseUrl; // Base URL для LLMOps
  
  @HiveField(7)
  final String? llmopsModel; // Модель для LLMOps
  
  @HiveField(8)
  final String? llmopsAuthHeader; // Authorization header для LLMOps
  
  @HiveField(9)
  final OutputFormat outputFormat; // Предпочитаемый формат вывода
  
  @HiveField(10)
  @JsonKey(toJson: _confluenceConfigToJson, fromJson: _confluenceConfigFromJson)
  final ConfluenceConfig? confluenceConfig; // Конфигурация Confluence
  
  @HiveField(11)
  final String? cerebrasToken; // API токен для Cerebras AI
  
  @HiveField(12)
  final String? groqToken; // API токен для Groq

  AppConfig({
    required this.apiUrl,
    required this.apiToken,
    this.defaultModel,
    this.reviewModel,
    this.selectedTemplateId,
    this.provider = 'openai', // По умолчанию OpenAI
    this.llmopsBaseUrl,
    this.llmopsModel,
    this.llmopsAuthHeader,
    this.outputFormat = OutputFormat.markdown, // По умолчанию Markdown
    this.confluenceConfig,
    this.cerebrasToken,
    this.groqToken,
  });
  
  factory AppConfig.fromJson(Map<String, dynamic> json) => _$AppConfigFromJson(json);
  Map<String, dynamic> toJson() => _$AppConfigToJson(this);
  
  // Кастомный fromMap для обработки старых данных
  factory AppConfig.fromMap(Map<dynamic, dynamic> map) {
    return AppConfig(
      apiUrl: map[0] as String,
      apiToken: map[1] as String,
      defaultModel: map[2] as String?,
      reviewModel: map[3] as String?,
      selectedTemplateId: map[4] as String?,
      provider: map[5] as String? ?? 'openai', // По умолчанию OpenAI для старых конфигураций
      llmopsBaseUrl: map[6] as String?,
      llmopsModel: map[7] as String?,
      llmopsAuthHeader: map[8] as String?,
      outputFormat: map[9] as OutputFormat? ?? OutputFormat.markdown, // По умолчанию Markdown для старых конфигураций
      confluenceConfig: map[10] as ConfluenceConfig?, // Confluence конфигурация для новых пользователей, null для существующих
      cerebrasToken: map[11] as String?, // Cerebras AI токен
      groqToken: map[12] as String?, // Groq токен
      // Игнорируем старое поле useConfluenceFormat - теперь всегда используем Confluence
    );
  }
  
  AppConfig copyWith({
    String? apiUrl,
    String? apiToken,
    String? defaultModel,
    String? reviewModel,
    String? selectedTemplateId,
    String? provider,
    String? llmopsBaseUrl,
    String? llmopsModel,
    String? llmopsAuthHeader,
    OutputFormat? outputFormat,
    Object? confluenceConfig = _sentinel,
    String? cerebrasToken,
    String? groqToken,
  }) {
    return AppConfig(
      apiUrl: apiUrl ?? this.apiUrl,
      apiToken: apiToken ?? this.apiToken,
      defaultModel: defaultModel ?? this.defaultModel,
      reviewModel: reviewModel ?? this.reviewModel,
      selectedTemplateId: selectedTemplateId ?? this.selectedTemplateId,
      provider: provider ?? this.provider,
      llmopsBaseUrl: llmopsBaseUrl ?? this.llmopsBaseUrl,
      llmopsModel: llmopsModel ?? this.llmopsModel,
      llmopsAuthHeader: llmopsAuthHeader ?? this.llmopsAuthHeader,
      outputFormat: outputFormat ?? this.outputFormat,
      confluenceConfig: confluenceConfig == _sentinel 
          ? this.confluenceConfig 
          : confluenceConfig as ConfluenceConfig?,
      cerebrasToken: cerebrasToken ?? this.cerebrasToken,
      groqToken: groqToken ?? this.groqToken,
    );
  }
}

// Sentinel object to distinguish between null and not provided
const Object _sentinel = Object();

// Helper functions for ConfluenceConfig JSON serialization
Map<String, dynamic>? _confluenceConfigToJson(ConfluenceConfig? config) {
  return config?.toJson();
}

ConfluenceConfig? _confluenceConfigFromJson(Map<String, dynamic>? json) {
  return json != null ? ConfluenceConfig.fromJson(json) : null;
}
