// Утилиты для работы с Monaco Editor
import { appState } from './appState.js';

// Инициализация Monaco Editor
export function initializeMonacoEditor() {
    const container = document.getElementById('monaco-editor-container');
    if (!container) {
        console.error('Контейнер monaco-editor-container не найден');
        return;
    }
    
    // Функция для создания Monaco Editor
    const createEditor = () => {
        try {
            // Очищаем контейнер перед созданием нового редактора
            container.innerHTML = '';
            
            // Убираем предыдущий редактор если есть
            if (appState.monacoEditor) {
                appState.monacoEditor.dispose();
                appState.monacoEditor = null;
            }
            
            console.log('Создаем Monaco Editor...');
            
            appState.monacoEditor = monaco.editor.create(container, {
                value: 'Например:\n\nНужна система для управления задачами команды разработчиков. Должна быть веб-версия и мобильное приложение. Нужна авторизация, создание проектов, назначение задач, трекинг времени.',
                language: 'markdown',
                theme: 'vs',
                minimap: { enabled: false },
                scrollBeyondLastLine: false,
                fontSize: 14,
                lineHeight: 20,
                wordWrap: 'on',
                automaticLayout: true,
                padding: { top: 16, bottom: 16 },
                overviewRulerBorder: false,
                hideCursorInOverviewRuler: true,
                overviewRulerLanes: 0,
                renderLineHighlight: 'none',
                selectionHighlight: false,
                roundedSelection: false,
                occurrencesHighlight: false,
                readOnly: false // Убеждаемся, что редактор не только для чтения
            });
            
            console.log('Monaco Editor успешно создан!');
            console.log('Readonly:', appState.monacoEditor.getOption(monaco.editor.EditorOption.readOnly));
            console.log('Размеры контейнера:', container.offsetWidth, 'x', container.offsetHeight);
            
            // Устанавливаем фокус на редактор
            setTimeout(() => {
                if (appState.monacoEditor) {
                    appState.monacoEditor.focus();
                    console.log('Фокус установлен на Monaco Editor');
                }
            }, 100);
            
        } catch (error) {
            console.error('Ошибка создания Monaco Editor:', error);
            console.error('Fallback НЕ используется - только Monaco Editor!');
        }
    };
    
    // Проверяем, что Monaco Editor загружен
    if (typeof monaco !== 'undefined') {
        console.log('Monaco Editor уже доступен, создаем редактор');
        createEditor();
    } else {
        console.log('Ожидание загрузки Monaco Editor...');
        // Ждем события загрузки Monaco Editor
        const handleMonacoReady = () => {
            console.log('Получено событие monacoReady');
            createEditor();
            window.removeEventListener('monacoReady', handleMonacoReady);
        };
        
        window.addEventListener('monacoReady', handleMonacoReady);
        
        // Дополнительная проверка через интервал
        const checkInterval = setInterval(() => {
            if (typeof monaco !== 'undefined') {
                console.log('Monaco Editor загружен через проверку интервала');
                clearInterval(checkInterval);
                createEditor();
                window.removeEventListener('monacoReady', handleMonacoReady);
            }
        }, 200);
        
        // Таймаут для отладки
        setTimeout(() => {
            if (typeof monaco === 'undefined') {
                console.error('Monaco Editor не загружен после 5 секунд ожидания!');
                clearInterval(checkInterval);
            }
        }, 5000);
    }
}

// Инициализация Monaco Editor для шаблонов
export function initializeTemplateEditor() {
    const container = document.getElementById('monaco-template-editor-container');
    if (!container) {
        console.error('Контейнер monaco-template-editor-container не найден');
        return;
    }
    
    // Проверяем, что Monaco Editor загружен
    if (typeof monaco === 'undefined') {
        console.error('Monaco Editor не загружен для шаблонов');
        createFallbackTemplateTextarea(container);
        return;
    }
    
    try {
        appState.templateEditor = monaco.editor.create(container, {
            value: '# Новый шаблон\n\n## Раздел 1\n\n[Описание раздела]\n\n## Раздел 2\n\n[Описание раздела]',
            language: 'markdown',
            theme: 'vs',
            minimap: { enabled: false },
            scrollBeyondLastLine: false,
            fontSize: 14,
            lineHeight: 20,
            wordWrap: 'on',
            automaticLayout: true,
            padding: { top: 16, bottom: 16 },
            overviewRulerBorder: false,
            hideCursorInOverviewRuler: true,
            overviewRulerLanes: 0,
            renderLineHighlight: 'none',
            selectionHighlight: false,
            roundedSelection: false,
            occurrencesHighlight: false
        });
        
        console.log('Monaco Editor для шаблонов инициализирован');
    } catch (error) {
        console.error('Ошибка инициализации Monaco Editor для шаблонов:', error);
        createFallbackTemplateTextarea(container);
    }
}

// Fallback textarea
function createFallbackTextarea(container) {
    container.innerHTML = `
        <textarea 
            id="fallback-input" 
            class="text-input" 
            style="width: 100%; min-height: 200px; border: 2px solid var(--color-gray-300); border-radius: 8px; padding: 16px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; font-size: 14px; resize: vertical; background: white;"
            placeholder="Например:

Нужна система для управления задачами команды разработчиков. Должна быть веб-версия и мобильное приложение. Нужна авторизация, создание проектов, назначение задач, трекинг времени."
        ></textarea>
    `;
    console.log('Создан fallback textarea для ввода требований');
    
    // Убеждаемся, что textarea доступна для редактирования
    setTimeout(() => {
        const textarea = document.getElementById('fallback-input');
        if (textarea) {
            textarea.removeAttribute('readonly');
            textarea.removeAttribute('disabled');
            console.log('Fallback textarea готова к редактированию');
        }
    }, 50);
}

// Fallback textarea для шаблонов
function createFallbackTemplateTextarea(container) {
    container.innerHTML = `
        <textarea 
            id="fallback-template-input" 
            class="text-input" 
            style="width: 100%; min-height: 400px; border: none; resize: vertical;"
            placeholder="# Новый шаблон

## Раздел 1

[Описание раздела]

## Раздел 2

[Описание раздела]"
        ></textarea>
    `;
    console.log('Использован fallback textarea для шаблонов');
}

// Получение текста из редактора
export function getInputText() {
    if (appState.monacoEditor) {
        const text = appState.monacoEditor.getValue().trim();
        console.log('Получен текст из Monaco Editor:', text.length, 'символов');
        return text;
    } else {
        console.error('Monaco Editor не инициализирован!');
        return '';
    }
}

// Получение текста из редактора шаблонов
export function getTemplateText() {
    if (appState.templateEditor) {
        return appState.templateEditor.getValue().trim();
    } else {
        const fallbackInput = document.getElementById('fallback-template-input');
        return fallbackInput ? fallbackInput.value.trim() : '';
    }
}
