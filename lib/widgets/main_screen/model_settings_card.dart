import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/config_service.dart';
import '../../services/llm_service.dart';
import '../../services/template_service.dart';
import '../template_management/isolated_template_selector.dart';

class ModelSettingsCard extends StatelessWidget {
  const ModelSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<ConfigService, LLMService, TemplateService>(
      builder: (context, configService, llmService, templateService, child) {
        // Добавляем защиту от некорректного состояния
        if (configService.config == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('Инициализация...', style: TextStyle(color: Colors.grey)),
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Первая строка: модель и кнопка обновления
                _buildModelSection(configService, llmService),
                const SizedBox(height: 16),
                // Вторая строка: селектор шаблонов
                _buildTemplateSection(templateService),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModelSection(ConfigService configService, LLMService llmService) {
    // Для LLMOps провайдера не показываем выбор модели, так как она задается в настройках
    if (configService.config?.provider == 'llmops') {
      return Row(
        children: [
          const Text('Модель: ', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(
            configService.config?.llmopsModel ?? 'Не задана',
            style: const TextStyle(color: Colors.blue),
          ),
          const SizedBox(width: 16),
          const Text('Провайдер: LocalLLM', 
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.green,
            ),
          ),
        ],
      );
    }
    
    // Для OpenAI, Cerebras AI и Groq провайдеров показываем выбор модели
    String providerDisplayName;
    switch (configService.config?.provider) {
      case 'cerebras':
        providerDisplayName = 'Cerebras AI';
        break;
      case 'groq':
        providerDisplayName = 'Groq';
        break;
      case 'openai':
      default:
        providerDisplayName = 'Open AI Competitive';
        break;
    }
    
    return Row(
      children: [
        const Text('Модель: ', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: llmService.availableModels.isNotEmpty 
              ? DropdownButton<String>(
                  value: configService.config?.defaultModel,
                  isExpanded: true,
                  isDense: false,
                  items: llmService.availableModels.map((modelId) {
                    return DropdownMenuItem<String>(
                      value: modelId,
                      child: Text(modelId),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      configService.updateSelectedModel(newValue);
                    }
                  },
                )
              : Text(
                  llmService.isLoading 
                    ? 'Загрузка моделей...' 
                    : 'Модели не загружены',
                  style: TextStyle(color: Colors.grey[600]),
                ),
          ),
        ),
        const SizedBox(width: 8),
        Text('Провайдер: $providerDisplayName', 
          style: const TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        // Кнопка обновления моделей
        if (configService.config != null)
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: llmService.isLoading ? null : () async {
              try {
                await llmService.getModels();
              } catch (e) {
                print('Error refreshing models: $e');
              }
            },
            tooltip: 'Обновить список моделей',
          ),

      ],
    );
  }

  Widget _buildTemplateSection(TemplateService templateService) {
    return Row(
      children: [
        const Text('Активный шаблон: ', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            child: templateService.isInitialized
                ? IsolatedTemplateSelector(
                    onTemplateSelected: (template) async {
                      if (template != null) {
                        try {
                          await templateService.setActiveTemplate(template.id);
                        } catch (e) {
                          print('Error setting active template: $e');
                        }
                      }
                    },
                  )
                : Container(
                    height: 48,
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'Инициализация шаблонов...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
          ),
        ),
      ],
    );
  }


}
