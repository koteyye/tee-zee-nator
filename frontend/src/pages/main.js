// Главная страница приложения
import { appState } from '../utils/appState.js';
import { initializeMonacoEditor, getInputText } from '../utils/editor.js';
import { showMessage, formatMarkdown } from '../utils/ui.js';
import { loadModelsFromConfig } from '../utils/api.js';
import { 
    UpdateLastUsedModel, 
    GenerateRequirements,
    GetConfig 
} from '../../wailsjs/go/main/App.js';
import { 
    loadTemplatesFromConfig, 
    loadCurrentTemplate,
    loadDefaultTemplate 
} from '../utils/api.js';

// Создание HTML интерфейса
export function createInterface() {
    return `
        <div class="main-container">
            <!-- Хедер с заголовком и кнопкой настроек -->
            <div class="header-section">
                <h1 class="main-title">TeeZeeNator</h1>
                <div class="header-buttons">
                    <button id="templates-btn" class="btn btn-secondary btn-settings">
                        Шаблон ТЗ
                    </button>
                    <button id="settings-btn" class="btn btn-secondary btn-settings btn-icon">
                        <span class="icon icon-settings"></span>
                        Настройки
                    </button>
                </div>
            </div>
            
            <!-- Сообщения -->
            <div id="message-container"></div>
            
            <!-- Выбор модели -->
            <div class="section">
                <label class="field-label" for="model-selector">
                    Модель ИИ
                </label>
                <select id="model-selector" class="model-select">
                    <option value="">Выберите модель...</option>
                </select>
            </div>
            
            <!-- Поле ввода сырых требований -->
            <div class="section">
                <label class="field-label" for="input-field">
                    Сырые требования
                </label>
                <div class="input-container">
                    <div id="monaco-editor-container" class="monaco-editor-container">
                        <!-- Monaco Editor будет здесь -->
                    </div>
                </div>
            </div>
            
            <!-- Кнопка генерации (слева) -->
            <div class="section">
                <div class="button-container-left">
                    <button id="generate-btn" class="btn btn-primary">
                        <span id="generate-text">Сгенерировать</span>
                        <div id="generate-spinner" class="loading-spinner hidden"></div>
                    </button>
                </div>
            </div>
            
            <!-- Блок результата -->
            <div class="section">
                <label class="field-label">
                    Результат
                </label>
                <div id="result-container" class="result-container empty">
                    <span>Здесь появится сгенерированный результат</span>
                </div>
            </div>
            
            <!-- Кнопка сохранения (слева) -->
            <div class="section">
                <div class="button-container-left">
                    <button id="save-btn" class="btn btn-secondary btn-icon" disabled>
                        <span class="icon icon-save"></span>
                        Сохранить .md
                    </button>
                </div>
            </div>
            
            <!-- Поле для уточнений (появляется после получения результата) -->
            <div id="refinement-section" class="section hidden">
                <label class="field-label" for="refinement-input">
                    Что изменить
                </label>
                <div class="input-container">
                    <textarea 
                        id="refinement-input" 
                        class="text-input refinement-input"
                        placeholder="Например: Добавить требования по безопасности, убрать мобильное приложение, изменить технологический стек..."
                    ></textarea>
                </div>
                <div class="button-container-left">
                    <button id="refine-btn" class="btn btn-primary">
                        <span id="refine-text">Изменить требования</span>
                        <div id="refine-spinner" class="loading-spinner hidden"></div>
                    </button>
                </div>
            </div>
        </div>
    `;
}

// Обработчики событий для главной страницы
export function setupMainEventListeners() {
    // Селектор модели на главном экране
    document.getElementById('model-selector')?.addEventListener('change', async (e) => {
        const selectedModel = e.target.value;
        if (selectedModel && appState.isConfigured) {
            try {
                await UpdateLastUsedModel(selectedModel);
                appState.selectedModel = selectedModel;
                appState.config = await GetConfig();
                showMessage('Модель изменена на: ' + selectedModel);
            } catch (error) {
                showMessage('Ошибка изменения модели: ' + error, 'error');
            }
        }
    });
    
    // Кнопка генерации
    document.getElementById('generate-btn')?.addEventListener('click', async () => {
        const inputText = getInputText();
        
        if (!inputText) {
            showMessage('Введите сырые требования для генерации', 'error');
            return;
        }
        
        if (!appState.selectedModel) {
            showMessage('Выберите модель для генерации', 'error');
            return;
        }
        
        // Сохраняем оригинальные требования
        appState.originalInput = inputText;
        appState.conversationHistory = []; // Сбрасываем историю при новой генерации
        
        await generateRequirements(inputText, false);
    });
    
    // Кнопка уточнения требований
    document.getElementById('refine-btn')?.addEventListener('click', async () => {
        const refinementText = document.getElementById('refinement-input')?.value.trim();
        
        if (!refinementText) {
            showMessage('Введите что нужно изменить', 'error');
            return;
        }
        
        // Создаем промт для уточнения на основе оригинальных требований и истории
        const contextPrompt = `Исходные сырые требования: "${appState.originalInput}"
        
Текущие сформированные требования: "${appState.lastResult}"

Что нужно изменить: ${refinementText}

Пожалуйста, обнови требования согласно указанным изменениям, сохранив структуру и добавив/изменив только то, что было запрошено.`;

        await generateRequirements(contextPrompt, true);
        
        // Очищаем поле уточнений
        document.getElementById('refinement-input').value = '';
    });
    
    // Кнопка сохранения
    document.getElementById('save-btn')?.addEventListener('click', async () => {
        if (!appState.lastResult) {
            showMessage('Нет результата для сохранения', 'error');
            return;
        }
        
        try {
            const blob = new Blob([appState.lastResult], { type: 'text/markdown' });
            const url = URL.createObjectURL(blob);
            
            const a = document.createElement('a');
            a.href = url;
            a.download = `requirements_${new Date().toISOString().slice(0, 19).replace(/[:-]/g, '')}.md`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
            
            showMessage('Файл сохранен!');
            
        } catch (error) {
            console.error('Ошибка сохранения:', error);
            showMessage('Ошибка сохранения файла: ' + error, 'error');
        }
    });
}

// Генерация требований
export async function generateRequirements(inputText, isRefinement = false) {
    try {
        appState.isGenerating = true;
        
        // Обновляем UI
        const generateBtn = document.getElementById('generate-btn');
        const refineBtn = document.getElementById('refine-btn');
        const generateText = document.getElementById('generate-text');
        const refineText = document.getElementById('refine-text');
        const generateSpinner = document.getElementById('generate-spinner');
        const refineSpinner = document.getElementById('refine-spinner');
        
        if (generateBtn) generateBtn.disabled = true;
        if (refineBtn) refineBtn.disabled = true;
        
        if (isRefinement) {
            if (refineText) refineText.textContent = 'Обрабатываем...';
            if (refineSpinner) refineSpinner.classList.remove('hidden');
        } else {
            if (generateText) generateText.textContent = 'Генерируем...';
            if (generateSpinner) generateSpinner.classList.remove('hidden');
        }
        
        // Получаем выбранную модель
        const modelSelector = document.getElementById('model-selector');
        if (!modelSelector || !modelSelector.value) {
            throw new Error('Выберите модель ИИ');
        }
        
        const selectedModel = modelSelector.value;
        
        // Обновляем последнюю использованную модель
        await UpdateLastUsedModel(selectedModel);
        
        // Получаем текущий шаблон
        let template = '';
        if (appState.selectedTemplate === 'default') {
            template = await loadDefaultTemplate();
        } else {
            template = await loadCurrentTemplate();
        }
        
        // Формируем запрос
        let messages = [];
        
        if (isRefinement && appState.conversationHistory.length > 0) {
            // Для уточнения используем историю диалога
            messages = [...appState.conversationHistory];
            messages.push({
                role: 'user',
                content: `Пожалуйста, измените техническое задание с учетом следующих требований: ${inputText}`
            });
        } else {
            // Первоначальная генерация
            const systemPrompt = `Ты - опытный системный аналитик. Твоя задача - создать подробное техническое задание на основе сырых требований пользователя.

Используй следующий шаблон как основу для структуры документа:

${template}

Замени переменные:
- {{USER_INPUT}} - на содержимое пользовательского ввода
- {{SYSTEM_ROLE}} - на "Системный аналитик"
- {{CURRENT_DATE}} - на текущую дату

Требования:
1. Анализируй требования пользователя и структурируй их
2. Добавляй недостающие разделы, которые важны для полноценного ТЗ
3. Используй четкий технический язык
4. Добавляй конкретные критерии приемки
5. Предлагай подходящие технологии и архитектурные решения`;

            messages = [
                { role: 'system', content: systemPrompt },
                { role: 'user', content: inputText }
            ];
            
            // Сохраняем оригинальный ввод
            appState.originalInput = inputText;
        }
        
        // Вызываем API
        const result = await GenerateRequirements(messages, selectedModel);
        
        if (result && result.content) {
            appState.lastResult = result.content;
            
            // Обновляем историю диалога
            appState.conversationHistory = [...messages];
            appState.conversationHistory.push({
                role: 'assistant',
                content: result.content
            });
            
            // Показываем результат
            const outputContainer = document.getElementById('output-container');
            if (outputContainer) {
                outputContainer.innerHTML = formatMarkdown(result.content);
                outputContainer.scrollIntoView({ behavior: 'smooth' });
            }
            
            // Показываем секцию уточнений
            const refinementSection = document.getElementById('refinement-section');
            if (refinementSection) {
                refinementSection.classList.remove('hidden');
            }
            
            // Показываем кнопку сохранения
            const saveBtn = document.getElementById('save-btn');
            if (saveBtn) {
                saveBtn.classList.remove('hidden');
            }
            
            showMessage('Требования успешно сгенерированы', 'success');
        } else {
            throw new Error('Получен пустой ответ от API');
        }
        
    } catch (error) {
        console.error('Ошибка генерации:', error);
        showMessage('Ошибка генерации: ' + error.message, 'error');
    } finally {
        appState.isGenerating = false;
        
        // Восстанавливаем UI
        const generateBtn = document.getElementById('generate-btn');
        const refineBtn = document.getElementById('refine-btn');
        const generateText = document.getElementById('generate-text');
        const refineText = document.getElementById('refine-text');
        const generateSpinner = document.getElementById('generate-spinner');
        const refineSpinner = document.getElementById('refine-spinner');
        
        if (generateBtn) generateBtn.disabled = false;
        if (refineBtn) refineBtn.disabled = false;
        
        if (generateText) generateText.textContent = 'Генерировать ТЗ';
        if (refineText) refineText.textContent = 'Изменить требования';
        
        if (generateSpinner) generateSpinner.classList.add('hidden');
        if (refineSpinner) refineSpinner.classList.add('hidden');
    }
}

// Показать главный экран
export function showMainView() {
    appState.currentView = 'main';
    document.querySelector('#app').innerHTML = createInterface();
    
    // Настраиваем обработчики событий
    setupMainEventListeners();
    
    // Инициализируем Monaco Editor с задержкой
    setTimeout(() => {
        initializeMonacoEditor();
    }, 100);
    
    // Загружаем модели если настроено
    setTimeout(() => {
        loadModelsFromConfig();
        
        // Восстанавливаем состояние, если есть результат
        if (appState.lastResult) {
            const resultContainer = document.getElementById('result-container');
            const saveBtn = document.getElementById('save-btn');
            const refinementSection = document.getElementById('refinement-section');
            
            resultContainer.innerHTML = `<div class="markdown-content">${formatMarkdown(appState.lastResult)}</div>`;
            resultContainer.classList.remove('empty');
            saveBtn.disabled = false;
            refinementSection.classList.remove('hidden');
        }
    }, 200);
}
