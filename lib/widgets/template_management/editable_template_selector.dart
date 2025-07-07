import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/template.dart';
import '../../services/template_service.dart';

class EditableTemplateSelector extends StatefulWidget {
  final Template? selectedTemplate;
  final ValueChanged<Template?> onTemplateSelected;

  const EditableTemplateSelector({
    super.key,
    required this.selectedTemplate,
    required this.onTemplateSelected,
  });

  @override
  State<EditableTemplateSelector> createState() => _EditableTemplateSelectorState();
}

class _EditableTemplateSelectorState extends State<EditableTemplateSelector> {
  List<Template> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final templateService = Provider.of<TemplateService>(context, listen: false);
    
    try {
      final templates = await templateService.getAllTemplates();
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
      print('Error loading templates: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TemplateService>(
      builder: (context, templateService, child) {
        // Перезагружаем шаблоны при изменениях в сервисе
        if (templateService.isInitialized && _templates.isEmpty && !_isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadTemplates();
          });
        }
        
        if (_isLoading) {
          return const SizedBox(
            height: 48,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (_templates.isEmpty) {
          return Container(
            height: 48,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                'Шаблоны не загружены',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Найдем выбранный шаблон в списке
        Template? currentValue = widget.selectedTemplate;
        if (currentValue != null && !_templates.any((t) => t.id == currentValue!.id)) {
          currentValue = null;
        }

        return DropdownButtonFormField<Template>(
          value: currentValue,
          decoration: const InputDecoration(
            labelText: 'Выберите шаблон для редактирования',
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
          onChanged: widget.onTemplateSelected,
          hint: const Text('Выберите шаблон'),
        );
      },
    );
  }
}
