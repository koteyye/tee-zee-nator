import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/app_config.dart';

class ConfigService extends ChangeNotifier {
  static const String _boxName = 'config_v2'; // Изменили имя бокса для избежания конфликтов
  static const String _configKey = 'app_config';
  
  AppConfig? _config;
  Box<AppConfig>? _box;
  
  AppConfig? get config => _config;
  
  Future<void> init() async {
    try {
      // Сначала пытаемся очистить старые боксы, если они существуют
      await _cleanupOldBoxes();
      
      // Открываем новый бокс
      _box = await Hive.openBox<AppConfig>(_boxName);
      _config = _box!.get(_configKey);
    } catch (e) {
      print('Ошибка при инициализации ConfigService: $e');
      // Если что-то пошло не так, создаем чистый бокс
      try {
        _box = await Hive.openBox<AppConfig>(_boxName);
        _config = null;
      } catch (e2) {
        print('Критическая ошибка при создании бокса: $e2');
        rethrow;
      }
    }
  }
  
  Future<void> _cleanupOldBoxes() async {
    // Список старых имен боксов для очистки
    final oldBoxNames = ['config'];
    
    for (final oldBoxName in oldBoxNames) {
      try {
        // Проверяем, открыт ли старый бокс
        if (Hive.isBoxOpen(oldBoxName)) {
          await Hive.box(oldBoxName).close();
        }
        
        // Пытаемся удалить старый файл
        await Hive.deleteBoxFromDisk(oldBoxName);
        print('Успешно удален старый бокс: $oldBoxName');
      } catch (e) {
        print('Не удалось удалить старый бокс $oldBoxName: $e');
        // Не прерываем выполнение, просто логируем
      }
    }
  }
  
  Future<bool> hasValidConfiguration() async {
    await init();
    return _config != null && 
           _config!.apiUrl.isNotEmpty && 
           _config!.apiToken.isNotEmpty;
  }
  
  Future<void> saveConfig(AppConfig config) async {
    await init();
    _config = config;
    await _box!.put(_configKey, config);
    notifyListeners();
  }
  
  Future<void> updateSelectedModel(String model) async {
    if (_config != null) {
      final updatedConfig = _config!.copyWith(selectedModel: model);
      await saveConfig(updatedConfig);
    }
  }
  
  Future<void> clearConfig() async {
    await init();
    await _box!.delete(_configKey);
    _config = null;
    notifyListeners();
  }
  
  /// Принудительно очищает все данные конфигурации, включая файлы на диске
  Future<void> forceReset() async {
    try {
      // Закрываем текущий бокс
      if (_box != null && _box!.isOpen) {
        await _box!.close();
      }
      
      // Удаляем все возможные боксы
      final allBoxNames = ['config', 'config_v2', _boxName];
      for (final boxName in allBoxNames) {
        try {
          if (Hive.isBoxOpen(boxName)) {
            await Hive.box(boxName).close();
          }
          await Hive.deleteBoxFromDisk(boxName);
        } catch (e) {
          print('Не удалось удалить бокс $boxName: $e');
        }
      }
      
      // Пересоздаем чистый бокс
      _box = await Hive.openBox<AppConfig>(_boxName);
      _config = null;
      notifyListeners();
      
      print('Конфигурация успешно сброшена');
    } catch (e) {
      print('Ошибка при принудительном сбросе: $e');
      rethrow;
    }
  }
}
