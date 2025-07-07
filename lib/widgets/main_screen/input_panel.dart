import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/config_service.dart';
import '../../models/generation_history.dart';

class InputPanel extends StatelessWidget {
  final TextEditingController rawRequirementsController;
  final TextEditingController changesController;
  final String generatedTz;
  final List<GenerationHistory> history;
  final bool isGenerating;
  final String? errorMessage;
  final VoidCallback onGenerate;
  final VoidCallback onClear;
  final ValueChanged<String> onHistoryItemTap;

  const InputPanel({
    super.key,
    required this.rawRequirementsController,
    required this.changesController,
    required this.generatedTz,
    required this.history,
    required this.isGenerating,
    required this.errorMessage,
    required this.onGenerate,
    required this.onClear,
    required this.onHistoryItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Сырые требования
        const Text(
          'Сырые требования:',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: rawRequirementsController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Введите сырые требования...',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        
        // Поле изменений (показывается после первой генерации)
        if (generatedTz.isNotEmpty) ...[
          const Text(
            'Изменения и дополнения:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: changesController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Введите изменения или дополнения...',
                  hintStyle: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Кнопки
        Row(
          children: [
            Consumer<ConfigService>(
              builder: (context, configService, child) {
                final canGenerate = configService.config != null && 
                                  rawRequirementsController.text.trim().isNotEmpty &&
                                  !isGenerating;
                
                return ElevatedButton(
                  onPressed: canGenerate ? onGenerate : null,
                  child: isGenerating 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(generatedTz.isEmpty ? 'Сгенерировать ТЗ' : 'Обновить ТЗ'),
                );
              },
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Очистить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade50,
                foregroundColor: Colors.orange.shade700,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        
        // История запросов
        if (history.isNotEmpty) ...[
          const Text(
            'История запросов:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    '${item.timestamp.day}.${item.timestamp.month}.${item.timestamp.year} ${item.timestamp.hour}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Модель: ${item.model}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      Text(
                        item.rawRequirements.length > 50
                            ? '${item.rawRequirements.substring(0, 50)}...'
                            : item.rawRequirements,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                  onTap: () => onHistoryItemTap(item.generatedTz),
                );
              },
            ),
          ),
        ],
        
        // Ошибка
        if (errorMessage != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Text(
              errorMessage!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      ],
    );
  }
}
