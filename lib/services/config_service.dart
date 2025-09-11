import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import '../models/app_config.dart';
import '../models/output_format.dart';
import '../services/confluence_error_handler.dart';
import '../models/confluence_config.dart';
import '../exceptions/confluence_exceptions.dart';

class ConfigService extends ChangeNotifier {
  static const String _boxName = 'config_v3_clean'; // Полностью новый бокс без legacy данных
  static const String _configKey = 'app_config';
  static const String _encryptionKey = 'tee_zee_nator_confluence_key_v1';
  
  AppConfig? _config;
  Box<AppConfig>? _box;
  bool _initialized = false;
  bool _useFileFallback = false; // macOS fallback when Hive serialization is broken
  
  AppConfig? get config => _config;
  
  Future<void> init() async {
    if (_initialized && _box != null && _box!.isOpen) {
      return; // Уже инициализировано
    }
    try {
      if (_useFileFallback) {
        // Уже в режиме fallback – просто пробуем восстановить из файла
        try {
          final restored = await _tryRestoreFromBackup();
          _config = restored;
        } catch (e) {
          debugPrint('[ConfigService:init:fallback] restore failed: $e');
        }
        _initialized = true;
        return;
      }
      // Открываем новый бокс
      _box = await Hive.openBox<AppConfig>(_boxName);
      if (kDebugMode) {
        try {
          print('[ConfigService:init] Opened box \'$_boxName\' path=${_box!.path} keys=${_box!.keys.toList()}');
        } catch (_) {}
      }
      
      // Пытаемся прочитать конфигурацию
      try {
        final stored = _box!.get(_configKey);
        _config = stored;
        if (_config != null) {
          _config = _migrateConfigIfNeeded(_config!);
        }
      } catch (e) {
        // НЕ удаляем данные автоматически – избегаем потери настроек
        print('[ConfigService:init] Ошибка при чтении конфига (сохраняем данные для диагностики): $e');
        // Пробуем сразу восстановить из резервной копии
        try {
          final restored = await _tryRestoreFromBackup();
          if (restored != null) {
            _config = restored;
            await _box!.put(_configKey, _config!);
            await _box!.flush();
            print('[ConfigService:init] Конфиг восстановлен из backup после ошибки чтения.');
          }
        } catch (e2) {
          print('[ConfigService:init] Не удалось восстановить из backup после ошибки чтения: $e2');
        }
        _config = null; // Оставляем как неинициализированный, пользователь сможет пересохранить
      }
      
      // Если конфигурации нет, оставляем как есть (не мигрируем из legacy, поскольку отключили legacy адаптеры)
      // Пользователь должен будет заново настроить приложение
      if (_config == null) {
        try {
          final restored = await _tryRestoreFromBackup();
            if (restored != null) {
              _config = restored;
              await _box!.put(_configKey, _config!);
              await _box!.flush();
              print('Конфиг восстановлен из резервной копии');
            }
        } catch (e) {
          print('Не удалось восстановить конфиг из резервной копии: $e');
        }
      }
      
    } catch (e) {
      print('Ошибка при инициализации ConfigService: $e');
      // Если это macOS и проблема потенциально связана с адаптером, уходим в файловый fallback
      if (e.toString().contains("OutputFormat") || e.toString().contains('AppConfig')) {
        debugPrint('[ConfigService:init] Switching to file fallback storage');
        _useFileFallback = true;
        try {
          final restored = await _tryRestoreFromBackup();
          _config = restored;
        } catch (e2) {
          debugPrint('[ConfigService:init] Fallback restore failed: $e2');
        }
        _initialized = true;
        return;
      }
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
    _initialized = true;
  }
  
  /// Migrates existing configuration to include format preference if missing
  AppConfig _migrateConfigIfNeeded(AppConfig config) {
    // Check if the config already has a valid format preference
    if (_isValidFormat(config.outputFormat)) {
      return config;
    }
    
    // Migration: set default format preference for existing configurations
    print('Migrating configuration: setting default format preference to Markdown');
    final migratedConfig = config.copyWith(
      outputFormat: OutputFormat.defaultFormat,
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
    if (_config?.outputFormat != null && _isValidFormat(_config!.outputFormat)) {
      return _config!.outputFormat;
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
    if (!_initialized) {
      await init();
    }
    if (_config == null) return false;
    final provider = _config!.provider;
    bool valid;
    switch (provider) {
      case 'openai':
        valid = _config!.apiUrl.isNotEmpty && _config!.apiToken.isNotEmpty;
        break;
      case 'cerebras':
        valid = (_config!.cerebrasToken ?? '').isNotEmpty;
        break;
      case 'groq':
        valid = (_config!.groqToken ?? '').isNotEmpty;
        break;
      case 'llmops':
        valid = (_config!.llmopsBaseUrl ?? '').isNotEmpty && (_config!.llmopsModel ?? '').isNotEmpty;
        break;
      default:
        valid = _config!.apiUrl.isNotEmpty; // fallback
    }
    if (kDebugMode) {
      print('[ConfigService:hasValidConfiguration] provider=$provider valid=$valid config=$_config');
    }
    return valid;
  }
  
  Future<void> saveConfig(AppConfig config) async {
    if (!_initialized) {
      await init();
    }
    
    try {
      if (_useFileFallback) {
        _config = config;
        await _writeBackup(config); // используем backup как основной storage
        notifyListeners();
        return;
      }
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
        // ВАЖНО: сохраняем токены провайдеров
        cerebrasToken: config.cerebrasToken,
        groqToken: config.groqToken,
        outputFormat: config.outputFormat,
        confluenceConfig: config.confluenceConfig,
      );
      
      _config = newConfig;
      
      // Очищаем ключ перед записью, чтобы избежать конфликтов типов
  // Не удаляем предварительно без необходимости – Hive перезапишет значение
      await _box!.put(_configKey, newConfig);
      await _box!.flush();
      await _writeBackup(newConfig);
      if (kDebugMode) {
        print('[ConfigService:saveConfig] Saved & flushed. Box keys=${_box!.keys.toList()}');
      }
      
      notifyListeners();
    } catch (e) {
      print('Ошибка при сохранении конфига: $e');
      if (e.toString().contains("OutputFormat") || e.toString().contains('AppConfig')) {
        // Активируем fallback режим и повторяем сохранение в файл
        debugPrint('[ConfigService:saveConfig] Activating file fallback due to type mismatch');
        _useFileFallback = true;
        try {
          _config = config;
          await _writeBackup(config);
          notifyListeners();
          return;
        } catch (e2) {
          debugPrint('[ConfigService:saveConfig] Fallback save failed: $e2');
        }
      }
      // Если ошибка связана с legacy адаптером, делаем полную очистку
      if (e.toString().contains('read-only') || e.toString().contains('Legacy')) {
        print('Обнаружена проблема с legacy адаптером, выполняем полную очистку...');
        await forceReset();
        // Пытаемся сохранить еще раз после очистки
        await _box!.put(_configKey, config);
        await _box!.flush();
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
      final updatedConfig = _config!.copyWith(outputFormat: format);
      await saveConfig(updatedConfig);
    }
  }
  
  Future<void> clearConfig() async {
  await init();
    await _box!.delete(_configKey);
    _config = null;
  await _deleteBackup();
  await _box!.flush();
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
  await _deleteBackup();
      await _box!.flush();
      
      print('Конфигурация успешно сброшена');
    } catch (e) {
      print('Ошибка при принудительном сбросе: $e');
      rethrow;
    }
  }

  /// Статическая утилита для получения диагностической информации без расширения публичного API моков
  static Map<String, dynamic> debugStatusOf(ConfigService s) {
    return {
      'initialized': s._initialized,
      'hasBox': s._box != null,
      'boxOpen': s._box?.isOpen,
      'boxPath': s._box?.path,
      'keys': s._box?.keys.toList(),
      'config': s._config?.toJson(),
    };
  }

  // ===== Backup JSON persistence =====
  Future<File> _backupFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/app_config_backup.json');
  }

  Future<void> _writeBackup(AppConfig config) async {
    try {
      final f = await _backupFile();
      await f.writeAsString(jsonEncode(config.toJson()));
    } catch (e) {
      print('Не удалось создать резервную копию: $e');
    }
  }

  Future<AppConfig?> _tryRestoreFromBackup() async {
    try {
      final f = await _backupFile();
      if (await f.exists()) {
        final content = await f.readAsString();
        if (content.trim().isEmpty) return null;
        final map = jsonDecode(content) as Map<String, dynamic>;
        return AppConfig.fromJson(map);
      }
    } catch (e) {
      print('Ошибка чтения резервной копии: $e');
    }
    return null;
  }

  Future<void> _deleteBackup() async {
    try {
      final f = await _backupFile();
      if (await f.exists()) {
        await f.delete();
      }
    } catch (e) {
      print('Не удалось удалить резервную копию: $e');
    }
  }

  // ============================================================================
  // CONFLUENCE CONFIGURATION METHODS
  // ============================================================================

  /// Gets the current Confluence configuration
  ConfluenceConfig? getConfluenceConfig() {
    if (_config?.confluenceConfig == null) {
      return null;
    }
    
    final config = _config!.confluenceConfig!;
    
    // Decrypt the token before returning
    try {
      final decryptedToken = _decryptToken(config.token);
      return config.copyWith(token: decryptedToken);
    } catch (e) {
      print('Error decrypting Confluence token: $e');
      // Return config with empty token if decryption fails
      return config.copyWith(token: '', isValid: false);
    }
  }

  /// Saves Confluence configuration with encrypted token
  Future<void> saveConfluenceConfig(ConfluenceConfig confluenceConfig) async {
    await init();
    
    // If main config doesn't exist, create a minimal one to store Confluence config
    if (_config == null) {
      _config = AppConfig(
        apiUrl: '',
        apiToken: '',
        provider: 'openai',
        outputFormat: OutputFormat.markdown,
      );
      await saveConfig(_config!);
    }

    try {
      // Validate configuration before saving
      _validateConfluenceConfig(confluenceConfig);
      
      // Encrypt the token before saving
      final encryptedToken = _encryptToken(confluenceConfig.token);
      final configToSave = confluenceConfig.copyWith(
        token: encryptedToken,
        lastValidated: DateTime.now(),
      );
      
      // Update the main config with Confluence configuration
      final updatedConfig = _config!.copyWith(confluenceConfig: configToSave);
      await saveConfig(updatedConfig);
      
      print('Confluence configuration saved successfully');
    } catch (e) {
      print('Error saving Confluence configuration: $e');
      if (e is ConfluenceException) {
        rethrow;
      }
      throw ConfluenceValidationException(
        'Failed to save Confluence configuration',
        technicalDetails: e.toString(),
        recoveryAction: 'Check your configuration values and try again',
      );
    }
  }

  /// Updates Confluence connection status
  Future<void> updateConfluenceConnectionStatus({
    required bool isValid,
    DateTime? lastValidated,
  }) async {
    final currentConfig = getConfluenceConfig();
    if (currentConfig == null) {
      throw ConfluenceValidationException(
        'Cannot update connection status: Confluence configuration not found',
        recoveryAction: 'Configure Confluence connection first',
      );
    }

    final updatedConfig = currentConfig.copyWith(
      isValid: isValid,
      lastValidated: lastValidated ?? DateTime.now(),
    );

    await saveConfluenceConfig(updatedConfig);
  }

  /// Validates Confluence configuration completeness and format
  bool validateConfluenceConfiguration() {
    final config = getConfluenceConfig();
    if (config == null) return false;
    
    try {
      _validateConfluenceConfig(config);
      return config.isConfigurationComplete && config.isValid;
    } catch (e) {
      return false;
    }
  }

  /// Checks if Confluence integration is enabled and properly configured
  bool isConfluenceEnabled() {
    final config = getConfluenceConfig();
    return config != null && 
           config.enabled && 
           config.isConfigurationComplete && 
           config.isValid;
  }

  /// Disables Confluence integration
  Future<void> disableConfluence() async {
    final currentConfig = getConfluenceConfig();
    if (currentConfig != null) {
      final disabledConfig = currentConfig.copyWith(
        enabled: false,
        isValid: false,
      );
      await saveConfluenceConfig(disabledConfig);
    }
  }

  /// Clears Confluence configuration completely
  Future<void> clearConfluenceConfig() async {
    await init();
    
    if (_config != null) {
      final updatedConfig = _config!.copyWith(confluenceConfig: null);
      await saveConfig(updatedConfig);
      print('Confluence configuration cleared');
    }
  }

  /// Gets connection status information for UI display
  Map<String, dynamic> getConfluenceConnectionStatus() {
    final config = getConfluenceConfig();
    
    if (config == null) {
      return {
        'isConfigured': false,
        'isEnabled': false,
        'isValid': false,
        'lastValidated': null,
        'statusMessage': 'Not configured',
      };
    }

    return {
      'isConfigured': config.isConfigurationComplete,
      'isEnabled': config.enabled,
      'isValid': config.isValid,
      'lastValidated': config.lastValidated,
      'statusMessage': _getConnectionStatusMessage(config),
    };
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Validates Confluence configuration fields
  void _validateConfluenceConfig(ConfluenceConfig config) {
    if (config.enabled) {
      if (config.baseUrl.isEmpty) {
        throw ConfluenceValidationException(
          'Base URL is required when Confluence is enabled',
          fieldName: 'baseUrl',
          recoveryAction: 'Enter a valid Confluence base URL',
        );
      }

      if (config.token.isEmpty) {
        throw ConfluenceValidationException(
          'API token is required when Confluence is enabled',
          fieldName: 'token',
          recoveryAction: 'Enter a valid Confluence API token',
        );
      }

      // Validate URL format
      if (!_isValidConfluenceUrl(config.baseUrl)) {
        throw ConfluenceValidationException(
          'Invalid Confluence URL format',
          fieldName: 'baseUrl',
          invalidValue: config.baseUrl,
          recoveryAction: 'Enter a valid Confluence URL (e.g., https://yourcompany.atlassian.net)',
        );
      }
    }
  }

  /// Validates Confluence URL format
  bool _isValidConfluenceUrl(String url) {
    if (url.isEmpty) return false;
    
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && 
             (uri.scheme == 'http' || uri.scheme == 'https') &&
             uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }

  /// Gets human-readable connection status message
  String _getConnectionStatusMessage(ConfluenceConfig config) {
    if (!config.enabled) {
      return 'Disabled';
    }
    
    if (!config.isConfigurationComplete) {
      return 'Configuration incomplete';
    }
    
    if (!config.isValid) {
      return 'Connection failed';
    }
    
    if (config.lastValidated != null) {
      final timeDiff = DateTime.now().difference(config.lastValidated!);
      if (timeDiff.inDays > 7) {
        return 'Connection not verified recently';
      }
    }
    
    return 'Connected';
  }

  /// Encrypts token using simple XOR encryption with base64 encoding
  String _encryptToken(String token) {
    if (token.isEmpty) return token;
    
    try {
      final keyBytes = utf8.encode(_encryptionKey);
      final tokenBytes = utf8.encode(token);
      final encryptedBytes = <int>[];
      
      for (int i = 0; i < tokenBytes.length; i++) {
        encryptedBytes.add(tokenBytes[i] ^ keyBytes[i % keyBytes.length]);
      }
      
      return base64.encode(encryptedBytes);
    } catch (e) {
      print('Error encrypting token: $e');
      return token; // Return original token if encryption fails
    }
  }

  /// Decrypts token using simple XOR decryption with base64 decoding
  String _decryptToken(String encryptedToken) {
    if (encryptedToken.isEmpty) return encryptedToken;
    
    try {
      // Проверяем, содержит ли токен недопустимые символы в конце
      if (encryptedToken.contains('===')) {
        // Исправляем неправильное окончание base64
        encryptedToken = encryptedToken.replaceAll('===', '==');
      }
      
      // Clean up the base64 string - remove any invalid characters
      String cleanToken = encryptedToken.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
      
      // Check if the token is too malformed
      if (cleanToken.length < encryptedToken.length * 0.8) {
        // Token is too corrupted, more than 20% of characters were invalid
        print('Token appears to be severely malformed, treating as plain text');
        return encryptedToken;
      }
      
      // Проверяем и исправляем padding
      int paddingNeeded = (4 - (cleanToken.length % 4)) % 4;
      cleanToken = cleanToken.replaceAll(RegExp(r'=+$'), '') + ''.padRight(paddingNeeded, '=');
      
      // Verify the token still has valid base64 format after cleaning
      if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(cleanToken)) {
        print('Token still contains invalid base64 characters after cleaning');
        return encryptedToken;
      }
      
      final keyBytes = utf8.encode(_encryptionKey);
      
      List<int> encryptedBytes;
      try {
        encryptedBytes = base64.decode(cleanToken);
      } catch (e) {
        // Используем централизованный обработчик ошибок токена
        return ConfluenceErrorHandler.handleTokenError(encryptedToken, e);
      }
      
      final decryptedBytes = <int>[];
      
      for (int i = 0; i < encryptedBytes.length; i++) {
        decryptedBytes.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
      }
      
      try {
        return utf8.decode(decryptedBytes);
      } catch (e) {
        // Используем централизованный обработчик ошибок токена
        return ConfluenceErrorHandler.handleTokenError(encryptedToken, e);
      }
    } catch (e) {
      // Используем централизованный обработчик ошибок токена
      return ConfluenceErrorHandler.handleTokenError(encryptedToken, e);
    }
  }
}
