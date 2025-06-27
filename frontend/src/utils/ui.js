// Утилиты для работы с UI

// Показать сообщение
export function showMessage(text, type = 'success') {
    const container = document.getElementById('message-container');
    if (!container) return;
    
    let messageClass = 'message-success';
    if (type === 'error') {
        messageClass = 'message-error';
    } else if (type === 'info') {
        messageClass = 'message-info';
    }
    
    container.innerHTML = `<div class="message ${messageClass}">${text}</div>`;
    
    // Автоматически скрыть через 5 секунд
    setTimeout(() => {
        container.innerHTML = '';
    }, 5000);
}

// Форматирование Markdown
export function formatMarkdown(text) {
    try {
        // Проверяем, что text это строка
        if (typeof text !== 'string') {
            console.warn('formatMarkdown получил не строку:', text);
            return '';
        }
        
        if (typeof marked === 'undefined') {
            return text.replace(/\n/g, '<br>').replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
        }
        
        marked.setOptions({
            breaks: true,
            gfm: true
        });
        
        return marked.parse(text);
    } catch (error) {
        console.error('Ошибка рендеринга Markdown:', error);
        return typeof text === 'string' ? text.replace(/\n/g, '<br>') : '';
    }
}

// Заполнение селектора моделей
export function populateModelSelect(selectId, models, selectedModel = null) {
    const select = document.getElementById(selectId);
    if (!select) return;
    
    // Очищаем текущие опции
    select.innerHTML = '<option value="">Выберите модель...</option>';
    
    // Добавляем модели
    models.forEach(model => {
        const option = document.createElement('option');
        option.value = model.id;
        option.textContent = `${model.id} (${model.owned_by})`;
        
        if (selectedModel && model.id === selectedModel) {
            option.selected = true;
        }
        
        select.appendChild(option);
    });
}

// Заполнение селектора шаблонов
export function populateTemplateSelect(selectId, templates, selectedTemplate = null) {
    const select = document.getElementById(selectId);
    if (!select) return;
    
    // Очищаем текущие опции
    select.innerHTML = '<option value="">Выберите шаблон...</option>';
    
    // Добавляем шаблоны
    templates.forEach(template => {
        const option = document.createElement('option');
        option.value = template.id;
        option.textContent = template.name;
        
        if (selectedTemplate && template.id === selectedTemplate) {
            option.selected = true;
        }
        
        select.appendChild(option);
    });
}
