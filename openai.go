package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// Model представляет модель из API
type Model struct {
	ID      string `json:"id"`
	Object  string `json:"object"`
	Created int64  `json:"created"`
	OwnedBy string `json:"owned_by"`
}

// ModelsResponse представляет ответ API со списком моделей
type ModelsResponse struct {
	Object string  `json:"object"`
	Data   []Model `json:"data"`
}

// ErrorResponse представляет ответ с ошибкой от API
type ErrorResponse struct {
	Error struct {
		Message string `json:"message"`
		Type    string `json:"type"`
		Code    string `json:"code"`
	} `json:"error"`
}

// OpenAIClient клиент для работы с OpenAI API
type OpenAIClient struct {
	BaseURL string
	APIKey  string
	client  *http.Client
}

// NewOpenAIClient создает новый клиент OpenAI API
func NewOpenAIClient(baseURL, apiKey string) *OpenAIClient {
	return &OpenAIClient{
		BaseURL: baseURL,
		APIKey:  apiKey,
		client: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// makeRequest выполняет HTTP-запрос к API
func (c *OpenAIClient) makeRequest(method, endpoint string, body []byte) ([]byte, error) {
	url := c.BaseURL + endpoint

	req, err := http.NewRequest(method, url, bytes.NewBuffer(body))
	if err != nil {
		return nil, fmt.Errorf("ошибка создания запроса: %w", err)
	}

	// Устанавливаем заголовки
	req.Header.Set("Authorization", "Bearer "+c.APIKey)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "TeeZeeNator/1.0")

	// Выполняем запрос
	resp, err := c.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("ошибка выполнения запроса: %w", err)
	}
	defer resp.Body.Close()

	// Читаем ответ
	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("ошибка чтения ответа: %w", err)
	}

	// Проверяем статус ответа
	if resp.StatusCode >= 400 {
		var errorResp ErrorResponse
		if err := json.Unmarshal(respBody, &errorResp); err == nil {
			return nil, fmt.Errorf("API ошибка (%d): %s", resp.StatusCode, errorResp.Error.Message)
		}
		return nil, fmt.Errorf("HTTP ошибка: %d - %s", resp.StatusCode, string(respBody))
	}

	return respBody, nil
}

// GetModels получает список доступных моделей
func (c *OpenAIClient) GetModels() ([]Model, error) {
	respBody, err := c.makeRequest("GET", "/models", nil)
	if err != nil {
		return nil, err
	}

	var modelsResp ModelsResponse
	err = json.Unmarshal(respBody, &modelsResp)
	if err != nil {
		return nil, fmt.Errorf("ошибка парсинга ответа: %w", err)
	}

	return modelsResp.Data, nil
}

// TestConnection проверяет подключение к API
func (c *OpenAIClient) TestConnection() error {
	_, err := c.GetModels()
	return err
}

// ValidateConfig проверяет валидность конфигурации API
func ValidateConfig(apiURL, apiKey string) ([]Model, error) {
	if apiURL == "" {
		return nil, fmt.Errorf("URL API не может быть пустым")
	}

	if apiKey == "" {
		return nil, fmt.Errorf("API ключ не может быть пустым")
	}

	client := NewOpenAIClient(apiURL, apiKey)
	models, err := client.GetModels()
	if err != nil {
		return nil, fmt.Errorf("ошибка валидации API: %w", err)
	}

	return models, nil
}

// GenerateRequest представляет запрос на генерацию требований
type GenerateRequest struct {
	Model       string    `json:"model"`
	Messages    []Message `json:"messages"`
	MaxTokens   int       `json:"max_tokens"`
	Temperature float64   `json:"temperature"`
	Stream      bool      `json:"stream"`
}

// Message представляет сообщение в чате
type Message struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// GenerateResponse представляет ответ от API генерации
type GenerateResponse struct {
	ID      string   `json:"id"`
	Object  string   `json:"object"`
	Created int64    `json:"created"`
	Model   string   `json:"model"`
	Choices []Choice `json:"choices"`
	Usage   Usage    `json:"usage"`
}

// Choice представляет вариант ответа
type Choice struct {
	Index        int     `json:"index"`
	Message      Message `json:"message"`
	FinishReason string  `json:"finish_reason"`
}

// Usage представляет информацию об использовании токенов
type Usage struct {
	PromptTokens     int `json:"prompt_tokens"`
	CompletionTokens int `json:"completion_tokens"`
	TotalTokens      int `json:"total_tokens"`
}

// GenerateRequirements генерирует технические требования на основе пользовательского ввода
func (c *OpenAIClient) GenerateRequirements(userInput, modelID, template string) (string, error) {
	// Создаем системный промпт для генерации технических требований
	systemPrompt := `Ты - опытный системный аналитик и эксперт по техническому писательству. 
Твоя задача - преобразовать "сырое" описание пользователя в структурированные технические требования по заданному шаблону.

ОБЯЗАТЕЛЬНО используй следующий шаблон для формирования требований:

` + template + `

ВАЖНО:
- Следуй структуре шаблона точно
- Заполни все разделы конкретной информацией на основе пользовательского ввода
- Если какой-то раздел неприменим, укажи "Не применимо" или "Определяется на этапе проектирования"
- Отвечай только на русском языке
- Будь конкретным и избегай общих фраз
- Используй профессиональную терминологию`

	request := GenerateRequest{
		Model: modelID,
		Messages: []Message{
			{
				Role:    "system",
				Content: systemPrompt,
			},
			{
				Role:    "user",
				Content: "Создай технические требования по шаблону для следующего описания: " + userInput,
			},
		},
		MaxTokens:   3000,
		Temperature: 0.7,
		Stream:      false,
	}

	// Сериализуем запрос
	requestBody, err := json.Marshal(request)
	if err != nil {
		return "", fmt.Errorf("ошибка сериализации запроса: %w", err)
	}

	// Выполняем запрос
	respBody, err := c.makeRequest("POST", "/chat/completions", requestBody)
	if err != nil {
		return "", err
	}

	// Парсим ответ
	var generateResp GenerateResponse
	err = json.Unmarshal(respBody, &generateResp)
	if err != nil {
		return "", fmt.Errorf("ошибка парсинга ответа: %w", err)
	}

	// Проверяем наличие choices
	if len(generateResp.Choices) == 0 {
		return "", fmt.Errorf("API не вернул вариантов ответа")
	}

	return generateResp.Choices[0].Message.Content, nil
}
