package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
)

// Config представляет конфигурацию приложения
type Config struct {
	APIURL        string `json:"api_url"`         // URL API-провайдера
	APIKey        string `json:"api_key"`         // Токен доступа
	LastUsedModel string `json:"last_used_model"` // Последняя используемая модель
}

// ConfigManager управляет конфигурацией приложения
type ConfigManager struct {
	configPath string
	config     *Config
}

// NewConfigManager создает новый менеджер конфигурации
func NewConfigManager() *ConfigManager {
	return &ConfigManager{
		configPath: getConfigPath(),
		config:     &Config{},
	}
}

// getConfigPath возвращает путь к файлу конфигурации в зависимости от ОС
func getConfigPath() string {
	var configDir string

	switch runtime.GOOS {
	case "windows":
		// Windows: %APPDATA%/TeeZeeNator/config.json
		configDir = os.Getenv("APPDATA")
		if configDir == "" {
			// Fallback на %USERPROFILE%\AppData\Roaming
			userProfile := os.Getenv("USERPROFILE")
			configDir = filepath.Join(userProfile, "AppData", "Roaming")
		}
	case "darwin":
		// macOS: ~/Library/Application Support/TeeZeeNator/config.json
		homeDir, _ := os.UserHomeDir()
		configDir = filepath.Join(homeDir, "Library", "Application Support")
	default:
		// Linux и другие Unix-системы: ~/.config/TeeZeeNator/config.json
		homeDir, _ := os.UserHomeDir()
		configDir = filepath.Join(homeDir, ".config")
	}

	appConfigDir := filepath.Join(configDir, "TeeZeeNator")
	return filepath.Join(appConfigDir, "config.json")
}

// LoadConfig загружает конфигурацию из файла
func (cm *ConfigManager) LoadConfig() error {
	// Проверяем, существует ли файл конфигурации
	if _, err := os.Stat(cm.configPath); os.IsNotExist(err) {
		// Файл не существует, создаем конфигурацию по умолчанию
		cm.config = &Config{
			APIURL:        "https://api.openai.com/v1",
			APIKey:        "",
			LastUsedModel: "",
		}
		return nil
	}

	// Читаем файл конфигурации
	data, err := os.ReadFile(cm.configPath)
	if err != nil {
		return fmt.Errorf("ошибка чтения файла конфигурации: %w", err)
	}

	// Парсим JSON
	err = json.Unmarshal(data, cm.config)
	if err != nil {
		return fmt.Errorf("ошибка парсинга конфигурации: %w", err)
	}

	return nil
}

// SaveConfig сохраняет конфигурацию в файл
func (cm *ConfigManager) SaveConfig() error {
	// Создаем директорию, если она не существует
	configDir := filepath.Dir(cm.configPath)
	err := os.MkdirAll(configDir, 0755)
	if err != nil {
		return fmt.Errorf("ошибка создания директории конфигурации: %w", err)
	}

	// Сериализуем конфигурацию в JSON
	data, err := json.MarshalIndent(cm.config, "", "  ")
	if err != nil {
		return fmt.Errorf("ошибка сериализации конфигурации: %w", err)
	}

	// Записываем в файл
	err = os.WriteFile(cm.configPath, data, 0644)
	if err != nil {
		return fmt.Errorf("ошибка записи файла конфигурации: %w", err)
	}

	return nil
}

// GetConfig возвращает текущую конфигурацию
func (cm *ConfigManager) GetConfig() *Config {
	return cm.config
}

// UpdateConfig обновляет конфигурацию
func (cm *ConfigManager) UpdateConfig(apiURL, apiKey, lastUsedModel string) error {
	cm.config.APIURL = apiURL
	cm.config.APIKey = apiKey
	if lastUsedModel != "" {
		cm.config.LastUsedModel = lastUsedModel
	}
	return cm.SaveConfig()
}

// IsConfigured проверяет, настроена ли конфигурация
func (cm *ConfigManager) IsConfigured() bool {
	return cm.config.APIKey != ""
}
