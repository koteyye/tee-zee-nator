import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/template.dart';
import '../models/output_format.dart';
import '../services/template_service.dart';
import '../services/config_service.dart';
import '../widgets/template_management/editable_template_selector.dart';
import '../widgets/template_management/review_model_selector.dart';
import '../services/template_review_controller.dart';
import '../services/template_review_streaming_service.dart';
import '../services/llm_service.dart';
import '../widgets/template_management/template_fix_diff_view.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class TemplateManagementScreen extends StatefulWidget {
  const TemplateManagementScreen({super.key});

  @override
  State<TemplateManagementScreen> createState() => _TemplateManagementScreenState();
}

class _TemplateManagementScreenState extends State<TemplateManagementScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TemplateReviewController _reviewController = TemplateReviewController();
  final ScrollController _reviewScroll = ScrollController();
  final ScrollController _fixScroll = ScrollController();
  
  Template? _selectedTemplate;
  String? _selectedReviewModel;
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  
  @override
  void initState() {
    super.initState();
    // Используем addPostFrameCallback для избежания проблем с layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActiveTemplate();
      _loadReviewModel();
    });
  _reviewController.addListener(_autoScrollReview);
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    _reviewScroll.dispose();
    _fixScroll.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  void _autoScrollReview() {
    if (!_reviewScroll.hasClients) return;
    // Scroll only during active streaming (reviewing or fixing)
    if (_reviewController.phase == TemplateReviewPhase.reviewing || _reviewController.phase == TemplateReviewPhase.fixing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_reviewScroll.hasClients) {
          _reviewScroll.jumpTo(_reviewScroll.position.maxScrollExtent);
        }
      });
    }
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
    });
  }
  
  void _onContentChanged() {
    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
  // ревью нужно провести заново при изменении контента
      });
    }
  }
  
  Future<void> _reviewTemplate() async {
    if (_selectedReviewModel == null) {
      _showError('Выберите модель для ревью');
      return;
    }
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showError('Контент шаблона не может быть пустым');
      return;
    }
    final llmService = Provider.of<LLMService>(context, listen: false);
    final streaming = TemplateReviewStreamingService(llmService: llmService);
    final stream = streaming.streamReview(content: content, model: _selectedReviewModel);
    _reviewController.startReview(stream: stream, currentContent: content);
  // Результат ревью отображается через _reviewController.reviewText
  }

  void _startFix() {
    if (_reviewController.phase != TemplateReviewPhase.reviewCompleted) return;
    final reviewText = _reviewController.reviewText;
    final content = _contentController.text;
    final llmService = Provider.of<LLMService>(context, listen: false);
    final streaming = TemplateReviewStreamingService(llmService: llmService);
    final stream = streaming.streamFix(
      original: content,
      reviewText: reviewText,
      model: _selectedReviewModel,
    );
    _reviewController.startFix(stream: stream, currentContent: content);
  }

  void _acceptFix() {
    final newContent = _reviewController.acceptFix();
    if (newContent != null) {
      _contentController.text = newContent;
      setState(() {
        _hasUnsavedChanges = true; // content changed
      });
    }
  }

  void _rejectFix() {
    _reviewController.rejectFix();
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
      
      // Новый контроль: если критические и не игнорируем — блок
      if (_reviewController.severity == TemplateReviewSeverity.critical && !_reviewController.ignoreCritical) {
        _showError('Есть критические замечания — исправьте или включите "Игнорировать ревью"');
        return;
      }
      
      if (_selectedTemplate == null) {
        // Создаем новый пользовательский шаблон
        final newId = 'user_${DateTime.now().millisecondsSinceEpoch}';
        final newTemplate = Template(
          id: newId,
          name: name,
          content: content,
          isDefault: false,
          createdAt: DateTime.now(),
          format: TemplateFormat.markdown,
        );
        await templateService.saveTemplate(newTemplate);
        setState(() {
          _selectedTemplate = newTemplate;
          _hasUnsavedChanges = false;
        });
      } else {
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
      }
      
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
      _hasUnsavedChanges = true; // чтобы подчеркнуть необходимость сохранения после ввода
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
  
  // Legacy _showReviewDialog removed (streaming review now inline)
  
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
                    
                    // Контент + (при фиксе) панель фикса, затем ревью ниже
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Контент всегда слева, занимает всю ширину если нет фикса
                                Expanded(
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
                                    readOnly: _reviewController.phase == TemplateReviewPhase.reviewing || _reviewController.phase == TemplateReviewPhase.fixing,
                                  ),
                                ),
                                if (_reviewController.phase == TemplateReviewPhase.fixing || _reviewController.phase == TemplateReviewPhase.fixCompleted) ...[
                                  const SizedBox(width: 16),
                                  // Панель фикса
                                  Expanded(
                                    child: AnimatedBuilder(
                                      animation: _reviewController,
                                      builder: (context, _) {
                                        Widget child;
                                        if (_reviewController.phase == TemplateReviewPhase.fixing) {
                                          child = Markdown(
                                            data: _reviewController.fixBuffer ?? '*Генерация исправленного шаблона...*',
                                            shrinkWrap: true,
                                            physics: const NeverScrollableScrollPhysics(),
                                          );
                                        } else {
                                          child = TemplateFixDiffView(
                                            original: _reviewController.originalContentSnapshot,
                                            fixed: _reviewController.fixBuffer ?? '',
                                          );
                                        }
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Режим исправления', style: Theme.of(context).textTheme.titleMedium),
                                            const SizedBox(height: 8),
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  border: Border.all(color: Colors.blueGrey),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Scrollbar(
                                                  controller: _fixScroll,
                                                  thumbVisibility: true,
                                                  child: SingleChildScrollView(
                                                    controller: _fixScroll,
                                                    primary: false,
                                                    child: child,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                if (_reviewController.phase == TemplateReviewPhase.fixCompleted)
                                                  ElevatedButton.icon(
                                                    onPressed: _acceptFix,
                                                    icon: const Icon(Icons.check),
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                                    label: const Text('Принять'),
                                                  ),
                                                if (_reviewController.phase == TemplateReviewPhase.fixCompleted) const SizedBox(width: 8),
                                                if (_reviewController.phase == TemplateReviewPhase.fixCompleted)
                                                  OutlinedButton.icon(
                                                    onPressed: _rejectFix,
                                                    icon: const Icon(Icons.close),
                                                    label: const Text('Отклонить'),
                                                  ),
                                              ],
                                            )
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Ревью (всегда внизу полноширинно)
                          SizedBox(
                            height: 260,
                            child: AnimatedBuilder(
                              animation: _reviewController,
                              builder: (context, _) {
                                Color borderColor;
                                String statusText;
                                switch (_reviewController.severity) {
                                  case TemplateReviewSeverity.critical:
                                    borderColor = Colors.red; statusText = 'Критические замечания'; break;
                                  case TemplateReviewSeverity.minor:
                                    borderColor = Colors.orange; statusText = 'Незначительные замечания'; break;
                                  case TemplateReviewSeverity.ok:
                                    borderColor = Colors.green; statusText = _reviewController.phase == TemplateReviewPhase.reviewing ? 'Ревью...' : 'Шаблон корректен'; break;
                                }
                                final showIgnore = _reviewController.severity == TemplateReviewSeverity.critical;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Text('Ревью шаблона', style: Theme.of(context).textTheme.titleMedium),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: borderColor.withOpacity(0.1),
                                          border: Border.all(color: borderColor),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(children: [
                                          SizedBox(width: 10, height: 10, child: DecoratedBox(decoration: BoxDecoration(color: borderColor, shape: BoxShape.circle))),
                                          const SizedBox(width: 6),
                                          Text(statusText, style: TextStyle(color: borderColor, fontSize: 12)),
                                        ]),
                                      ),
                                      const Spacer(),
                                      if (_reviewController.phase == TemplateReviewPhase.reviewing)
                                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                                    ]),
                                    const SizedBox(height: 6),
                                    Row(children: [
                                      Checkbox(
                                        value: _reviewController.ignoreCritical,
                                        onChanged: showIgnore ? (v) => _reviewController.setIgnoreCritical(v ?? false) : null,
                                      ),
                                      const Text('Игнорировать ревью'),
                                      if (showIgnore) const SizedBox(width: 8),
                                      if (showIgnore)
                                        Icon(
                                          _reviewController.canSave ? Icons.lock_open : Icons.lock,
                                          size: 16,
                                          color: _reviewController.canSave ? Colors.green : Colors.red,
                                        )
                                    ]),
                                    Expanded(
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: borderColor),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Scrollbar(
                                          controller: _reviewScroll,
                                          thumbVisibility: true,
                                          child: SingleChildScrollView(
                                            controller: _reviewScroll,
                                            primary: false,
                                            child: Markdown(
                                              data: _reviewController.reviewText.isEmpty
                                                  ? (_reviewController.phase == TemplateReviewPhase.reviewing ? '*Стриминг ответа...*' : '—')
                                                  : _reviewController.reviewText,
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    if (_reviewController.phase == TemplateReviewPhase.reviewCompleted && _reviewController.severity != TemplateReviewSeverity.ok)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: ElevatedButton.icon(
                                          onPressed: _startFix,
                                          icon: const Icon(Icons.build),
                                          label: const Text('Исправить'),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Кнопки действий
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _reviewController.phase == TemplateReviewPhase.reviewing || _selectedReviewModel == null
                                ? null
                                : _reviewTemplate,
                            icon: const Icon(Icons.rate_review),
                            label: Text(_reviewController.phase == TemplateReviewPhase.reviewing ? 'Ревью...' : 'Ревью шаблона'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _selectedTemplate == null || !_reviewController.canSave ? null : _saveTemplate,
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
