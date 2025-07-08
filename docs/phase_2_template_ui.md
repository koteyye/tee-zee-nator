# План реализации пользовательских шаблонов (Этап 2)

## Анализ текущего проекта

### Архитектура проекта
TeeZeeNator построен на Flutter/Dart с использованием Provider для управления состоянием. Основные компоненты:

- **Модели данных**: `AppConfig`, `OpenAIModel`, `ChatMessage`, `GenerationHistory`
- **Сервисы**: `ConfigService` (конфигурация), `OpenAIService` (API взаимодействие), `FileService` (работа с файлами)
- **Экраны**: `MainScreen` (основной), `SetupScreen` (настройки), `TransformerTestScreen` (тестирование)
- **Виджеты**: модульная структура с отдельными компонентами UI
- **Хранение**: Hive для локального хранения конфигурации

### Текущий функционал шаблонов
- Базовый шаблон загружается из файла `tz_pattern.md`
- Переключатель "Использовать шаблон ТЗ" в `ModelSettingsCard`
- Жестко закодированная логика выбора шаблона в `OpenAIService`

---

## Детальный план изменений

### 1. Модели данных

#### 1.1 Новая модель `Template`
**Файл**: `lib/models/template.dart`
```dart
@HiveType(typeId: 3)
@JsonSerializable()
class Template {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  final String name;
  
  @HiveField(2)
  final String content;
  
  @HiveField(3)
  final bool isDefault;
  
  @HiveField(4)
  final DateTime createdAt;
  
  @HiveField(5)
  final DateTime? updatedAt;
}
```

#### 1.2 Обновление `AppConfig`
**Файл**: `lib/models/app_config.dart`
- Добавить поле `reviewModel` для модели ревью шаблонов
- Добавить поле `selectedTemplateId` для активного шаблона
- Переименовать `selectedModel` в `defaultModel`

### 2. Сервисы

#### 2.1 Новый сервис `TemplateService`
**Файл**: `lib/services/template_service.dart`

**Функциональность**:
- CRUD операции с шаблонами
- Загрузка дефолтного шаблона из `tz_pattern.md`
- Валидация шаблонов
- Управление активным шаблоном

**Основные методы**:
```dart
class TemplateService extends ChangeNotifier {
  Future<void> init();
  Future<List<Template>> getAllTemplates();
  Future<Template?> getActiveTemplate();
  Future<void> saveTemplate(Template template);
  Future<void> deleteTemplate(String id);
  Future<void> setActiveTemplate(String id);
  Future<String> reviewTemplate(String content, AppConfig config);
}
```

#### 2.2 Обновление `OpenAIService`
**Файл**: `lib/services/openai_service.dart`

**Изменения**:
- Добавить метод `reviewTemplate()` для ревью шаблонов
- Обновить `generateTZ()` для работы с пользовательскими шаблонами
- Системный промт для ревью:
```dart
const String TEMPLATE_REVIEW_PROMPT = '''
Ты главный методолог требований, тебе нужно провести ревью шаблона и выдать все замечания, вопросы (если они есть) и предложения по оптимизации шаблона.
Обязательно выдели есть ли КРИТИЧЕСКИЕ замечания к шаблону. При наличии критических замечаний введи в ответ текст "[CRITICAL_ALERT]"
''';
```

#### 2.3 Обновление `ConfigService`
**Файл**: `lib/services/config_service.dart`

**Изменения**:
- Поддержка новых полей в `AppConfig`
- Методы для работы с моделью ревью

### 3. UI компоненты

#### 3.1 Новый экран `TemplateManagementScreen`
**Файл**: `lib/screens/template_management_screen.dart`

**Компоненты экрана**:
- Заголовок с кнопкой закрытия
- Выбор модели для ревью (дропдаун)
- Селектор шаблонов (дропдаун)
- Многострочное поле ввода контента
- Кнопки "Ревью шаблона", "Сохранить", "Закрыть"
- Переключатель "Игнорировать ревью"
- Область отображения результатов ревью

#### 3.2 Диалог подтверждения `TemplateReviewDialog`
**Файл**: `lib/widgets/template_management/template_review_dialog.dart`

**Функциональность**:
- Отображение результатов ревью
- Подсветка критических замечаний
- Кнопки действий

#### 3.3 Виджет `TemplateSelector`
**Файл**: `lib/widgets/template_management/template_selector.dart`

**Функциональность**:
- Дропдаун для выбора шаблона
- Отображение названий шаблонов
- Обработка изменений выбора

#### 3.4 Обновление `ModelSettingsCard`
**Файл**: `lib/widgets/main_screen/model_settings_card.dart`

**Изменения**:
- Заменить Switch на TemplateSelector
- Добавить кнопку "Шаблоны ТЗ" рядом с настройками

#### 3.5 Обновление главного меню `MainScreen`
**Файл**: `lib/screens/main_screen.dart`

**Изменения в AppBar**:
```dart
actions: [
  IconButton(
    icon: const Icon(Icons.description),
    onPressed: () => _openTemplateManagement(),
    tooltip: 'Шаблоны ТЗ',
  ),
  IconButton(
    icon: const Icon(Icons.settings),
    onPressed: () => _openSettings(),
    tooltip: 'Настройки',
  ),
],
```

### 4. Структура файлов

#### 4.1 Новые файлы
```
lib/
├── models/
│   └── template.dart                      # Модель шаблона
│   └── template.g.dart                    # Сгенерированный код
├── services/
│   └── template_service.dart              # Сервис работы с шаблонами
├── screens/
│   └── template_management_screen.dart    # Экран управления шаблонами
└── widgets/
    └── template_management/
        ├── template_selector.dart         # Селектор шаблонов
        ├── template_review_dialog.dart    # Диалог ревью
        ├── template_content_editor.dart   # Редактор контента
        └── review_model_selector.dart     # Селектор модели ревью
```

#### 4.2 Обновляемые файлы
```
lib/
├── models/
│   └── app_config.dart                    # Добавить поля для шаблонов
├── services/
│   ├── config_service.dart                # Поддержка новых полей
│   └── openai_service.dart                # Метод ревью шаблонов
├── screens/
│   └── main_screen.dart                   # Кнопка "Шаблоны ТЗ"
└── widgets/main_screen/
    └── model_settings_card.dart           # Замена Switch на Selector
```

### 5. Логика работы

#### 5.1 Инициализация шаблонов
1. При первом запуске загружается дефолтный шаблон из `tz_pattern.md`
2. Создается запись в базе с `isDefault: true`
3. Устанавливается как активный шаблон

#### 5.2 Управление шаблонами
1. **Создание нового шаблона**:
   - Пользователь создает копию дефолтного или пустой шаблон
   - Редактирует контент
   - Проводит ревью (опционально)
   - Сохраняет

2. **Ревью шаблона**:
   - Отправляется запрос в LLM с системным промтом
   - Проверяется наличие `[CRITICAL_ALERT]`
   - Блокируется/разблокируется кнопка "Сохранить"

3. **Использование шаблона**:
   - На главном экране выбирается активный шаблон
   - При генерации ТЗ используется выбранный шаблон

#### 5.3 Интеграция с существующим функционалом
1. **Замена логики в `OpenAIService.generateTZ()`**:
```dart
// Вместо жестко закодированного шаблона
final templateService = Provider.of<TemplateService>(context, listen: false);
final activeTemplate = await templateService.getActiveTemplate();
final templateContent = activeTemplate?.content ?? defaultTemplate;
```

2. **Обновление UI состояния**:
```dart
// Замена bool _useBaseTemplate на String? _selectedTemplateId
String? _selectedTemplateId;
```

### 6. Хранение данных

#### 6.1 Структура Hive
```dart
// Новый бокс для шаблонов
Box<Template> templatesBox = await Hive.openBox<Template>('templates');

// Ключи:
// - 'default' - дефолтный шаблон
// - 'user_<uuid>' - пользовательские шаблоны
// - 'active_template_id' - ID активного шаблона
```

#### 6.2 Миграция данных
- Создание дефолтного шаблона при первом запуске
- Сохранение текущих настроек пользователя

### 7. Последовательность реализации

#### Этап 1: Базовая инфраструктура
1. Создать модель `Template` с генерацией кода
2. Создать `TemplateService` с базовым CRUD
3. Обновить `AppConfig` с новыми полями
4. Настроить Hive для работы с шаблонами

#### Этап 2: UI компоненты
1. Создать `TemplateManagementScreen`
2. Создать вспомогательные виджеты
3. Обновить главное меню

#### Этап 3: Интеграция
1. Обновить `OpenAIService` для ревью
2. Интегрировать выбор шаблона в главный экран
3. Обновить логику генерации ТЗ

#### Этап 4: Тестирование и полировка
1. Тестирование всех сценариев
2. Обработка ошибок
3. UX улучшения

---

## Оценка сложности

**Высокая сложность**: Требует изменений в архитектуре приложения, новых моделей данных, экранов и интеграции с существующим функционалом.

**Время реализации**: 2-3 недели для полной реализации.

**Риски**:
- Миграция данных пользователей
- Совместимость с существующими настройками
- Производительность при работе с большим количеством шаблонов

**Преимущества**:
- Значительное расширение функциональности
- Улучшение пользовательского опыта
- Гибкость в создании ТЗ под разные проекты
