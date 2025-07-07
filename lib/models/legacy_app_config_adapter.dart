import 'package:hive/hive.dart';
import 'app_config.dart';

// Legacy адаптер для старой версии AppConfig
class LegacyAppConfigAdapter extends TypeAdapter<AppConfig> {
  @override
  final int typeId = 1; // Старый typeId
  
  @override
  AppConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    
    // Старая структура:
    // 0: String apiUrl
    // 1: String apiToken  
    // 2: String? selectedModel (в старых версиях это мог быть bool useConfluenceFormat)
    // 3: возможно bool useConfluenceFormat (в некоторых версиях)
    
    String? defaultModel;
    
    // Пытаемся безопасно извлечь модель
    try {
      final field2 = fields[2];
      if (field2 is String) {
        defaultModel = field2;
      }
      // Если field2 это bool, то это старая версия useConfluenceFormat - игнорируем
    } catch (e) {
      // Игнорируем ошибки при чтении поля 2
    }
    
    return AppConfig(
      apiUrl: fields[0] as String,
      apiToken: fields[1] as String,
      defaultModel: defaultModel,
      reviewModel: null, // Новое поле - устанавливаем null
      selectedTemplateId: null, // Новое поле - устанавливаем null
    );
  }
  
  @override
  void write(BinaryWriter writer, AppConfig obj) {
    // Этот адаптер только для чтения, записи не должно быть
    throw UnimplementedError('Legacy adapter is read-only');
  }
}
