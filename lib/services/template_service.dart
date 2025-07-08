import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import '../models/template.dart';
import '../models/app_config.dart';
import 'llm_service.dart';

class TemplateService extends ChangeNotifier {
  late Box<Template> _templatesBox;
  late Box<String> _settingsBox;
  bool _initialized = false;
  Template? _cachedActiveTemplate;
  
  static const String _defaultTemplateKey = 'default';
  static const String _activeTemplateKey = 'active_template_id';
  
  bool get isInitialized => _initialized;
  Template? get cachedActiveTemplate => _cachedActiveTemplate;
  
  Future<void> init() async {
    try {
      _templatesBox = await Hive.openBox<Template>('templates');
      _settingsBox = await Hive.openBox<String>('template_settings');
      
      // Создаем дефолтный шаблон при первом запуске
      await _ensureDefaultTemplate();
      
      // Кешируем активный шаблон
      await _updateCachedActiveTemplate();
      
      _initialized = true;
      notifyListeners();
      log('TemplateService initialized successfully');
    } catch (e) {
      log('Error initializing TemplateService: $e');
      rethrow;
    }
  }
  
  Future<void> _updateCachedActiveTemplate() async {
    try {
      final activeId = _settingsBox.get(_activeTemplateKey);
      if (activeId != null) {
        _cachedActiveTemplate = _templatesBox.get(activeId);
      }
      
      if (_cachedActiveTemplate == null) {
        _cachedActiveTemplate = _templatesBox.get(_defaultTemplateKey);
      }
    } catch (e) {
      log('Error updating cached active template: $e');
      _cachedActiveTemplate = null;
    }
  }
  
  Future<void> _ensureDefaultTemplate() async {
    if (!_templatesBox.containsKey(_defaultTemplateKey)) {
      try {
        // Загружаем дефолтный шаблон из assets
        final defaultContent = await rootBundle.loadString('tz_pattern.md');
        
        final defaultTemplate = Template(
          id: _defaultTemplateKey,
          name: 'Шаблон по умолчанию',
          content: defaultContent,
          isDefault: true,
          createdAt: DateTime.now(),
        );
        
        await _templatesBox.put(_defaultTemplateKey, defaultTemplate);
        
        // Устанавливаем как активный, если нет активного шаблона
        if (!_settingsBox.containsKey(_activeTemplateKey)) {
          await _settingsBox.put(_activeTemplateKey, _defaultTemplateKey);
        }
        
        log('Default template created and set as active');
      } catch (e) {
        log('Error creating default template: $e');
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
  
  Future<Template?> getActiveTemplate() async {
    try {
      if (!_initialized) await init();
      
      final activeId = _settingsBox.get(_activeTemplateKey);
      if (activeId != null) {
        return _templatesBox.get(activeId);
      }
      
      // Если активный шаблон не найден, возвращаем дефолтный
      return _templatesBox.get(_defaultTemplateKey);
    } catch (e) {
      log('Error getting active template: $e');
      return null;
    }
  }
  
  Future<String?> getActiveTemplateId() async {
    if (!_initialized) await init();
    return _settingsBox.get(_activeTemplateKey);
  }
  
  Future<void> saveTemplate(Template template) async {
    if (!_initialized) await init();
    
    final updatedTemplate = template.copyWith(
      updatedAt: DateTime.now(),
    );
    
    await _templatesBox.put(template.id, updatedTemplate);
    
    // Если сохраняемый шаблон является активным, обновляем кеш
    if (_cachedActiveTemplate?.id == template.id) {
      _cachedActiveTemplate = updatedTemplate;
    }
    
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
    final activeId = _settingsBox.get(_activeTemplateKey);
    if (activeId == id) {
      await setActiveTemplate(_defaultTemplateKey);
    }
    
    await _templatesBox.delete(id);
    notifyListeners();
    log('Template deleted: ${template.name}');
  }
  
  Future<void> setActiveTemplate(String id) async {
    if (!_initialized) await init();
    
    final template = _templatesBox.get(id);
    if (template == null) {
      throw ArgumentError('Template with id $id not found');
    }
    
    await _settingsBox.put(_activeTemplateKey, id);
    _cachedActiveTemplate = template;
    notifyListeners();
    log('Active template set to: ${template.name}');
  }
  
  Future<String> reviewTemplate(String content, AppConfig config, BuildContext context) async {
    if (!_initialized) await init();
    
    if (config.reviewModel == null || config.reviewModel!.isEmpty) {
      throw ArgumentError('Review model not configured');
    }
    
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
}
