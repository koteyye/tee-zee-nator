import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/template.dart';
import '../../models/output_format.dart';
import '../../services/template_service.dart';

class IsolatedTemplateSelector extends StatelessWidget {
  final ValueChanged<Template?> onTemplateSelected;
  final OutputFormat? format;

  const IsolatedTemplateSelector({
    super.key,
    required this.onTemplateSelected,
    this.format,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.grey.shade600 : Colors.grey.shade300;
    final textColor = isDark ? Colors.white : Colors.black;
    return Consumer<TemplateService>(
      builder: (context, templateService, child) {
        if (!templateService.isInitialized) {
          return Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        return FutureBuilder<Template?>(
          future: templateService.getActiveTemplate(format ?? OutputFormat.markdown),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final activeTemplate = snapshot.data;
            if (activeTemplate == null) {
              return Container(
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    'Нет активного шаблона',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              );
            }

            return Container(
              height: 48,
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: InkWell(
                onTap: () => _showTemplateDialog(context, templateService),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      if (activeTemplate.isDefault) ...[
                        const Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          activeTemplate.name,
                          style: TextStyle(color: textColor),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: isDark ? Colors.white70 : null),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTemplateDialog(BuildContext context, TemplateService templateService) async {
    try {
      List<Template> templates;
      if (format != null) {
        templates = await templateService.getTemplatesForFormat(format!);
      } else {
        templates = await templateService.getAllTemplates();
      }
      
      if (!context.mounted) return;
      
      final activeTemplate = await templateService.getActiveTemplate(format ?? OutputFormat.markdown);
      
      final selectedTemplate = await showDialog<Template>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Выберите шаблон'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                final isActive = activeTemplate != null && template.id == activeTemplate.id;
                
                return ListTile(
                  leading: template.isDefault
                    ? const Icon(Icons.star, color: Colors.amber)
                    : const Icon(Icons.description),
                  title: Text(template.name),
                  trailing: isActive ? const Icon(Icons.check, color: Colors.green) : null,
                  onTap: () => Navigator.of(context).pop(template),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
          ],
        ),
      );
      
      if (selectedTemplate != null) {
        onTemplateSelected(selectedTemplate);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка загрузки шаблонов: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
