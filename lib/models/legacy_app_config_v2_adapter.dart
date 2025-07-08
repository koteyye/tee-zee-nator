import 'package:hive/hive.dart';
import 'app_config.dart';

/// Адаптер для чтения старой версии AppConfig (typeId: 2)
class LegacyAppConfigV2Adapter extends TypeAdapter<AppConfig> {
  @override
  final int typeId = 2;

  @override
  AppConfig read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    final numOfFields = reader.readByte();
    for (int i = 0; i < numOfFields; i++) {
      final int key = reader.readByte();
      final dynamic value = reader.read();
      fields[key] = value;
    }
    
    return AppConfig(
      apiUrl: fields[0] as String? ?? '',
      apiToken: fields[1] as String? ?? '',
      defaultModel: fields[2] as String?,
      reviewModel: fields[3] as String?,
      selectedTemplateId: fields[4] as String?,
      provider: 'openai', // По умолчанию для старых конфигураций
      llmopsBaseUrl: null,
      llmopsModel: null,
      llmopsAuthHeader: null,
    );
  }

  @override
  void write(BinaryWriter writer, AppConfig obj) {
    // Не используется, так как это только для чтения старых данных
    throw UnimplementedError('LegacyAppConfigV2Adapter is read-only');
  }
}
