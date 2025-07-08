/// Абстрактный провайдер LLM
abstract class LLMProvider {
  /// Отправляет запрос к LLM провайдеру
  Future<String> sendRequest({
    required String systemPrompt,
    required String userPrompt,
    String? model,
    int? maxTokens,
    double? temperature,
  });
  
  /// Получает список доступных моделей
  Future<List<String>> getModels();
  
  /// Тестирует соединение с провайдером
  Future<bool> testConnection();
  
  /// Проверяет, загружены ли модели
  bool get hasModels;
  
  /// Получает список доступных моделей (кеш)
  List<String> get availableModels;
  
  /// Получает состояние загрузки
  bool get isLoading;
  
  /// Получает ошибку, если есть
  String? get error;
}
