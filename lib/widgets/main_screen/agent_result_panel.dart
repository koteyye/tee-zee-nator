import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/technical_specification.dart';
import '../../services/agent_controller.dart';
import '../../models/generation_history.dart';
import '../../models/output_format.dart';

class AgentResultPanel extends StatelessWidget {
  final AgentController controller;
  final List<GenerationHistory> history;
  final OutputFormat selectedFormat;
  final Function(OutputFormat)? onFormatChanged;
  final Function(GenerationHistory)? onHistoryItemSelected;
  final VoidCallback? onExportToConfluence;

  const AgentResultPanel({
    super.key,
    required this.controller,
    required this.history,
    required this.selectedFormat,
    this.onFormatChanged,
    this.onHistoryItemSelected,
    this.onExportToConfluence,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final specification = controller.currentSpec;
        final isGenerating = controller.isProcessing;
        final progress = controller.progress;
        final currentStep = controller.currentStep;
        final userMessage = controller.currentUserMessage;
        final error = controller.error;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Заголовок
            Row(
              children: [
                const Icon(Icons.smart_toy, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'ИИ-агент генерирует ТЗ:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (!isGenerating && specification.sections.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Добавить сохранение через контроллер
                    },
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Сохранить'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Сообщение пользователю
            if (userMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, 
                         size: 16, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        userMessage!,
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Прогресс генерации
            if (isGenerating) ...[
              _buildGenerationProgress(progress, currentStep),
              const SizedBox(height: 12),
            ],
            
            // Ошибка
            if (error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, 
                         size: 16, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            // Основной контент
            Expanded(child: _buildSpecificationContent(specification, isGenerating)),
          ],
        );
      },
    );
  }

  Widget _buildGenerationProgress(double? progress, String? currentStep) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Агент работает...',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: Colors.green.shade100,
              valueColor: AlwaysStoppedAnimation(Colors.green.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              '${progress.toInt()}% завершено',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green.shade700,
              ),
            ),
          ],
          if (currentStep != null) ...[
            const SizedBox(height: 8),
            Text(
              currentStep!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.green.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecificationContent(TechnicalSpecification specification, bool isGenerating) {
    if (specification.sections.isEmpty && !isGenerating) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.smart_toy_outlined,
                size: 48,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'ИИ-агент сгенерирует ТЗ пошагово',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Метаданные спецификации
          _buildSpecificationHeader(specification),
          
          // Контент спецификации
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildSpecificationSections(specification),
            ),
          ),
          
          // История генерации
          if (specification.generationSteps.isNotEmpty)
            _buildGenerationHistory(specification),
        ],
      ),
    );
  }

  Widget _buildSpecificationHeader(TechnicalSpecification specification) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  specification.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Статус: ${_getStatusDisplayName(specification.metadata.status)} | '
                  'Версия: ${specification.metadata.version}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (specification.metadata.progressPercentage > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getProgressColor(specification.metadata.progressPercentage),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${specification.metadata.progressPercentage.toInt()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecificationSections(TechnicalSpecification specification) {
    if (specification.sections.isEmpty) {
      return const Text(
        'Разделы будут появляться по мере генерации...',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: Colors.grey,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: specification.sections.entries.map((entry) {
        return _buildSection(entry.key, entry.value);
      }).toList(),
    );
  }

  Widget _buildSection(String key, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(6),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.article_outlined,
                size: 16,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                _formatSectionName(key),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () => Clipboard.setData(ClipboardData(text: content)),
                tooltip: 'Копировать раздел',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerationHistory(TechnicalSpecification specification) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'История генерации',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...specification.generationSteps.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _formatSectionName(String name) {
    return name
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _getStatusDisplayName(SpecStatus status) {
    switch (status) {
      case SpecStatus.draft:
        return 'Черновик';
      case SpecStatus.generating:
        return 'Генерируется';
      case SpecStatus.review:
        return 'На ревью';
      case SpecStatus.completed:
        return 'Завершено';
    }
  }

  Color _getProgressColor(double progress) {
    if (progress < 30) return Colors.red.shade400;
    if (progress < 70) return Colors.orange.shade400;
    return Colors.green.shade400;
  }
}