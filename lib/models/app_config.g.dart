// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppConfigAdapter extends TypeAdapter<AppConfig> {
  @override
  final int typeId = 1;

  @override
  AppConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppConfig(
      apiUrl: fields[0] as String,
      apiToken: fields[1] as String,
      selectedModel: fields[2] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AppConfig obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.apiUrl)
      ..writeByte(1)
      ..write(obj.apiToken)
      ..writeByte(2)
      ..write(obj.selectedModel);
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
      selectedModel: json['selectedModel'] as String?,
    );

Map<String, dynamic> _$AppConfigToJson(AppConfig instance) => <String, dynamic>{
      'apiUrl': instance.apiUrl,
      'apiToken': instance.apiToken,
      'selectedModel': instance.selectedModel,
    };
