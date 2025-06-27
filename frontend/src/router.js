// Роутинг и управление переходами между страницами
import { appState } from './utils/appState.js';
import { loadModelsFromConfig } from './utils/api.js';
import { 
    createInterface as createMainInterface, 
    setupMainEventListeners
} from './pages/main.js';
import { 
    createSettingsInterface, 
    setupSettingsEventListeners, 
    loadCurrentSettings 
} from './pages/settings.js';
import { 
    createTemplatesInterface, 
    setupTemplateEventListeners, 
    loadTemplates 
} from './pages/templates.js';
import { 
    createAddTemplateInterface, 
    setupAddTemplateEventListeners, 
    initializeAddTemplatePage 
} from './pages/addTemplate.js';

// Показать главную страницу
export function showMainView() {
    appState.currentView = 'main';
    const appContainer = document.getElementById('app');
    if (appContainer) {
        appContainer.innerHTML = createMainInterface();
        setupMainEventListeners();
        loadModelsFromConfig();
        
        // Устанавливаем выбранный шаблон
        const templateInfo = document.getElementById('template-info');
        if (templateInfo && appState.selectedTemplate) {
            if (appState.selectedTemplate === 'default') {
                templateInfo.textContent = 'Используется: Стандартный шаблон';
            } else {
                const template = appState.templates.find(t => t.id === appState.selectedTemplate);
                if (template) {
                    templateInfo.textContent = `Используется: ${template.name}`;
                }
            }
        }
    }
}

// Показать страницу настроек
export function showSettingsView() {
    appState.currentView = 'settings';
    const appContainer = document.getElementById('app');
    if (appContainer) {
        appContainer.innerHTML = createSettingsInterface();
        setupSettingsEventListeners();
        loadCurrentSettings();
    }
}

// Показать страницу шаблонов
export function showTemplatesView() {
    appState.currentView = 'templates';
    const appContainer = document.getElementById('app');
    if (appContainer) {
        appContainer.innerHTML = createTemplatesInterface();
        setupTemplateEventListeners();
        loadTemplates();
    }
}

// Показать страницу добавления шаблона
export function showAddTemplateView() {
    appState.currentView = 'add-template';
    const appContainer = document.getElementById('app');
    if (appContainer) {
        appContainer.innerHTML = createAddTemplateInterface();
        setupAddTemplateEventListeners();
        initializeAddTemplatePage();
    }
}

// Настройка глобальных обработчиков событий для навигации
export function setupGlobalEventListeners() {
    // Обработчики для переходов между страницами
    window.addEventListener('showMainView', showMainView);
    window.addEventListener('showSettingsView', showSettingsView);
    window.addEventListener('showTemplatesView', showTemplatesView);
    window.addEventListener('showAddTemplateView', showAddTemplateView);
    
    // Обработчик для кнопок навигации (используется на всех страницах)
    document.addEventListener('click', (e) => {
        const target = e.target;
        
        // Кнопка "Назад" на странице настроек
        if (target && target.id === 'back-btn') {
            e.preventDefault();
            showMainView();
        }
        
        // Кнопка "Назад" на странице шаблонов
        if (target && target.id === 'back-from-templates-btn') {
            e.preventDefault();
            showMainView();
        }
        
        // Кнопка "Назад" на странице добавления шаблона
        if (target && target.id === 'back-from-add-template-btn') {
            e.preventDefault();
            showTemplatesView();
        }
        
        // Кнопка "Настройки" на главной странице
        if (target && target.id === 'settings-btn') {
            e.preventDefault();
            showSettingsView();
        }
        
        // Кнопка "Шаблоны" на главной странице
        if (target && target.id === 'templates-btn') {
            e.preventDefault();
            showTemplatesView();
        }
        
        // Кнопка "Добавить шаблон" на странице шаблонов
        if (target && target.id === 'add-template-btn') {
            e.preventDefault();
            showAddTemplateView();
        }
    });
}
