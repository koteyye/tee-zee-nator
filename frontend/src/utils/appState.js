// Состояние приложения
export const appState = {
    isConfigured: false,
    config: null,
    isGenerating: false,
    monacoEditor: null,
    templateEditor: null, // Monaco Editor для шаблонов
    lastResult: '',
    originalInput: '', // Сохраняем оригинальные сырые требования
    currentView: 'main', // 'main', 'settings', 'templates', 'add-template'
    conversationHistory: [], // История диалога для контекста
    availableModels: [], // Список доступных моделей
    selectedModel: null, // Выбранная модель
    currentApiKey: '', // Сохраняем текущий API ключ
    templates: [], // Список шаблонов
    availableTemplates: [], // Доступные шаблоны из конфигурации
    selectedTemplate: 'default', // Выбранный шаблон
    currentTemplate: null, // Текущий отображаемый шаблон
    defaultTemplate: null // Дефолтный шаблон
};
