// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppConfigAdapter extends TypeAdapter<AppConfig> {
  @override
  final int typeId = 10;

  @override
  AppConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppConfig(
      apiUrl: fields[0] as String,
      apiToken: fields[1] as String,
      defaultModel: fields[2] as String?,
      reviewModel: fields[3] as String?,
      selectedTemplateId: fields[4] as String?,
      provider: fields[5] as String,
      llmopsBaseUrl: fields[6] as String?,
      llmopsModel: fields[7] as String?,
      llmopsAuthHeader: fields[8] as String?,
      preferredFormat: fields[9] as OutputFormat,
      confluenceConfig: fields[10] as ConfluenceConfig?,
    );
  }

  @override
  void write(BinaryWriter writer, AppConfig obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.apiUrl)
      ..writeByte(1)
      ..write(obj.apiToken)
      ..writeByte(2)
      ..write(obj.defaultModel)
      ..writeByte(3)
      ..write(obj.reviewModel)
      ..writeByte(4)
      ..write(obj.selectedTemplateId)
      ..writeByte(5)
      ..write(obj.provider)
      ..writeByte(6)
      ..write(obj.llmopsBaseUrl)
      ..writeByte(7)
      ..write(obj.llmopsModel)
      ..writeByte(8)
      ..write(obj.llmopsAuthHeader)
      ..writeByte(9)
      ..write(obj.preferredFormat)
      ..writeByte(10)
      ..write(obj.confluenceConfig);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) => AppConfig(
      apiUrl: json['apiUrl'] as String,
      apiToken: json['apiToken'] as String,
      defaultModel: json['defaultModel'] as String?,
      reviewModel: json['reviewModel'] as String?,
      selectedTemplateId: json['selectedTemplateId'] as String?,
      provider: json['provider'] as String? ?? 'openai',
      llmopsBaseUrl: json['llmopsBaseUrl'] as String?,
      llmopsModel: json['llmopsModel'] as String?,
      llmopsAuthHeader: json['llmopsAuthHeader'] as String?,
      preferredFormat:
          $enumDecodeNullable(_$OutputFormatEnumMap, json['preferredFormat']) ??
              OutputFormat.markdown,
      confluenceConfig: _confluenceConfigFromJson(
          json['confluenceConfig'] as Map<String, dynamic>?),
    );

Map<String, dynamic> _$AppConfigToJson(AppConfig instance) => <String, dynamic>{
      'apiUrl': instance.apiUrl,
      'apiToken': instance.apiToken,
      'defaultModel': instance.defaultModel,
      'reviewModel': instance.reviewModel,
      'selectedTemplateId': instance.selectedTemplateId,
      'provider': instance.provider,
      'llmopsBaseUrl': instance.llmopsBaseUrl,
      'llmopsModel': instance.llmopsModel,
      'llmopsAuthHeader': instance.llmopsAuthHeader,
      'preferredFormat': _$OutputFormatEnumMap[instance.preferredFormat]!,
      'confluenceConfig': _confluenceConfigToJson(instance.confluenceConfig),
    };

const _$OutputFormatEnumMap = {
  OutputFormat.markdown: 'markdown',
  OutputFormat.confluence: 'confluence',
};
