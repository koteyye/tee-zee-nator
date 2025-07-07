import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/template.dart';
import '../../services/template_service.dart';

class TemplateSelector extends StatelessWidget {
  final ValueChanged<Template?> onTemplateSelected;

  const TemplateSelector({
    super.key,
    required this.onTemplateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TemplateService>(
      builder: (context, templateService, child) {
        if (!templateService.isInitialized || templateService.cachedActiveTemplate == null) {
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
        );
      },
    );
  }
}

class _TemplateDropdown extends StatefulWidget {
  final TemplateService templateService;
  final ValueChanged<Template?> onTemplateSelected;

  const _TemplateDropdown({
    required this.templateService,
    required this.onTemplateSelected,
  });

  @override
  State<_TemplateDropdown> createState() => _TemplateDropdownState();
}

class _TemplateDropdownState extends State<_TemplateDropdown> {
  List<Template> _templates = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final templates = await widget.templateService.getAllTemplates();
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

    final currentValue = widget.templateService.cachedActiveTemplate;
    
    return DropdownButtonFormField<Template>(
      value: currentValue,
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
        }
      },
      hint: const Text('Выберите шаблон'),
    );
  }
}
