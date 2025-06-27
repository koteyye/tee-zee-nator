// Главный файл приложения TeeZeeNator с модульной архитектурой
import './mts-style.css';

// Импортируем роутинг и компоненты
import { 
    setupGlobalEventListeners,
    showMainView,
    showSettingsView 
} from './router.js';

// Импортируем состояние приложения и утилиты
import { appState } from './utils/appState.js';
import { showMessage } from './utils/ui.js';
import { loadDefaultTemplate } from './utils/api.js';

// Импортируем функции из Go бэкенда
import {
    GetConfig,
    IsConfigured
} from '../wailsjs/go/main/App.js';

console.log('TeeZeeNator v2.0 - Модульная версия загружена');

// Инициализация приложения
async function initApp() {
    console.log('Инициализация TeeZeeNator...');
    
    try {
        // Проверяем конфигурацию
        appState.isConfigured = await IsConfigured();
        if (appState.isConfigured) {
            appState.config = await GetConfig();
            appState.currentApiKey = appState.config.api_key || '';
            appState.selectedModel = appState.config.last_used_model || '';
            console.log('Конфигурация загружена');
        }
        
        // Загружаем дефолтный шаблон и устанавливаем его как выбранный
        try {
            await loadDefaultTemplate();
            appState.selectedTemplate = 'default'; // Устанавливаем дефолтный шаблон как выбранный
            console.log('Дефолтный шаблон загружен и установлен как активный');
        } catch (error) {
            console.warn('Не удалось загрузить дефолтный шаблон:', error);
        }
        
    } catch (error) {
        console.error('Ошибка инициализации:', error);
        showMessage('Ошибка инициализации приложения: ' + error.message, 'error');
    }
    
    // Настраиваем глобальные обработчики событий
    setupGlobalEventListeners();
    
    // Показываем соответствующий экран
    if (!appState.isConfigured) {
        console.log('Конфигурация не найдена, показываем настройки');
        showSettingsView();
        setTimeout(() => {
            showMessage('Добро пожаловать в TeeZeeNator! Настройте подключение к API для начала работы.', 'info');
        }, 500);
    } else {
        console.log('Показываем главный экран');
        showMainView();
    }
}

// Обработчик ошибок
window.addEventListener('error', (event) => {
    console.error('Глобальная ошибка:', event.error);
    showMessage('Произошла ошибка в приложении. Проверьте консоль разработчика.', 'error');
});

// Обработчик необработанных промисов
window.addEventListener('unhandledrejection', (event) => {
    console.error('Необработанная ошибка промиса:', event.reason);
    showMessage('Произошла ошибка при выполнении запроса: ' + event.reason, 'error');
});

// Запуск приложения после загрузки DOM
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initApp);
} else {
    initApp();
}

// Экспорт для возможности импорта в других модулях
export { initApp };
