import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/template.dart';
import '../../models/output_format.dart';
import '../../services/template_service.dart';

class TemplateSelector extends StatelessWidget {
  final ValueChanged<Template?> onTemplateSelected;
  final OutputFormat? format;

  const TemplateSelector({
    super.key,
    required this.onTemplateSelected,
    this.format,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TemplateService>(
      builder: (context, templateService, child) {
        if (!templateService.isInitialized) {
          return Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey)),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text(
                  'Загрузка шаблонов...',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return _TemplateDropdown(
          templateService: templateService,
          onTemplateSelected: onTemplateSelected,
          format: format,
        );
      },
    );
  }
}

class _TemplateDropdown extends StatefulWidget {
  final TemplateService templateService;
  final ValueChanged<Template?> onTemplateSelected;
  final OutputFormat? format;

  const _TemplateDropdown({
    required this.templateService,
    required this.onTemplateSelected,
    this.format,
  });

  @override
  State<_TemplateDropdown> createState() => _TemplateDropdownState();
}

class _TemplateDropdownState extends State<_TemplateDropdown> {
  List<Template> _templates = [];
  bool _isLoading = false;
  Template? _activeTemplate;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    _loadActiveTemplate();
  }

  Future<void> _loadTemplates() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      List<Template> templates;
      if (widget.format != null) {
        templates = await widget.templateService.getTemplatesForFormat(widget.format!);
      } else {
        templates = await widget.templateService.getAllTemplates();
      }
      if (mounted) {
        setState(() {
          _templates = templates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadActiveTemplate() async {
    try {
      Template? active;
      if (widget.format != null) {
        active = await widget.templateService.getActiveTemplate(widget.format!);
      } else {
        active = await widget.templateService.getActiveTemplate(OutputFormat.markdown);
      }
      if (mounted) {
        setState(() {
          _activeTemplate = active;
        });
      }
    } catch (e) {
      // Игнорируем ошибки загрузки активного шаблона
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _templates.isEmpty) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Загрузка списка шаблонов...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_templates.isEmpty) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey)),
        ),
        child: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 16),
            SizedBox(width: 12),
            Text(
              'Ошибка загрузки шаблонов',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }

    Template? currentValue = _activeTemplate;
    // Если active не в списке, ищем по ID
    if (currentValue != null && !_templates.any((t) => t.id == currentValue!.id)) {
      currentValue = null;
    }
    
    return DropdownButtonFormField<Template>(
      initialValue: currentValue,
      decoration: const InputDecoration(
        labelText: 'Активный шаблон',
        border: OutlineInputBorder(),
      ),
      items: _templates.map((template) {
        return DropdownMenuItem<Template>(
          value: template,
          child: Row(
            children: [
              if (template.isDefault)
                const Icon(
                  Icons.star,
                  size: 16,
                  color: Colors.amber,
                ),
              if (template.isDefault) const SizedBox(width: 4),
              Expanded(child: Text(template.name)),
            ],
          ),
        );
      }).toList(),
      onChanged: (Template? newTemplate) {
        if (newTemplate != null) {
          widget.onTemplateSelected(newTemplate);
          // Обновляем локальный кэш
          setState(() {
            _activeTemplate = newTemplate;
          });
        }
      },
      hint: const Text('Выберите шаблон'),
    );
  }
}
