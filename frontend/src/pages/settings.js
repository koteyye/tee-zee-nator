// Страница настроек
import { appState } from '../utils/appState.js';
import { showMessage, populateModelSelect } from '../utils/ui.js';
import { loadAvailableModels } from '../utils/api.js';
import { 
    SaveConfig,
    GetConfig 
} from '../../wailsjs/go/main/App.js';

// Создание интерфейса настроек
export function createSettingsInterface() {
    return `
        <div class="main-container">
            <!-- Хедер настроек -->
            <div class="header-section">
                <h1 class="main-title">Настройки API</h1>
                <button id="back-btn" class="btn btn-secondary btn-settings">
                    ← Назад
                </button>
            </div>
            
            <!-- Сообщения -->
            <div id="message-container"></div>
            
            <!-- Настройки API -->
            <div class="section">
                <label class="field-label" for="api-url">
                    URL API провайдера
                </label>
                <input 
                    type="url" 
                    id="api-url" 
                    class="text-input" 
                    style="min-height: auto; height: 50px;"
                    placeholder="https://api.openai.com/v1"
                    value="https://api.openai.com/v1"
                />
            </div>
            
            <div class="section">
                <label class="field-label" for="api-key">
                    API ключ
                </label>
                <input 
                    type="password" 
                    id="api-key" 
                    class="text-input" 
                    style="min-height: auto; height: 50px;"
                    placeholder="Введите ваш API ключ"
                />
            </div>
            
            <div class="section">
                <label class="field-label" for="settings-model-select">
                    Модель по умолчанию
                </label>
                <select id="settings-model-select" class="model-select">
                    <option value="">Сначала проверьте подключение для загрузки моделей</option>
                </select>
            </div>
            
            <!-- Кнопки настроек (слева) -->
            <div class="button-container-left">
                <button id="test-connection-btn" class="btn btn-secondary">
                    <span id="test-text">Проверить подключение</span>
                    <div id="test-spinner" class="loading-spinner hidden"></div>
                </button>
                <button id="save-config-btn" class="btn btn-primary" disabled>
                    Сохранить настройки
                </button>
            </div>
        </div>
    `;
}

// Обработчики событий настроек
export function setupSettingsEventListeners() {
    // Обработчик для поля API ключа (очистка при клике на звездочки)
    document.getElementById('api-key')?.addEventListener('focus', (e) => {
        if (e.target.value.startsWith('••••••')) {
            e.target.value = '';
            e.target.placeholder = 'Введите новый API ключ';
        }
    });
    
    // Проверка подключения
    document.getElementById('test-connection-btn')?.addEventListener('click', async () => {
        const apiUrl = document.getElementById('api-url')?.value.trim();
        const apiKeyInput = document.getElementById('api-key')?.value.trim();
        
        // Используем существующий ключ, если поле содержит звездочки или пустое
        const apiKey = (apiKeyInput && !apiKeyInput.startsWith('••••••')) ? apiKeyInput : appState.currentApiKey;
        
        if (!apiUrl || !apiKey) {
            showMessage('Заполните URL API и ключ', 'error');
            return;
        }
        
        const btn = document.getElementById('test-connection-btn');
        const text = document.getElementById('test-text');
        const spinner = document.getElementById('test-spinner');
        
        btn.disabled = true;
        text.textContent = 'Проверяем...';
        spinner.classList.remove('hidden');
        
        try {
            // Загружаем модели
            const models = await loadAvailableModels(apiUrl, apiKey);
            
            // Заполняем селект моделей в настройках
            populateModelSelect('settings-model-select', models, appState.selectedModel);
            
            showMessage(`Подключение успешно! Загружено моделей: ${models.length}`);
            document.getElementById('save-config-btn').disabled = false;
        } catch (error) {
            showMessage('Ошибка подключения: ' + error, 'error');
        } finally {
            btn.disabled = false;
            text.textContent = 'Проверить подключение';
            spinner.classList.add('hidden');
        }
    });
    
    // Сохранение настроек
    document.getElementById('save-config-btn')?.addEventListener('click', async () => {
        const apiUrl = document.getElementById('api-url')?.value.trim();
        const apiKeyInput = document.getElementById('api-key')?.value.trim();
        const selectedModel = document.getElementById('settings-model-select')?.value || 'gpt-3.5-turbo';
        
        // Используем существующий ключ, если поле содержит звездочки или пустое
        const apiKey = (apiKeyInput && !apiKeyInput.startsWith('••••••')) ? apiKeyInput : appState.currentApiKey;
        
        if (!apiUrl || !apiKey) {
            showMessage('Заполните URL API и ключ', 'error');
            return;
        }
        
        try {
            await SaveConfig(apiUrl, apiKey, selectedModel);
            appState.config = await GetConfig();
            appState.isConfigured = true;
            appState.selectedModel = selectedModel;
            appState.currentApiKey = apiKey;
            
            showMessage('Настройки сохранены!');
            
            // Автоматически возвращаемся на главный экран через 2 секунды
            setTimeout(() => {
                // Импортируем showMainView здесь для избежания циклической зависимости
                import('./main.js').then(({ showMainView }) => {
                    showMainView();
                });
            }, 2000);
        } catch (error) {
            showMessage('Ошибка сохранения настроек: ' + error, 'error');
        }
    });
}

// Загрузка текущих настроек
export async function loadCurrentSettings() {
    try {
        if (appState.isConfigured && appState.config) {
            const apiUrlField = document.getElementById('api-url');
            const apiKeyField = document.getElementById('api-key');
            
            if (apiUrlField) {
                apiUrlField.value = appState.config.api_url || '';
            }
            
            if (apiKeyField) {
                // Показываем звездочки для существующего ключа
                if (appState.config.api_key) {
                    apiKeyField.value = '••••••••••••••••••••••••••••••••••••••••••••••••••••';
                    apiKeyField.placeholder = 'API ключ сохранен (введите новый для изменения)';
                } else {
                    apiKeyField.placeholder = 'Введите ваш API ключ';
                }
                appState.currentApiKey = appState.config.api_key || '';
            }
            
            // Если у нас есть модели, загружаем их
            if (appState.availableModels.length > 0) {
                populateModelSelect('settings-model-select', appState.availableModels, appState.selectedModel);
            }
        }
    } catch (error) {
        console.error('Ошибка загрузки настроек:', error);
    }
}

// Показать экран настроек
export function showSettingsView() {
    appState.currentView = 'settings';
    document.querySelector('#app').innerHTML = createSettingsInterface();
    
    // Настраиваем обработчики событий
    setupSettingsEventListeners();
    
    // Загружаем текущие настройки
    loadCurrentSettings();
}
