import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/config_service.dart';
import '../../services/openai_service.dart';

class ModelSettingsCard extends StatelessWidget {
  final bool useBaseTemplate;
  final ValueChanged<bool> onTemplateToggle;

  const ModelSettingsCard({
    super.key,
    required this.useBaseTemplate,
    required this.onTemplateToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConfigService, OpenAIService>(
      builder: (context, configService, openAIService, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text('Модель: ', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: openAIService.availableModels.isNotEmpty 
                    ? DropdownButton<String>(
                        value: configService.config?.selectedModel,
                        isExpanded: true,
                        items: openAIService.availableModels.map((model) {
                          return DropdownMenuItem<String>(
                            value: model.id,
                            child: Text(model.id),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            configService.updateSelectedModel(newValue);
                          }
                        },
                      )
                    : Text(
                        openAIService.isLoading 
                          ? 'Загрузка моделей...' 
                          : 'Модели не загружены',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                ),
                const SizedBox(width: 16),
                // Кнопка обновления моделей
                if (configService.config != null)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: openAIService.isLoading ? null : () async {
                      await openAIService.getModels(configService.config!);
                    },
                    tooltip: 'Обновить список моделей',
                  ),
                const SizedBox(width: 8),
                const Text('Шаблон ТЗ: '),
                const SizedBox(width: 8),
                Switch(
                  value: useBaseTemplate,
                  onChanged: onTemplateToggle,
                ),
                const SizedBox(width: 8),
                Text(
                  useBaseTemplate ? 'включен' : 'отключен',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: useBaseTemplate ? Colors.green[700] : Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 16),
                const Text('Формат: Confluence HTML', 
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
