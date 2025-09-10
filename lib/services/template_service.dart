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
  
  static const String _defaultMarkdownKey = 'default_markdown';
  static const String _defaultConfluenceKey = 'default_confluence';
  static const String _activeMarkdownKey = 'active_template_markdown';
  static const String _activeConfluenceKey = 'active_template_confluence';
  
  bool get isInitialized => _initialized;
  
  Future<void> init() async {
    try {
      _templatesBox = await Hive.openBox<Template>('templates');
      _settingsBox = await Hive.openBox<String>('template_settings');
      
      // Создаем дефолтный шаблон при первом запуске
      await _ensureDefaultTemplate();
      
      // Migration for legacy templates
      await _migrateLegacyTemplates();
      
      _initialized = true;
      notifyListeners();
      log('TemplateService initialized successfully');
    } catch (e) {
      log('Error initializing TemplateService: $e');
      rethrow;
    }
  }
  
  
  Future<void> _ensureDefaultTemplate() async {
    // Markdown default
    if (!_templatesBox.containsKey(_defaultMarkdownKey)) {
      try {
        final defaultContent = await rootBundle.loadString('tz_pattern.md');
        
        final defaultTemplate = Template(
          id: _defaultMarkdownKey,
          name: 'Шаблон по умолчанию (Markdown)',
          content: defaultContent,
          isDefault: true,
          createdAt: DateTime.now(),
          format: TemplateFormat.markdown,
        );
        
        await _templatesBox.put(_defaultMarkdownKey, defaultTemplate);
        
        if (!_settingsBox.containsKey(_activeMarkdownKey)) {
          await _settingsBox.put(_activeMarkdownKey, _defaultMarkdownKey);
        }
        
        log('Default Markdown template created');
      } catch (e) {
        log('Error creating default Markdown template: $e');
        rethrow;
      }
    }
    
    // Confluence default
    if (!_templatesBox.containsKey(_defaultConfluenceKey)) {
      try {
        final defaultContent = await rootBundle.loadString('assets/tz_pattern_confluence.html');
        
        final defaultTemplate = Template(
          id: _defaultConfluenceKey,
          name: 'Шаблон по умолчанию (Confluence)',
          content: defaultContent,
          isDefault: true,
          createdAt: DateTime.now(),
          format: TemplateFormat.confluence,
        );
        
        await _templatesBox.put(_defaultConfluenceKey, defaultTemplate);
        
        if (!_settingsBox.containsKey(_activeConfluenceKey)) {
          await _settingsBox.put(_activeConfluenceKey, _defaultConfluenceKey);
        }
        
        log('Default Confluence template created');
      } catch (e) {
        log('Error creating default Confluence template: $e');
        rethrow;
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
  
  Future<Template?> getActiveTemplate(OutputFormat format) async {
    try {
      if (!_initialized) await init();
      
      String activeKey, defaultKey;
      TemplateFormat tf = _mapToTemplateFormat(format);
      
      switch (format) {
        case OutputFormat.markdown:
          activeKey = _activeMarkdownKey;
          defaultKey = _defaultMarkdownKey;
          break;
        case OutputFormat.confluence:
          activeKey = _activeConfluenceKey;
          defaultKey = _defaultConfluenceKey;
          break;
      }
      
      final activeId = _settingsBox.get(activeKey);
      Template? template;
      if (activeId != null) {
        template = _templatesBox.get(activeId);
        if (template != null && template.format != tf) {
          template = null;
        }
      }
      
      template ??= _templatesBox.get(defaultKey);
      
      return template;
    } catch (e) {
      log('Error getting active template for $format: $e');
      return null;
    }
  }
  
  Template? get cachedActiveTemplate => null; // Заглушка для совместимости, но лучше использовать getActiveTemplate с форматом
  
  Future<String?> getActiveTemplateId(OutputFormat format) async {
    if (!_initialized) await init();
    
    String activeKey;
    switch (format) {
      case OutputFormat.markdown:
        activeKey = _activeMarkdownKey;
        break;
      case OutputFormat.confluence:
        activeKey = _activeConfluenceKey;
        break;
    }
    return _settingsBox.get(activeKey);
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
    
    // Если удаляемый шаблон активный для какого-то формата, переключаемся на дефолтный
    if (_settingsBox.get(_activeMarkdownKey) == id) {
      await _settingsBox.put(_activeMarkdownKey, _defaultMarkdownKey);
    }
    if (_settingsBox.get(_activeConfluenceKey) == id) {
      await _settingsBox.put(_activeConfluenceKey, _defaultConfluenceKey);
    }
    
    await _templatesBox.delete(id);
    notifyListeners();
    log('Template deleted: ${template.name}');
  }
  
  Future<void> setActiveTemplate(String id, OutputFormat format) async {
    if (!_initialized) await init();
    
    final template = _templatesBox.get(id);
    if (template == null) {
      throw ArgumentError('Template with id $id not found');
    }
    
    if (template.format != _mapToTemplateFormat(format)) {
      throw ArgumentError('Template format does not match $format');
    }
    
    String activeKey;
    switch (format) {
      case OutputFormat.markdown:
        activeKey = _activeMarkdownKey;
        break;
      case OutputFormat.confluence:
        activeKey = _activeConfluenceKey;
        break;
    }
    
    await _settingsBox.put(activeKey, id);
    notifyListeners();
    log('Active template set for $format: ${template.name}');
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
          final inferred = t.content.contains('<html') || t.content.contains('<body') ?
              TemplateFormat.confluence : TemplateFormat.markdown;
          final migrated = t.copyWith(format: inferred);
          await _templatesBox.put(key, migrated);
          log('Migrated legacy template $key to $inferred');
        }
      } catch (e) {
        log('Error migrating template $key: $e');
      }
    }
  }
  
  TemplateFormat _mapToTemplateFormat(OutputFormat format) {
    switch (format) {
      case OutputFormat.markdown:
        return TemplateFormat.markdown;
      case OutputFormat.confluence:
        return TemplateFormat.confluence;
    }
  }
  
  Future<List<Template>> getTemplatesForFormat(OutputFormat format) async {
    if (!_initialized) await init();
    
    final all = await getAllTemplates();
    final tf = _mapToTemplateFormat(format);
    var filtered = all.where((t) => t.format == tf).toList();
    
    filtered.sort((a, b) {
      if (a.isDefault && !b.isDefault) return -1;
      if (!a.isDefault && b.isDefault) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
    
    return filtered;
  }
  
  Future<Template> createNewTemplate(OutputFormat format, {String name = 'Новый шаблон'}) async {
    final newId = generateNewTemplateId();
    final tf = _mapToTemplateFormat(format);
    final newTemplate = Template(
      id: newId,
      name: name,
      content: '',
      isDefault: false,
      createdAt: DateTime.now(),
      format: tf,
    );
    await saveTemplate(newTemplate);
    return newTemplate;
  }
}
