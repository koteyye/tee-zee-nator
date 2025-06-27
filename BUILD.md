# Инструкции по сборке и запуску

## Сборка приложения

### 1. Убедитесь, что установлены зависимости:
```bash
# Установка Wails (если не установлен)
go install github.com/wailsapp/wails/v2/cmd/wails@latest

# Установка зависимостей frontend (выполняется автоматически при сборке)
cd frontend
npm install
cd ..
```

### 2. Сборка приложения:
```bash
# Сборка для продакшена
wails build

# Сборка с дополнительными флагами
wails build -clean -upx -tags production
```

### 3. Готовое приложение:
После сборки исполняемый файл будет находиться в:
- **Windows:** `build/bin/my-ai-gen.exe`
- **macOS:** `build/bin/my-ai-gen.app`
- **Linux:** `build/bin/my-ai-gen`

## Запуск в режиме разработки

```bash
# Запуск с hot-reload
wails dev

# Запуск с отладкой
wails dev -devtools
```

## Тестирование приложения

### 1. Запустите собранное приложение:
- Windows: Двойной клик на `build/bin/my-ai-gen.exe`
- Или из командной строки: `.\build\bin\my-ai-gen.exe`

### 2. Настройка при первом запуске:
1. **URL API:** Оставьте по умолчанию `https://api.openai.com/v1` или введите URL вашего провайдера
2. **API Key:** Введите ваш OpenAI API ключ (sk-...)
3. Нажмите **"Проверить подключение"**
4. При успехе нажмите **"Сохранить конфигурацию"**
5. Выберите модель из списка (например, gpt-3.5-turbo или gpt-4)
6. Нажмите **"Продолжить"**

### 3. Проверка работы:
- Конфиг должен сохраниться в системную папку
- При повторном запуске приложение должно сразу открыться на основном экране
- В настройках можно изменить API ключ или модель

## Структура файлов конфигурации

Конфигурация сохраняется в формате JSON:
```json
{
  "api_url": "https://api.openai.com/v1",
  "api_key": "sk-ваш-api-ключ",
  "last_used_model": "gpt-3.5-turbo"
}
```

**Расположение файла:**
- **Windows:** `%APPDATA%\my-ai-gen\config.json`
- **macOS:** `~/Library/Application Support/my-ai-gen/config.json`
- **Linux:** `~/.config/my-ai-gen/config.json`

## Устранение неполадок

### Ошибка "npm not found":
```bash
# Установите Node.js
winget install OpenJS.NodeJS
# Или скачайте с https://nodejs.org/

# Перезапустите терминал или обновите PATH
$env:PATH += ";C:\Program Files\nodejs"
```

### Ошибка выполнения PowerShell скриптов:
```bash
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Ошибка "wails command not found":
```bash
# Убедитесь, что GOPATH/bin в PATH
go install github.com/wailsapp/wails/v2/cmd/wails@latest
```

### API ошибки:
- **401 Unauthorized:** Проверьте правильность API ключа
- **404 Not Found:** Проверьте URL API провайдера
- **Network errors:** Проверьте подключение к интернету

## Кроссплатформенная сборка

### Сборка для Windows (из любой ОС):
```bash
wails build -platform windows/amd64
```

### Сборка для macOS (только с macOS):
```bash
wails build -platform darwin/amd64
wails build -platform darwin/arm64
```

### Сборка для Linux:
```bash
wails build -platform linux/amd64
```

## Вызов функций из frontend

Все Go функции доступны через импорт:
```javascript
import {
    GetConfig,
    IsConfigured,
    SaveConfig,
    ValidateAndGetModels,
    GetModels,
    TestConnection,
    UpdateLastUsedModel
} from '../wailsjs/go/main/App';

// Пример использования
const config = await GetConfig();
const models = await ValidateAndGetModels("https://api.openai.com/v1", "sk-...");
```

Биндинги автоматически генерируются при сборке в папке `frontend/wailsjs/`.
