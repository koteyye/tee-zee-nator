import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/llm_service.dart';
import '../../services/config_service.dart';

class ReviewModelSelector extends StatefulWidget {
  final String? selectedModel;
  final ValueChanged<String?> onModelSelected;

  const ReviewModelSelector({
    super.key,
    required this.selectedModel,
    required this.onModelSelected,
  });

  @override
  State<ReviewModelSelector> createState() => _ReviewModelSelectorState();
}

class _ReviewModelSelectorState extends State<ReviewModelSelector> {
  List<String> _models = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Перенесем загрузку в addPostFrameCallback чтобы избежать проблем с layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadModels();
    });
  }

  Future<void> _loadModels() async {
    final llmService = Provider.of<LLMService>(context, listen: false);
    final configService = Provider.of<ConfigService>(context, listen: false);
    final config = configService.config;
    
    if (config == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    // Инициализируем провайдер если нужно
    if (llmService.provider == null) {
      llmService.initializeProvider(config);
    }
    
    setState(() {
      _models = llmService.availableModels;
      _isLoading = false;
    });
    
    // Если моделей нет для OpenAI, попробуем их загрузить
    if (_models.isEmpty && config.provider == 'openai') {
      try {
        setState(() {
          _isLoading = true;
        });
        
        final success = await llmService.testConnection();
        if (success) {
          final models = await llmService.getModels();
          setState(() {
            _models = models;
          });
        }
      } catch (e) {
        print('Error loading models: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else if (config.provider == 'llmops') {
      // Для LLMOps добавляем настроенную модель
      setState(() {
        _models = [config.llmopsModel ?? 'llama3'];
      });
    }
  }

  Future<void> _saveSelectedModel(String? modelId) async {
    if (modelId == null) return;
    
    final configService = Provider.of<ConfigService>(context, listen: false);
    final currentConfig = configService.config;
    
    if (currentConfig != null) {
      final updatedConfig = currentConfig.copyWith(reviewModel: modelId);
      await configService.saveConfig(updatedConfig);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_models.isEmpty) {
      return Container(
        height: 48,
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade200),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: Text(
            'Модели не загружены. Проверьте настройки подключения к API.',
            style: TextStyle(color: Colors.orange),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: widget.selectedModel,
      decoration: const InputDecoration(
        labelText: 'Модель для ревью шаблонов',
        border: OutlineInputBorder(),
        helperText: 'Выберите модель, которая будет проводить ревью шаблонов',
      ),
      items: _models.map((modelId) {
        return DropdownMenuItem<String>(
          value: modelId,
          child: Text(modelId),
        );
      }).toList(),
      onChanged: (modelId) {
        widget.onModelSelected(modelId);
        _saveSelectedModel(modelId);
      },
      hint: const Text('Выберите модель для ревью'),
    );
  }
}
