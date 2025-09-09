import 'package:flutter/foundation.dart';
import '../models/agent_response.dart';
import '../models/technical_specification.dart';
import '../services/llm_service.dart';
import '../services/agent_executor.dart';
import '../models/output_format.dart';

class AgentController extends ChangeNotifier {
  final LLMService _llmService;
  late AgentExecutor _executor;
  bool _isProcessing = false;
  String? _error;
  String? _currentUserMessage;

  AgentController({required LLMService llmService}) 
      : _llmService = llmService {
    _executor = AgentExecutor(TechnicalSpecification.empty());
  }

  // Геттеры
  TechnicalSpecification get currentSpec => _executor.currentSpec;
  bool get isProcessing => _isProcessing;
  String? get error => _error;
  double get progress => _executor.progress;
  String? get currentStep => _executor.currentStep;
  String? get currentUserMessage => _currentUserMessage;

  Future<void> handleAgentRequest({
    required String rawRequirements,
    String? changes,
    String? templateContent,
    OutputFormat format = OutputFormat.markdown,
  }) async {
    if (rawRequirements.trim().isEmpty || _isProcessing) return;

    _setProcessing(true);
    _clearError();
    _executor.resetProgress();

    try {
      // Отправляем запрос к агенту
      final agentResponse = await _llmService.generateAgentTZ(
        rawRequirements: rawRequirements,
        changes: changes,
        templateContent: templateContent,
        format: format,
      );

      // Обрабатываем ответ агента
      await _processAgentResponse(agentResponse);

    } catch (e) {
      _setError('Произошла ошибка: $e');
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> _processAgentResponse(AgentResponse response) async {
    // Сохраняем сообщение для пользователя
    _currentUserMessage = response.userMessage;
    notifyListeners();

    // Выполняем действия если есть
    if (response.actions != null) {
      for (final action in response.actions!) {
        try {
          final result = await _executor.executeAction(action);
          debugPrint('Действие ${action.type.name}: $result');
        } catch (e) {
          debugPrint('Ошибка выполнения действия ${action.type.name}: $e');
        }
      }
    }

    // Применяем обновления спецификации
    if (response.specificationSections != null) {
      _executor.applyTemplateUpdates(response.specificationSections!);
    }

    notifyListeners();
  }

  String formatSpecForOutput() {
    final spec = currentSpec;
    final buffer = StringBuffer();
    
    buffer.writeln('# ${spec.title}\n');
    
    for (final entry in spec.sections.entries) {
      if (entry.value.trim().isNotEmpty) {
        buffer.writeln('## ${_formatSectionName(entry.key)}\n');
        buffer.writeln('${entry.value}\n');
      }
    }
    
    buffer.writeln('---');
    buffer.writeln('*Версия: ${spec.metadata.version} | '
        'Статус: ${spec.metadata.status.name} | '
        'Прогресс: ${spec.metadata.progressPercentage.toInt()}% | '
        'Обновлено: ${_formatDateTime(spec.metadata.updatedAt)}*');
        
    if (spec.generationSteps.isNotEmpty) {
      buffer.writeln('\n### История генерации:');
      for (int i = 0; i < spec.generationSteps.length; i++) {
        buffer.writeln('${i + 1}. ${spec.generationSteps[i]}');
      }
    }
    
    return buffer.toString();
  }

  void resetSpecification() {
    _executor.updateSpec(TechnicalSpecification.empty());
    _currentUserMessage = null;
    _clearError();
    notifyListeners();
  }

  // Приватные методы
  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  String _formatSectionName(String name) {
    return name
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}.${dateTime.month}.${dateTime.year} '
           '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}