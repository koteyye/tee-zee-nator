package main

import (
	"context"
	"fmt"
)

// App struct
type App struct {
	ctx             context.Context
	configManager   *ConfigManager
	templateManager *TemplateManager
}

// NewApp creates a new App application struct
func NewApp() *App {
	return &App{
		configManager:   NewConfigManager(),
		templateManager: NewTemplateManager(),
	}
}

// startup is called when the app starts. The context is saved
// so we can call the runtime methods
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx

	// Инициализируем каталог templates
	err := a.templateManager.InitializeTemplatesDirectory()
	if err != nil {
		fmt.Printf("Ошибка инициализации каталога templates: %v\n", err)
	}

	// Загружаем конфигурацию при запуске
	err = a.configManager.LoadConfig()
	if err != nil {
		fmt.Printf("Ошибка загрузки конфигурации: %v\n", err)
	}

	// Загружаем шаблоны при запуске
	err = a.templateManager.LoadTemplates()
	if err != nil {
		fmt.Printf("Ошибка загрузки шаблонов: %v\n", err)
	}
}

// GetConfig возвращает текущую конфигурацию
func (a *App) GetConfig() *Config {
	return a.configManager.GetConfig()
}

// IsConfigured проверяет, настроена ли конфигурация
func (a *App) IsConfigured() bool {
	return a.configManager.IsConfigured()
}

// SaveConfig сохраняет конфигурацию
func (a *App) SaveConfig(apiURL, apiKey, lastUsedModel string) error {
	return a.configManager.UpdateConfig(apiURL, apiKey, lastUsedModel)
}

// ValidateAndGetModels валидирует конфигурацию API и возвращает список моделей
func (a *App) ValidateAndGetModels(apiURL, apiKey string) ([]Model, error) {
	return ValidateConfig(apiURL, apiKey)
}

// GetModels получает список моделей с текущей конфигурацией
func (a *App) GetModels() ([]Model, error) {
	config := a.configManager.GetConfig()
	if !a.configManager.IsConfigured() {
		return nil, fmt.Errorf("API не настроен")
	}

	client := NewOpenAIClient(config.APIURL, config.APIKey)
	return client.GetModels()
}

// TestConnection тестирует подключение к API
func (a *App) TestConnection() error {
	config := a.configManager.GetConfig()
	if !a.configManager.IsConfigured() {
		return fmt.Errorf("API не настроен")
	}

	client := NewOpenAIClient(config.APIURL, config.APIKey)
	return client.TestConnection()
}

// UpdateLastUsedModel обновляет последнюю используемую модель
func (a *App) UpdateLastUsedModel(modelID string) error {
	config := a.configManager.GetConfig()
	return a.configManager.UpdateConfig(config.APIURL, config.APIKey, modelID)
}

// GenerateRequirements генерирует технические требования на основе пользовательского ввода и шаблона
func (a *App) GenerateRequirements(userInput, templateID string) (string, error) {
	config := a.configManager.GetConfig()
	if !a.configManager.IsConfigured() {
		return "", fmt.Errorf("API не настроен")
	}

	if config.LastUsedModel == "" {
		return "", fmt.Errorf("модель не выбрана")
	}

	if userInput == "" {
		return "", fmt.Errorf("введите описание для генерации требований")
	}

	// Получаем шаблон
	template, err := a.templateManager.GetTemplate(templateID)
	if err != nil {
		return "", fmt.Errorf("ошибка получения шаблона: %w", err)
	}

	client := NewOpenAIClient(config.APIURL, config.APIKey)
	return client.GenerateRequirements(userInput, config.LastUsedModel, template.Content)
}

// Greet returns a greeting for the given name (оставляем для совместимости)
func (a *App) Greet(name string) string {
	return fmt.Sprintf("Привет %s! Добро пожаловать в AI Requirements Generator!", name)
}

// === Методы для работы с шаблонами ===

// GetTemplates возвращает список всех шаблонов
func (a *App) GetTemplates() []Template {
	return a.templateManager.GetTemplates()
}

// GetTemplate возвращает шаблон по ID
func (a *App) GetTemplate(id string) (*Template, error) {
	return a.templateManager.GetTemplate(id)
}

// AddTemplate добавляет новый шаблон
func (a *App) AddTemplate(name, content string) error {
	if name == "" {
		return fmt.Errorf("название шаблона не может быть пустым")
	}
	if content == "" {
		return fmt.Errorf("содержимое шаблона не может быть пустым")
	}
	return a.templateManager.AddTemplate(name, content)
}

// DeleteTemplate удаляет шаблон
func (a *App) DeleteTemplate(id string) error {
	return a.templateManager.DeleteTemplate(id)
}

// GetDefaultTemplate возвращает дефолтный шаблон
func (a *App) GetDefaultTemplate() (*Template, error) {
	return a.templateManager.GetTemplate("default")
}
