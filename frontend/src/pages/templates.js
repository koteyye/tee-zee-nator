// Страница управления шаблонами
import { appState } from '../utils/appState.js';
import { showMessage, formatMarkdown } from '../utils/ui.js';
import { 
    GetTemplates,
    GetTemplate,
    DeleteTemplate,
    GetDefaultTemplate
} from '../../wailsjs/go/main/App.js';

// Создание интерфейса шаблонов
export function createTemplatesInterface() {
    return `
        <div class="main-container">
            <!-- Хедер шаблонов -->
            <div class="header-section">
                <h1 class="main-title">Шаблоны ТЗ</h1>
                <div class="header-buttons">
                    <button id="add-template-btn" class="btn btn-primary">
                        + Добавить шаблон
                    </button>
                    <button id="back-from-templates-btn" class="btn btn-secondary btn-settings">
                        ← Назад
                    </button>
                </div>
            </div>
            
            <!-- Сообщения -->
            <div id="message-container"></div>
            
            <!-- Список шаблонов -->
            <div class="section">
                <label class="field-label">
                    Выберите шаблон для просмотра
                </label>
                <select id="template-selector" class="model-select">
                    <option value="">Выберите шаблон...</option>
                </select>
            </div>
            
            <!-- Просмотр шаблона -->
            <div class="section">
                <div class="template-preview">
                    <div id="template-content-preview" class="template-content">
                        <p class="placeholder-text">Выберите шаблон для просмотра</p>
                    </div>
                </div>
            </div>
            
            <!-- Кнопки действий -->
            <div class="section">
                <div class="template-actions">
                    <button id="use-template-btn" class="btn btn-primary" disabled>
                        Использовать этот шаблон
                    </button>
                    <button id="delete-template-btn" class="btn btn-danger" disabled>
                        Удалить шаблон
                    </button>
                </div>
            </div>
        </div>
    `;
}

// Загрузка шаблонов
export async function loadTemplates() {
    try {
        const templates = await GetTemplates();
        appState.templates = templates || [];
        
        const selector = document.getElementById('template-selector');
        if (selector) {
            populateTemplateSelect('template-selector', appState.templates, appState.selectedTemplate);
        }
    } catch (error) {
        console.error('Ошибка загрузки шаблонов:', error);
        showMessage('Ошибка загрузки шаблонов: ' + error.message, 'error');
    }
}

// Заполнение списка шаблонов
function populateTemplateSelect(selectId, templates, selectedTemplate = null) {
    const select = document.getElementById(selectId);
    if (!select) return;
    
    // Очищаем текущие опции, кроме первой
    select.innerHTML = '<option value="">Выберите шаблон...</option>';
    
    // Добавляем дефолтный шаблон
    const defaultOption = document.createElement('option');
    defaultOption.value = 'default';
    defaultOption.textContent = 'Стандартный шаблон';
    select.appendChild(defaultOption);
    
    // Добавляем пользовательские шаблоны
    if (templates && templates.length > 0) {
        templates.forEach(template => {
            const option = document.createElement('option');
            option.value = template.id;
            option.textContent = template.name;
            select.appendChild(option);
        });
    }
    
    // Устанавливаем выбранный шаблон
    if (selectedTemplate) {
        select.value = selectedTemplate;
    }
}

// Загрузка содержимого шаблона
export async function loadTemplateContent(templateId) {
    try {
        let template;
        
        if (templateId === 'default') {
            template = await GetDefaultTemplate();
        } else {
            template = await GetTemplate(templateId);
        }
        
        if (template && template.content) {
            appState.currentTemplate = template.content;
            const preview = document.getElementById('template-content-preview');
            if (preview) {
                preview.innerHTML = formatMarkdown(template.content);
            }
            
            // Активируем кнопки
            const useBtn = document.getElementById('use-template-btn');
            const deleteBtn = document.getElementById('delete-template-btn');
            
            if (useBtn) {
                useBtn.disabled = false;
            }
            
            // Кнопку удаления активируем только для пользовательских шаблонов
            if (deleteBtn) {
                deleteBtn.disabled = templateId === 'default';
            }
        }
    } catch (error) {
        console.error('Ошибка загрузки шаблона:', error);
        showMessage('Ошибка загрузки шаблона: ' + error.message, 'error');
    }
}

// Настройка обработчиков событий для страницы шаблонов
export function setupTemplateEventListeners() {
    // Выбор шаблона
    const templateSelector = document.getElementById('template-selector');
    if (templateSelector) {
        templateSelector.addEventListener('change', async (e) => {
            const templateId = e.target.value;
            if (templateId) {
                await loadTemplateContent(templateId);
            } else {
                // Очищаем превью
                const preview = document.getElementById('template-content-preview');
                if (preview) {
                    preview.innerHTML = '<p class="placeholder-text">Выберите шаблон для просмотра</p>';
                }
                
                // Деактивируем кнопки
                const useBtn = document.getElementById('use-template-btn');
                const deleteBtn = document.getElementById('delete-template-btn');
                
                if (useBtn) useBtn.disabled = true;
                if (deleteBtn) deleteBtn.disabled = true;
            }
        });
    }
    
    // Использование шаблона
    const useTemplateBtn = document.getElementById('use-template-btn');
    if (useTemplateBtn) {
        useTemplateBtn.addEventListener('click', () => {
            const templateSelector = document.getElementById('template-selector');
            if (templateSelector && templateSelector.value) {
                appState.selectedTemplate = templateSelector.value;
                showMessage('Шаблон выбран для использования', 'success');
                
                // Возвращаемся на главную страницу
                setTimeout(() => {
                    // Это событие будет обработано в main.js
                    window.dispatchEvent(new CustomEvent('showMainView'));
                }, 1000);
            }
        });
    }
    
    // Удаление шаблона
    const deleteTemplateBtn = document.getElementById('delete-template-btn');
    if (deleteTemplateBtn) {
        deleteTemplateBtn.addEventListener('click', async () => {
            const templateSelector = document.getElementById('template-selector');
            if (templateSelector && templateSelector.value && templateSelector.value !== 'default') {
                const templateId = templateSelector.value;
                const templateName = templateSelector.options[templateSelector.selectedIndex].text;
                
                if (confirm(`Вы уверены, что хотите удалить шаблон "${templateName}"?`)) {
                    try {
                        await DeleteTemplate(templateId);
                        showMessage('Шаблон удален', 'success');
                        
                        // Перезагружаем список шаблонов
                        await loadTemplates();
                        
                        // Очищаем превью
                        const preview = document.getElementById('template-content-preview');
                        if (preview) {
                            preview.innerHTML = '<p class="placeholder-text">Выберите шаблон для просмотра</p>';
                        }
                        
                        // Деактивируем кнопки
                        const useBtn = document.getElementById('use-template-btn');
                        const deleteBtn = document.getElementById('delete-template-btn');
                        
                        if (useBtn) useBtn.disabled = true;
                        if (deleteBtn) deleteBtn.disabled = true;
                        
                    } catch (error) {
                        console.error('Ошибка удаления шаблона:', error);
                        showMessage('Ошибка удаления шаблона: ' + error.message, 'error');
                    }
                }
            }
        });
    }
}
