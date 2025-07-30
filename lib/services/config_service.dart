import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/app_config.dart';
import '../models/output_format.dart';

class ConfigService extends ChangeNotifier {
  static const String _boxName = 'config_v3_clean'; // Полностью новый бокс без legacy данных
  static const String _configKey = 'app_config';
  
  AppConfig? _config;
  Box<AppConfig>? _box;
  
  AppConfig? get config => _config;
  
  Future<void> init() async {
    try {
      // Открываем новый бокс
      _box = await Hive.openBox<AppConfig>(_boxName);
      
      // Пытаемся прочитать конфигурацию
      try {
        _config = _box!.get(_configKey);
        
        // Выполняем миграцию для существующих конфигураций без format preference
        if (_config != null) {
          _config = _migrateConfigIfNeeded(_config!);
        }
      } catch (e) {
        print('Ошибка при чтении конфига, возможно старый формат: $e');
        // Если не можем прочитать конфиг, очищаем и создаем новый
        await _box!.delete(_configKey);
        _config = null;
      }
      
      // Если конфигурации нет, оставляем как есть (не мигрируем из legacy, поскольку отключили legacy адаптеры)
      // Пользователь должен будет заново настроить приложение
      
    } catch (e) {
      print('Ошибка при инициализации ConfigService: $e');
      // Если что-то пошло не так, очищаем все и создаем чистый бокс
      try {
        await _cleanupAllBoxes();
        _box = await Hive.openBox<AppConfig>(_boxName);
        _config = null;
      } catch (e2) {
        print('Критическая ошибка при создании бокса: $e2');
        rethrow;
      }
    }
  }
  
  /// Migrates existing configuration to include format preference if missing
  AppConfig _migrateConfigIfNeeded(AppConfig config) {
    // Check if the config already has a valid format preference
    if (_isValidFormat(config.preferredFormat)) {
      return config;
    }
    
    // Migration: set default format preference for existing configurations
    print('Migrating configuration: setting default format preference to Markdown');
    final migratedConfig = config.copyWith(
      preferredFormat: OutputFormat.defaultFormat,
    );
    
    // Save the migrated configuration
    _saveMigratedConfig(migratedConfig);
    
    return migratedConfig;
  }
  
  /// Validates if the format preference is valid
  bool _isValidFormat(OutputFormat? format) {
    if (format == null) return false;
    return OutputFormat.values.contains(format);
  }
  
  /// Saves migrated configuration asynchronously
  void _saveMigratedConfig(AppConfig config) {
    // Save asynchronously to avoid blocking initialization
    Future.microtask(() async {
      try {
        await _box!.put(_configKey, config);
        print('Configuration migration completed successfully');
      } catch (e) {
        print('Error saving migrated configuration: $e');
      }
    });
  }
  
  /// Gets the preferred format with fallback to default
  OutputFormat getPreferredFormat() {
    if (_config?.preferredFormat != null && _isValidFormat(_config!.preferredFormat)) {
      return _config!.preferredFormat;
    }
    return OutputFormat.defaultFormat;
  }
  
  /// Validates and updates format preference with fallback
  Future<void> updatePreferredFormatWithValidation(OutputFormat? format) async {
    final validFormat = format ?? OutputFormat.defaultFormat;
    
    if (!_isValidFormat(validFormat)) {
      print('Invalid format provided, using default: ${OutputFormat.defaultFormat.displayName}');
      await updatePreferredFormat(OutputFormat.defaultFormat);
      return;
    }
    
    await updatePreferredFormat(validFormat);
  }

  Future<void> _cleanupAllBoxes() async {
    // Список всех возможных имен боксов для очистки
    final allBoxNames = ['config', 'config_v2', 'config_v3_clean', _boxName];
    
    for (final boxName in allBoxNames) {
      try {
        // Проверяем, открыт ли бокс
        if (Hive.isBoxOpen(boxName)) {
          await Hive.box(boxName).close();
        }
        
        // Пытаемся удалить файл бокса
        await Hive.deleteBoxFromDisk(boxName);
        print('Успешно удален бокс: $boxName');
      } catch (e) {
        print('Не удалось удалить бокс $boxName: $e');
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
    
    try {
      // Убеждаемся, что сохраняем именно новый тип AppConfig с typeId=4
      // Создаем новый экземпляр для гарантии правильного типа
      final newConfig = AppConfig(
        apiUrl: config.apiUrl,
        apiToken: config.apiToken,
        defaultModel: config.defaultModel,
        reviewModel: config.reviewModel,
        selectedTemplateId: config.selectedTemplateId,
        provider: config.provider,
        llmopsBaseUrl: config.llmopsBaseUrl,
        llmopsModel: config.llmopsModel,
        llmopsAuthHeader: config.llmopsAuthHeader,
        preferredFormat: config.preferredFormat,
      );
      
      _config = newConfig;
      
      // Очищаем ключ перед записью, чтобы избежать конфликтов типов
      await _box!.delete(_configKey);
      await _box!.put(_configKey, newConfig);
      
      notifyListeners();
    } catch (e) {
      print('Ошибка при сохранении конфига: $e');
      // Если ошибка связана с legacy адаптером, делаем полную очистку
      if (e.toString().contains('read-only') || e.toString().contains('Legacy')) {
        print('Обнаружена проблема с legacy адаптером, выполняем полную очистку...');
        await forceReset();
        // Пытаемся сохранить еще раз после очистки
        await _box!.put(_configKey, config);
        _config = config;
        notifyListeners();
      } else {
        rethrow;
      }
    }
  }
  
  Future<void> updateSelectedModel(String model) async {
    if (_config != null) {
      final updatedConfig = _config!.copyWith(defaultModel: model);
      await saveConfig(updatedConfig);
    }
  }

  Future<void> updatePreferredFormat(OutputFormat format) async {
    if (_config != null) {
      final updatedConfig = _config!.copyWith(preferredFormat: format);
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
      final allBoxNames = ['config', 'config_v2', 'config_v3_clean', _boxName];
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
