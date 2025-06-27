package main

import (
	"embed"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

//go:embed template/tz_pattern.md
var defaultTemplate embed.FS

//go:embed build/templates/*
var bundledTemplates embed.FS

// Template представляет шаблон ТЗ
type Template struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Content   string `json:"content"`
	IsDefault bool   `json:"is_default"`
}

// TemplateManager управляет шаблонами ТЗ
type TemplateManager struct {
	templatesPath string
	templates     []Template
}

// NewTemplateManager создает новый менеджер шаблонов
func NewTemplateManager() *TemplateManager {
	configDir := getConfigPath()
	templatesPath := filepath.Join(filepath.Dir(configDir), "templates.json")

	return &TemplateManager{
		templatesPath: templatesPath,
		templates:     []Template{},
	}
}

// LoadTemplates загружает шаблоны из файла
func (tm *TemplateManager) LoadTemplates() error {
	// Загружаем дефолтный шаблон
	defaultContent, err := defaultTemplate.ReadFile("template/tz_pattern.md")
	if err != nil {
		return fmt.Errorf("ошибка загрузки дефолтного шаблона: %w", err)
	}

	defaultTpl := Template{
		ID:        "default",
		Name:      "Стандартный шаблон ТЗ",
		Content:   string(defaultContent),
		IsDefault: true,
	}

	// Инициализируем список с дефолтным шаблоном
	tm.templates = []Template{defaultTpl}

	// Проверяем, существует ли файл с пользовательскими шаблонами
	if _, err := os.Stat(tm.templatesPath); os.IsNotExist(err) {
		// Файл не существует, создаем его с дефолтным шаблоном
		return tm.SaveTemplates()
	}

	// Читаем файл с шаблонами
	data, err := os.ReadFile(tm.templatesPath)
	if err != nil {
		return fmt.Errorf("ошибка чтения файла шаблонов: %w", err)
	}

	var savedTemplates []Template
	err = json.Unmarshal(data, &savedTemplates)
	if err != nil {
		return fmt.Errorf("ошибка парсинга шаблонов: %w", err)
	}

	// Добавляем пользовательские шаблоны к дефолтному
	for _, tpl := range savedTemplates {
		if !tpl.IsDefault { // Исключаем дефолтный шаблон из файла
			tm.templates = append(tm.templates, tpl)
		}
	}

	return nil
}

// SaveTemplates сохраняет шаблоны в файл
func (tm *TemplateManager) SaveTemplates() error {
	// Создаем директорию, если она не существует
	templatesDir := filepath.Dir(tm.templatesPath)
	err := os.MkdirAll(templatesDir, 0755)
	if err != nil {
		return fmt.Errorf("ошибка создания директории шаблонов: %w", err)
	}

	// Отфильтровываем только пользовательские шаблоны для сохранения
	var userTemplates []Template
	for _, tpl := range tm.templates {
		if !tpl.IsDefault {
			userTemplates = append(userTemplates, tpl)
		}
	}

	// Сериализуем только пользовательские шаблоны в JSON
	data, err := json.MarshalIndent(userTemplates, "", "  ")
	if err != nil {
		return fmt.Errorf("ошибка сериализации шаблонов: %w", err)
	}

	// Записываем в файл
	err = os.WriteFile(tm.templatesPath, data, 0644)
	if err != nil {
		return fmt.Errorf("ошибка записи файла шаблонов: %w", err)
	}

	return nil
}

// GetTemplates возвращает список всех шаблонов
func (tm *TemplateManager) GetTemplates() []Template {
	return tm.templates
}

// GetTemplate возвращает шаблон по ID
func (tm *TemplateManager) GetTemplate(id string) (*Template, error) {
	for _, tpl := range tm.templates {
		if tpl.ID == id {
			return &tpl, nil
		}
	}
	return nil, fmt.Errorf("шаблон с ID '%s' не найден", id)
}

// AddTemplate добавляет новый шаблон
func (tm *TemplateManager) AddTemplate(name, content string) error {
	// Генерируем ID для нового шаблона
	id := fmt.Sprintf("custom_%d", len(tm.templates))

	newTemplate := Template{
		ID:        id,
		Name:      name,
		Content:   content,
		IsDefault: false,
	}

	tm.templates = append(tm.templates, newTemplate)
	return tm.SaveTemplates()
}

// DeleteTemplate удаляет шаблон (кроме дефолтного)
func (tm *TemplateManager) DeleteTemplate(id string) error {
	if id == "default" {
		return fmt.Errorf("нельзя удалить дефолтный шаблон")
	}

	for i, tpl := range tm.templates {
		if tpl.ID == id {
			tm.templates = append(tm.templates[:i], tm.templates[i+1:]...)
			return tm.SaveTemplates()
		}
	}

	return fmt.Errorf("шаблон с ID '%s' не найден", id)
}

// InitializeTemplatesDirectory создает каталог templates рядом с exe и копирует туда дефолтные шаблоны
func (tm *TemplateManager) InitializeTemplatesDirectory() error {
	// Получаем путь к исполняемому файлу
	exePath, err := os.Executable()
	if err != nil {
		return fmt.Errorf("ошибка получения пути к исполняемому файлу: %w", err)
	}

	// Создаем каталог templates рядом с exe
	templatesDir := filepath.Join(filepath.Dir(exePath), "templates")
	err = os.MkdirAll(templatesDir, 0755)
	if err != nil {
		return fmt.Errorf("ошибка создания каталога templates: %w", err)
	}

	// Копируем дефолтный шаблон
	defaultTemplatePath := filepath.Join(templatesDir, "default_template.md")
	if _, err := os.Stat(defaultTemplatePath); os.IsNotExist(err) {
		// Читаем содержимое из embedded файлов
		content, err := bundledTemplates.ReadFile("build/templates/default_template.md")
		if err != nil {
			// Если bundled шаблон не найден, используем embedded
			content, err = defaultTemplate.ReadFile("template/tz_pattern.md")
			if err != nil {
				return fmt.Errorf("ошибка чтения дефолтного шаблона: %w", err)
			}
		}

		// Записываем файл
		err = os.WriteFile(defaultTemplatePath, content, 0644)
		if err != nil {
			return fmt.Errorf("ошибка записи дефолтного шаблона: %w", err)
		}
	}

	return nil
}
