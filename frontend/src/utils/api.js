// Утилиты для работы с API
import { appState } from './appState.js';
import { populateModelSelect } from './ui.js';
import { 
    ValidateAndGetModels,
    GetModels,
    GetTemplates,
    GetTemplate,
    GetDefaultTemplate
} from '../../wailsjs/go/main/App.js';

// Функции для работы с моделями
export async function loadAvailableModels(apiUrl, apiKey) {
    try {
        const models = await ValidateAndGetModels(apiUrl, apiKey);
        appState.availableModels = models;
        return models;
    } catch (error) {
        console.error('Ошибка загрузки моделей:', error);
        throw error;
    }
}

export async function loadModelsFromConfig() {
    try {
        if (appState.isConfigured && appState.config) {
            // Загружаем модели из сохраненной конфигурации
            const models = await GetModels();
            appState.availableModels = models;
            
            // Устанавливаем выбранную модель
            appState.selectedModel = appState.config.last_used_model;
            
            // Заполняем селект на главном экране
            populateModelSelect('model-selector', models, appState.selectedModel);
        }
    } catch (error) {
        console.error('Ошибка загрузки моделей из конфигурации:', error);
    }
}

// Функции для работы с шаблонами
export async function loadTemplatesFromConfig() {
    try {
        const templates = await GetTemplates();
        appState.availableTemplates = templates;
        return templates;
    } catch (error) {
        console.error('Ошибка загрузки шаблонов:', error);
        throw error;
    }
}

export async function loadCurrentTemplate() {
    try {
        if (appState.selectedTemplate) {
            const template = await GetTemplate(appState.selectedTemplate);
            return template ? template.content : '';
        }
        return '';
    } catch (error) {
        console.error('Ошибка загрузки текущего шаблона:', error);
        throw error;
    }
}

export async function loadDefaultTemplate() {
    try {
        const template = await GetDefaultTemplate();
        appState.defaultTemplate = template;
        return template ? template.content : '';
    } catch (error) {
        console.error('Ошибка загрузки дефолтного шаблона:', error);
        throw error;
    }
}
