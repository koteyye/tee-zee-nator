import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../models/template.dart';
import '../models/app_config.dart';
import '../models/output_format.dart';
import 'llm_service.dart';

class TemplateService extends ChangeNotifier {
  late Box<Template> _templatesBox;
  late Box<String> _settingsBox;
  bool _initialized = false;

  // Unified keys (legacy keys will be migrated)
  static const String _defaultKey = 'default_markdown';
  static const String _activeKey = 'active_template';

  // Legacy keys kept for migration only
  static const String _legacyDefaultConfluenceKey = 'default_confluence';
  static const String _legacyActiveMarkdownKey = 'active_template_markdown';
  static const String _legacyActiveConfluenceKey = 'active_template_confluence';

  bool get isInitialized => _initialized;
  
  Future<void> init() async {
    try {
  _templatesBox = await Hive.openBox<Template>('templates');
  _settingsBox = await Hive.openBox<String>('template_settings');
      
  // Ensure unified default template exists
  await _ensureUnifiedDefaultTemplate();

  // Migrate legacy templates/keys (format split) -> unified
  await _migrateLegacyTemplates();
  await _migrateLegacyKeys();
      
      _initialized = true;
      notifyListeners();
      log('TemplateService initialized successfully');
    } catch (e) {
      log('Error initializing TemplateService: $e');
      final es = e.toString();
      final suspectFormat = es.contains('TemplateFormat') || es.contains("Null' is not a subtype") || es.contains('type cast');
      if (suspectFormat) {
        final recovered = await _attemptRecoveryFromCorruption();
        if (recovered) {
          _initialized = true;
          notifyListeners();
          log('TemplateService recovered after corruption and reinitialized');
          return;
        }
      }
      rethrow;
    }
  }

  Future<bool> _attemptRecoveryFromCorruption() async {
    try {
      log('Attempting templates box recovery: closing & deleting corrupted box');
      const boxName = 'templates';
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
      try { await Hive.deleteBoxFromDisk(boxName); } catch (_) {}
      _templatesBox = await Hive.openBox<Template>(boxName);
      _settingsBox = await Hive.openBox<String>('template_settings');
      await _ensureUnifiedDefaultTemplate();
      await _migrateLegacyTemplates();
      await _migrateLegacyKeys();
      return true;
    } catch (e) {
      log('Recovery attempt failed: $e');
      return false;
    }
  }
  
  
  Future<void> _ensureUnifiedDefaultTemplate() async {
    // Helper to try loading from multiple candidate asset names
    Future<String?> _tryLoadDefaultAsset() async {
      const candidates = ['tz_pattern.md', 'pattern.md'];
      for (final path in candidates) {
        try {
          log('Attempting to load default template asset: $path');
          final content = await rootBundle.loadString(path);
          if (content.trim().isNotEmpty) {
            return content;
          }
        } catch (e) {
          log('Asset not found or failed to load: $path ($e)');
        }
      }
      return null;
    }

    if (!_templatesBox.containsKey(_defaultKey)) {
      final content = await _tryLoadDefaultAsset();
      if (content != null) {
        Future<void> _writeDefault() async {
          final defaultTemplate = Template(
            id: _defaultKey,
            name: 'Шаблон по умолчанию',
            content: content,
            isDefault: true,
            createdAt: DateTime.now(),
            format: TemplateFormat.markdown,
          );
          await _templatesBox.put(_defaultKey, defaultTemplate);
        }
        try {
          await _writeDefault();
          log('Unified default template created successfully from asset');
        } catch (e) {
          if (e.toString().contains('unknown type: TemplateFormat')) {
            log('TemplateFormat adapter missing at write time – registering late and retrying');
            try { Hive.registerAdapter<TemplateFormat>(TemplateFormatAdapter()); } catch (_) {}
            await _writeDefault();
            log('Unified default template created after late adapter registration');
          } else {
            rethrow;
          }
        }
      } else {
        log('No default asset available, creating placeholder default template');
        final placeholder = Template(
          id: _defaultKey,
          name: 'Шаблон по умолчанию (placeholder)',
          content: '# Техническое задание\n\n(Добавьте содержимое – исходный шаблон не найден в сборке)',
          isDefault: true,
          createdAt: DateTime.now(),
          format: TemplateFormat.markdown,
        );
        await _templatesBox.put(_defaultKey, placeholder);
      }
      if (!_settingsBox.containsKey(_activeKey)) {
        await _settingsBox.put(_activeKey, _defaultKey);
      }
    } else {
      // Upgrade existing placeholder if real asset is now present
      final existing = _templatesBox.get(_defaultKey);
      if (existing != null) {
        final looksPlaceholder = existing.content.contains('исходный шаблон не найден') || existing.content.trim().length < 120;
        if (looksPlaceholder) {
          final content = await _tryLoadDefaultAsset();
          if (content != null && content.trim().length > existing.content.trim().length) {
            log('Upgrading placeholder default template with real asset content');
            final upgraded = existing.copyWith(content: content, updatedAt: DateTime.now());
            await _templatesBox.put(_defaultKey, upgraded);
          }
        }
      }
      if (!_settingsBox.containsKey(_activeKey)) {
        await _settingsBox.put(_activeKey, _defaultKey);
      }
    }
  }
  
  Future<List<Template>> getAllTemplates() async {
    try {
      if (!_initialized) await init();
  final templates = _templatesBox.values.toList();
      // Сортируем: дефолтный шаблон первый, остальные по дате создания
      templates.sort((a, b) {
        if (a.isDefault && !b.isDefault) return -1;
        if (!a.isDefault && b.isDefault) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      
      return templates;
    } catch (e) {
      log('Error getting all templates: $e');
      return [];
    }
  }
  
  Future<Template?> getTemplate(String id) async {
    if (!_initialized) await init();
    return _templatesBox.get(id);
  }
  
  Future<Template?> getActiveTemplate(OutputFormat format) async { // format ignored (kept for compatibility)
    try {
      if (!_initialized) await init();
      final activeId = _settingsBox.get(_activeKey) ?? _defaultKey;
      return _templatesBox.get(activeId) ?? _templatesBox.get(_defaultKey);
    } catch (e) {
      log('Error getting active template: $e');
      return null;
    }
  }
  
  Template? get cachedActiveTemplate => null; // Заглушка для совместимости, но лучше использовать getActiveTemplate с форматом
  
  Future<String?> getActiveTemplateId(OutputFormat format) async { // format ignored
    if (!_initialized) await init();
    return _settingsBox.get(_activeKey) ?? _defaultKey;
  }
  
  Future<void> saveTemplate(Template template) async {
    if (!_initialized) await init();
    
    final updatedTemplate = template.copyWith(
      updatedAt: DateTime.now(),
    );
    
    await _templatesBox.put(template.id, updatedTemplate);
    
    notifyListeners();
    log('Template saved: ${template.name}');
  }
  
  Future<void> deleteTemplate(String id) async {
    if (!_initialized) await init();
    
    final template = _templatesBox.get(id);
    if (template == null) {
      throw ArgumentError('Template with id $id not found');
    }
    
    // Нельзя удалить дефолтный шаблон
    if (template.isDefault) {
      throw ArgumentError('Cannot delete default template');
    }
    
    // Если удаляемый шаблон активный, переключаемся на дефолтный
    if (_settingsBox.get(_activeKey) == id) {
      await _settingsBox.put(_activeKey, _defaultKey);
    }
    
    await _templatesBox.delete(id);
    notifyListeners();
    log('Template deleted: ${template.name}');
  }
  
  Future<void> setActiveTemplate(String id, OutputFormat format) async { // format ignored
    if (!_initialized) await init();
    final template = _templatesBox.get(id);
    if (template == null) {
      throw ArgumentError('Template with id $id not found');
    }
    await _settingsBox.put(_activeKey, id);
    notifyListeners();
    log('Active template set: ${template.name}');
  }
  
  Future<String> reviewTemplate(String content, AppConfig config, BuildContext context) async {
    if (!_initialized) await init();
    
    if (config.reviewModel == null || config.reviewModel!.isEmpty) {
      throw ArgumentError('Review model not configured');
    }
    
    // ignore: use_build_context_synchronously
    final llmService = Provider.of<LLMService>(context, listen: false);
    return await llmService.reviewTemplate(content, config.reviewModel);
  }
  
  Future<Template> duplicateTemplate(String sourceId, String newName) async {
    if (!_initialized) await init();
    
    final sourceTemplate = _templatesBox.get(sourceId);
    if (sourceTemplate == null) {
      throw ArgumentError('Source template with id $sourceId not found');
    }
    
    final newId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final duplicatedTemplate = Template(
      id: newId,
      name: newName,
      content: sourceTemplate.content,
      isDefault: false,
      createdAt: DateTime.now(),
      format: sourceTemplate.format,
    );
    
    await saveTemplate(duplicatedTemplate);
    return duplicatedTemplate;
  }
  
  String generateNewTemplateId() {
    return 'user_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  Future<bool> validateTemplate(String content) async {
    // Базовая валидация шаблона
    if (content.trim().isEmpty) {
      return false;
    }
    
    // Можно добавить дополнительные проверки
    return true;
  }
  
  Future<void> _migrateLegacyTemplates() async {
    for (String key in List.from(_templatesBox.keys)) {
      try {
        final t = _templatesBox.get(key);
        // ignore: unnecessary_null_comparison
        if (t != null && t.format == null) { // Legacy without format
          final migrated = t.copyWith(format: TemplateFormat.markdown);
          await _templatesBox.put(key, migrated);
          log('Migrated legacy template $key to markdown');
        } else if (t != null && t.format == TemplateFormat.confluence) {
          // Normalize all to markdown
            final migrated = t.copyWith(format: TemplateFormat.markdown);
            await _templatesBox.put(key, migrated);
            log('Normalized template $key (confluence->markdown)');
        }
      } catch (e) {
        log('Error migrating template $key: $e');
      }
    }
  }
  
  Future<void> _migrateLegacyKeys() async {
    try {
      // If unified active key already exists, nothing to do
      if (_settingsBox.containsKey(_activeKey)) return;

      // Prefer previously selected Markdown active template, else Confluence
      final legacyMarkdown = _settingsBox.get(_legacyActiveMarkdownKey);
      final legacyConfluence = _settingsBox.get(_legacyActiveConfluenceKey);
      final chosen = legacyMarkdown ?? legacyConfluence ?? _defaultKey;
      await _settingsBox.put(_activeKey, chosen);

      // Ensure default template flag is only on unified default
      final legacyDefaultConfluence = _templatesBox.get(_legacyDefaultConfluenceKey);
      if (legacyDefaultConfluence != null && legacyDefaultConfluence.isDefault) {
        final updated = legacyDefaultConfluence.copyWith(isDefault: false);
        await _templatesBox.put(_legacyDefaultConfluenceKey, updated);
      }

      log('Migrated legacy active template keys to unified key ($_activeKey -> $chosen)');
    } catch (e) {
      log('Error migrating legacy template keys: $e');
    }
  }
  
  Future<List<Template>> getTemplatesForFormat(OutputFormat format) async { // format ignored
    if (!_initialized) await init();
    return getAllTemplates();
  }

  Future<Template> createNewTemplate(OutputFormat format, {String name = 'Новый шаблон'}) async { // format ignored
    final newId = generateNewTemplateId();
    final newTemplate = Template(
      id: newId,
      name: name,
      content: '',
      isDefault: false,
      createdAt: DateTime.now(),
      format: TemplateFormat.markdown,
    );
    await saveTemplate(newTemplate);
    return newTemplate;
  }
}
