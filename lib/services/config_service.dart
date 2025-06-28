import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/app_config.dart';

class ConfigService extends ChangeNotifier {
  static const String _boxName = 'config';
  static const String _configKey = 'app_config';
  
  AppConfig? _config;
  Box<AppConfig>? _box;
  
  AppConfig? get config => _config;
  
  Future<void> init() async {
    _box = await Hive.openBox<AppConfig>(_boxName);
    _config = _box!.get(_configKey);
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
}
