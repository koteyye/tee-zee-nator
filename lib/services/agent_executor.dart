import 'package:flutter/foundation.dart';
import '../models/agent_action.dart';
import '../models/technical_specification.dart';

class AgentExecutor extends ChangeNotifier {
  TechnicalSpecification _currentSpec;
  double _progress = 0.0;
  String? _currentStep;
  
  AgentExecutor(this._currentSpec);

  TechnicalSpecification get currentSpec => _currentSpec;
  double get progress => _progress;
  String? get currentStep => _currentStep;

  Future<String> executeAction(AgentAction action) async {
    _currentStep = action.progressMessage ?? 'Выполняю действие...';
    notifyListeners();
    
    String result;
    
    switch (action.type) {
      case AgentActionType.generateContent:
        result = await _generateContent(action);
        break;
      case AgentActionType.validateRequirements:
        result = await _validateRequirements(action);
        break;
      case AgentActionType.suggestImprovements:
        result = await _suggestImprovements(action);
        break;
      case AgentActionType.createStructure:
        result = await _createStructure(action);
        break;
      case AgentActionType.updateSection:
        result = await _updateSection(action);
        break;
    }
    
    _updateProgress();
    notifyListeners();
    
    return result;
  }

  Future<String> _generateContent(AgentAction action) async {
    if (action.section == null || action.content == null) {
      throw Exception('Для generate_content требуются поля section и content');
    }

    // Добавляем шаг генерации
    final steps = List<String>.from(_currentSpec.generationSteps);
    steps.add('Сгенерирован раздел: ${action.section}');

    // Обновляем секцию в текущем ТЗ
    final updatedSections = Map<String, String>.from(_currentSpec.sections);

    updatedSections[action.section!] = action.content!;

    _currentSpec = _currentSpec.copyWith(
      sections: updatedSections,
      generationSteps: steps,
      metadata: _currentSpec.metadata.copyWith(
        updatedAt: DateTime.now(),
        status: SpecStatus.generating,
      ),
    );

    return 'Раздел "${action.section}" успешно сгенерирован';
  }

  Future<String> _validateRequirements(AgentAction action) async {
    final issues = <String>[];
    
    // Проверяем обязательные разделы
    const requiredSections = [
      'overview', 'requirements', 'acceptance_criteria'
    ];
    
    for (final section in requiredSections) {
      if (!_currentSpec.sections.containsKey(section) ||
          _currentSpec.sections[section]?.trim().isEmpty == true) {
        issues.add('Отсутствует раздел: $section');
      }
    }

    final steps = List<String>.from(_currentSpec.generationSteps);
    if (issues.isEmpty) {
      steps.add('Валидация пройдена успешно');
      return 'Все требования корректны';
    } else {
      steps.add('Найдены проблемы валидации: ${issues.length}');
      return 'Найдены проблемы: ${issues.join(', ')}';
    }
  }

  Future<String> _suggestImprovements(AgentAction action) async {
    final suggestions = action.suggestions ?? [];
    
    final steps = List<String>.from(_currentSpec.generationSteps);
    steps.add('Предложены улучшения: ${suggestions.length}');
    
    _currentSpec = _currentSpec.copyWith(generationSteps: steps);
    
    return 'Предложения по улучшению: ${suggestions.join('; ')}';
  }

  Future<String> _createStructure(AgentAction action) async {
    const defaultSections = {
      'overview': 'Описание проекта',
      'goals': 'Цели и задачи',
      'requirements': 'Функциональные требования',
      'technical_requirements': 'Технические требования',
      'acceptance_criteria': 'Критерии приемки',
      'timeline': 'Временные рамки',
      'resources': 'Ресурсы',
    };

    // Объединяем с существующими секциями
    final updatedSections = <String, String>{
      ...defaultSections,
      ..._currentSpec.sections,
    };

    final steps = List<String>.from(_currentSpec.generationSteps);
    steps.add('Создана базовая структура ТЗ');

    _currentSpec = _currentSpec.copyWith(
      sections: updatedSections,
      generationSteps: steps,
      metadata: _currentSpec.metadata.copyWith(
        updatedAt: DateTime.now(),
        status: SpecStatus.generating,
      ),
    );

    return 'Структура технического задания создана';
  }

  Future<String> _updateSection(AgentAction action) async {
    if (action.section == null || action.content == null) {
      throw Exception('Для update_section требуются поля section и content');
    }

    final updatedSections = Map<String, String>.from(_currentSpec.sections);
    updatedSections[action.section!] = action.content!;

    final steps = List<String>.from(_currentSpec.generationSteps);
    steps.add('Обновлен раздел: ${action.section}');

    _currentSpec = _currentSpec.copyWith(
      sections: updatedSections,
      generationSteps: steps,
      metadata: _currentSpec.metadata.copyWith(
        updatedAt: DateTime.now(),
      ),
    );

    return 'Раздел "${action.section}" обновлен';
  }

  void applyTemplateUpdates(Map<String, String> updates) {
    final updatedSections = Map<String, String>.from(_currentSpec.sections);
    updatedSections.addAll(updates);

    final steps = List<String>.from(_currentSpec.generationSteps);
    steps.add('Применены обновления шаблона: ${updates.keys.length}');

    _currentSpec = _currentSpec.copyWith(
      sections: updatedSections,
      generationSteps: steps,
      metadata: _currentSpec.metadata.copyWith(
        updatedAt: DateTime.now(),
      ),
    );
  }

  void _updateProgress() {
    // Простая логика расчета прогресса
    final totalSections = 7; // Предполагаемое количество разделов
    final completedSections = _currentSpec.sections.length;
    _progress = (completedSections / totalSections * 100).clamp(0.0, 100.0);
    
    // Если все разделы заполнены, помечаем как завершенное
    if (_progress >= 90.0) {
      _currentSpec = _currentSpec.copyWith(
        metadata: _currentSpec.metadata.copyWith(
          status: SpecStatus.completed,
          progressPercentage: 100.0,
        ),
      );
      _currentStep = 'Генерация завершена';
    }
  }

  void updateSpec(TechnicalSpecification newSpec) {
    _currentSpec = newSpec;
    notifyListeners();
  }

  void resetProgress() {
    _progress = 0.0;
    _currentStep = null;
    notifyListeners();
  }
}