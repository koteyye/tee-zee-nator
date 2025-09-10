import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/template.dart';
import '../models/output_format.dart';
import '../services/template_service.dart';
import '../services/config_service.dart';
import '../widgets/template_management/editable_template_selector.dart';
import '../widgets/template_management/review_model_selector.dart';
import '../widgets/template_management/template_review_dialog.dart';

class TemplateManagementScreen extends StatefulWidget {
  const TemplateManagementScreen({super.key});

  @override
  State<TemplateManagementScreen> createState() => _TemplateManagementScreenState();
}

class _TemplateManagementScreenState extends State<TemplateManagementScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  
  Template? _selectedTemplate;
  String? _selectedReviewModel;
  bool _ignoreReview = false;
  bool _isLoading = false;
  String? _reviewResult;
  bool _hasUnsavedChanges = false;
  
  @override
  void initState() {
    super.initState();
    // Используем addPostFrameCallback для избежания проблем с layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActiveTemplate();
      _loadReviewModel();
    });
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }
  
  Future<void> _loadActiveTemplate() async {
    final templateService = Provider.of<TemplateService>(context, listen: false);
    final configService = Provider.of<ConfigService>(context, listen: false);
    try {
      final config = configService.config;
      if (config == null) return;
      final activeTemplate = await templateService.getActiveTemplate(config.outputFormat);
      if (activeTemplate != null) {
        setState(() {
          _selectedTemplate = activeTemplate;
          _nameController.text = activeTemplate.name;
          _contentController.text = activeTemplate.content;
        });
      }
    } catch (e) {
      _showError('Ошибка загрузки активного шаблона: $e');
    }
  }
  
  Future<void> _loadReviewModel() async {
    final configService = Provider.of<ConfigService>(context, listen: false);
    await configService.init();
    final config = configService.config;
    if (config != null && config.reviewModel != null) {
      setState(() {
        _selectedReviewModel = config.reviewModel;
      });
    }
  }
  
  void _onTemplateSelected(Template? template) {
    if (_hasUnsavedChanges) {
      _showUnsavedChangesDialog(() => _loadTemplate(template));
    } else {
      _loadTemplate(template);
    }
  }
  
  void _loadTemplate(Template? template) {
    setState(() {
      _selectedTemplate = template;
      _nameController.text = template?.name ?? '';
      _contentController.text = template?.content ?? '';
      _hasUnsavedChanges = false;
      _reviewResult = null;
    });
  }
  
  void _onContentChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
        _reviewResult = null; // Сбрасываем результат ревью при изменении
      });
    }
  }
  
  Future<void> _reviewTemplate() async {
    if (_selectedReviewModel == null) {
      _showError('Выберите модель для ревью');
      return;
    }
    
    final configService = Provider.of<ConfigService>(context, listen: false);
    final templateService = Provider.of<TemplateService>(context, listen: false);
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      final config = configService.config;
      if (config == null) {
        throw Exception('Конфигурация не найдена');
      }
      
      final content = _contentController.text.trim();
      if (content.isEmpty) {
        throw Exception('Контент шаблона не может быть пустым');
      }
      
      final reviewResult = await templateService.reviewTemplate(content, config, context);
      
      setState(() {
        _reviewResult = reviewResult;
      });
      
      _showReviewDialog(reviewResult);
      
    } catch (e) {
      _showError('Ошибка при ревью шаблона: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveTemplate() async {
    final templateService = Provider.of<TemplateService>(context, listen: false);
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      final name = _nameController.text.trim();
      final content = _contentController.text.trim();
      
      if (name.isEmpty) {
        throw Exception('Название шаблона не может быть пустым');
      }
      
      if (content.isEmpty) {
        throw Exception('Контент шаблона не может быть пустым');
      }
      
      // Проверяем, нужно ли ревью
      if (!_ignoreReview && _reviewResult == null && !_selectedTemplate!.isDefault) {
        _showError('Проведите ревью шаблона перед сохранением или включите "Игнорировать ревью"');
        return;
      }
      
      // Проверяем критические замечания
      if (_reviewResult != null && _reviewResult!.contains('[CRITICAL_ALERT]') && !_ignoreReview) {
        _showError('Шаблон содержит критические замечания. Исправьте их или включите "Игнорировать ревью"');
        return;
      }
      
      final updatedTemplate = _selectedTemplate!.copyWith(
        name: name,
        content: content,
        updatedAt: DateTime.now(),
      );
      
      await templateService.saveTemplate(updatedTemplate);
      
      setState(() {
        _hasUnsavedChanges = false;
        _selectedTemplate = updatedTemplate;
      });
      
      _showSuccess('Шаблон сохранен успешно');
      
    } catch (e) {
      _showError('Ошибка при сохранении шаблона: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _createNewTemplate() {
    if (_hasUnsavedChanges) {
      _showUnsavedChangesDialog(_performCreateNewTemplate);
    } else {
      _performCreateNewTemplate();
    }
  }
  
  Future<void> _performCreateNewTemplate() async {
    final templateService = Provider.of<TemplateService>(context, listen: false);
    final configService = Provider.of<ConfigService>(context, listen: false);
    final config = configService.config;
    if (config == null) return;
    
    final newTemplate = await templateService.createNewTemplate(config.outputFormat);
    
    setState(() {
      _selectedTemplate = newTemplate;
      _nameController.text = newTemplate.name;
      _contentController.text = newTemplate.content;
      _hasUnsavedChanges = false;
      _reviewResult = null;
    });
  }
  
  Future<void> _deleteTemplate() async {
    if (_selectedTemplate == null || _selectedTemplate!.isDefault) {
      _showError('Нельзя удалить дефолтный шаблон');
      return;
    }
    
    final confirmed = await _showConfirmDialog(
      'Удалить шаблон',
      'Вы уверены, что хотите удалить шаблон "${_selectedTemplate!.name}"?',
    );
    
    if (!confirmed) return;
    
    final templateService = Provider.of<TemplateService>(context, listen: false);
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      await templateService.deleteTemplate(_selectedTemplate!.id);
      
      // Загружаем дефолтный шаблон после удаления
      await _loadActiveTemplate();
      
      _showSuccess('Шаблон удален успешно');
      
    } catch (e) {
      _showError('Ошибка при удалении шаблона: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _showReviewDialog(String reviewResult) {
    showDialog(
      context: context,
      builder: (context) => TemplateReviewDialog(
        reviewResult: reviewResult,
        hasCriticalIssues: reviewResult.contains('[CRITICAL_ALERT]'),
      ),
    );
  }
  
  void _showUnsavedChangesDialog(VoidCallback onProceed) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Несохраненные изменения'),
        content: const Text('У вас есть несохраненные изменения. Продолжить без сохранения?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onProceed();
            },
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
  }
  
  Future<bool> _showConfirmDialog(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление шаблонами ТЗ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_selectedTemplate != null && !_selectedTemplate!.isDefault)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isLoading ? null : _deleteTemplate,
              tooltip: 'Удалить шаблон',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Селектор модели для ревью
                    ReviewModelSelector(
                      selectedModel: _selectedReviewModel,
                      onModelSelected: (model) {
                        setState(() {
                          _selectedReviewModel = model;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Селектор шаблонов и кнопка создания
                    Row(
                      children: [
                        Expanded(
                          child: Consumer<ConfigService>(
                            builder: (context, configService, child) {
                              final config = configService.config;
                              final format = config?.outputFormat ?? OutputFormat.defaultFormat;
                              return EditableTemplateSelector(
                                selectedTemplate: _selectedTemplate,
                                currentFormat: format,
                                onTemplateSelected: _onTemplateSelected,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _createNewTemplate,
                          icon: const Icon(Icons.add),
                          label: const Text('Новый'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Поле названия
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Название шаблона',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _onContentChanged(),
                    ),
                    const SizedBox(height: 16),
                    
                    // Поле контента - обернем в Flexible для безопасности
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 200),
                        child: TextField(
                          controller: _contentController,
                          decoration: const InputDecoration(
                            labelText: 'Контент шаблона',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          maxLines: null,
                          expands: true,
                          textAlignVertical: TextAlignVertical.top,
                          onChanged: (_) => _onContentChanged(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Переключатель игнорирования ревью
                    Row(
                      children: [
                        Checkbox(
                          value: _ignoreReview,
                          onChanged: (value) {
                            setState(() {
                              _ignoreReview = value ?? false;
                            });
                          },
                        ),
                        const Text('Игнорировать ревью'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Кнопки действий
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading || _selectedReviewModel == null
                                ? null
                                : _reviewTemplate,
                            icon: const Icon(Icons.rate_review),
                            label: const Text('Ревью шаблона'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading || _selectedTemplate == null
                                ? null
                                : _saveTemplate,
                            icon: const Icon(Icons.save),
                            label: const Text('Сохранить'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _hasUnsavedChanges
                                  ? Colors.orange
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
