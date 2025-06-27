// Страница добавления нового шаблона
import { appState } from '../utils/appState.js';
import { initializeTemplateEditor, getTemplateText } from '../utils/editor.js';
import { showMessage } from '../utils/ui.js';
import { AddTemplate } from '../../wailsjs/go/main/App.js';

// Создание интерфейса добавления шаблона
export function createAddTemplateInterface() {
    return `
        <div class="main-container">
            <!-- Хедер добавления шаблона -->
            <div class="header-section">
                <h1 class="main-title">Добавить шаблон ТЗ</h1>
                <div class="header-buttons">
                    <button id="save-template-btn" class="btn btn-primary">
                        Сохранить шаблон
                    </button>
                    <button id="back-from-add-template-btn" class="btn btn-secondary btn-settings">
                        ← Назад
                    </button>
                </div>
            </div>
            
            <!-- Сообщения -->
            <div id="message-container"></div>
            
            <!-- Название шаблона -->
            <div class="section">
                <label class="field-label" for="template-name">
                    Название шаблона
                </label>
                <input 
                    type="text" 
                    id="template-name" 
                    class="text-input" 
                    style="min-height: auto; height: 50px;"
                    placeholder="Введите название шаблона"
                />
            </div>
            
            <!-- Описание шаблона -->
            <div class="section">
                <label class="field-label" for="template-description">
                    Описание (необязательно)
                </label>
                <input 
                    type="text" 
                    id="template-description" 
                    class="text-input" 
                    style="min-height: auto; height: 50px;"
                    placeholder="Краткое описание шаблона"
                />
            </div>
            
            <!-- Редактор шаблона -->
            <div class="section">
                <label class="field-label" for="template-editor">
                    Содержимое шаблона (Markdown)
                </label>
                <div class="template-editor-container">
                    <div id="monaco-template-editor-container" class="monaco-editor-container">
                        <!-- Monaco Editor для шаблонов будет здесь -->
                    </div>
                    <div class="editor-help">
                        <p><strong>Справка:</strong> Используйте переменные для динамического содержимого:</p>
                        <ul>
                            <li><code>{{USER_INPUT}}</code> - место для вставки пользовательского ввода</li>
                            <li><code>{{SYSTEM_ROLE}}</code> - роль системы (системный аналитик)</li>
                            <li><code>{{CURRENT_DATE}}</code> - текущая дата</li>
                        </ul>
                    </div>
                </div>
            </div>
        </div>
    `;
}



// Настройка обработчиков событий для страницы добавления шаблона
export function setupAddTemplateEventListeners() {
    // Сохранение шаблона
    const saveTemplateBtn = document.getElementById('save-template-btn');
    if (saveTemplateBtn) {
        saveTemplateBtn.addEventListener('click', async () => {
            const nameInput = document.getElementById('template-name');
            const descriptionInput = document.getElementById('template-description');
            
            if (!nameInput || !nameInput.value.trim()) {
                showMessage('Введите название шаблона', 'error');
                return;
            }
            
            const templateContent = getTemplateText();
            if (!templateContent.trim()) {
                showMessage('Введите содержимое шаблона', 'error');
                return;
            }
            
            try {
                await AddTemplate(nameInput.value.trim(), templateContent);
                showMessage('Шаблон успешно сохранен', 'success');
                
                // Возвращаемся к списку шаблонов
                setTimeout(() => {
                    window.dispatchEvent(new CustomEvent('showTemplatesView'));
                }, 1000);
                
            } catch (error) {
                console.error('Ошибка сохранения шаблона:', error);
                showMessage('Ошибка сохранения шаблона: ' + error.message, 'error');
            }
        });
    }
    
    // Валидация названия в реальном времени
    const nameInput = document.getElementById('template-name');
    if (nameInput) {
        nameInput.addEventListener('input', () => {
            const saveBtn = document.getElementById('save-template-btn');
            if (saveBtn) {
                saveBtn.disabled = !nameInput.value.trim();
            }
        });
    }
}

// Инициализация страницы добавления шаблона
export function initializeAddTemplatePage() {
    // Инициализируем Monaco Editor для шаблонов с задержкой
    setTimeout(() => {
        initializeTemplateEditor();
        
        // Устанавливаем базовый шаблон
        const defaultTemplate = `# Техническое задание

## Общее описание
{{USER_INPUT}}

## Функциональные требования
Описать основные функции системы...

## Нефункциональные требования
- Производительность
- Безопасность  
- Надежность

## Технические требования
Указать технологии и архитектуру...

## Критерии приемки
Перечислить условия готовности...

---
*Документ создан: {{CURRENT_DATE}}*
*Подготовлено: {{SYSTEM_ROLE}}*`;

        // Устанавливаем содержимое в редактор
        if (appState.templateEditor) {
            appState.templateEditor.setValue(defaultTemplate);
        } else {
            // Fallback для текстовой области
            const fallbackInput = document.getElementById('fallback-template-input');
            if (fallbackInput) {
                fallbackInput.value = defaultTemplate;
            }
            
            // Попробуем найти textarea в контейнере Monaco
            const fallbackTextarea = document.querySelector('#monaco-template-editor-container textarea');
            if (fallbackTextarea) {
                fallbackTextarea.value = defaultTemplate;
            }
        }
    }, 100);
}
