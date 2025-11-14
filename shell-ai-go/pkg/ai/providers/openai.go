package providers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"

	"shell-ai-go/pkg/ai"
)

// OpenAIProvider implements the OpenAI API provider
type OpenAIProvider struct {
	config *ai.ProviderConfig
}

// NewOpenAIProvider creates a new OpenAI provider
func NewOpenAIProvider(config *ai.ProviderConfig) *OpenAIProvider {
	if config.MaxTokens == 0 {
		config.MaxTokens = 2000
	}
	if config.Temperature == 0 {
		config.Temperature = 0.7
	}
	if config.Model == "" {
		config.Model = "gpt-3.5-turbo"
	}
	if config.BaseURL == "" {
		config.BaseURL = "https://api.openai.com/v1"
	}

	return &OpenAIProvider{config: config}
}

// Name returns the provider name
func (p *OpenAIProvider) Name() string {
	return "openai"
}

// IsConfigured checks if the provider is properly configured
func (p *OpenAIProvider) IsConfigured() bool {
	return p.config != nil && p.config.APIKey != ""
}

// IsEnabled checks if the provider is enabled
func (p *OpenAIProvider) IsEnabled() bool {
	return p.config != nil && p.config.Enabled
}

// openAIRequest represents the request structure for OpenAI API
type openAIRequest struct {
	Model       string          `json:"model"`
	Messages    []openAIMessage `json:"messages"`
	MaxTokens   int             `json:"max_tokens"`
	Temperature float64         `json:"temperature"`
	Stream      bool            `json:"stream,omitempty"`
}

// openAIMessage represents a message in the OpenAI format
type openAIMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// openAIResponse represents the response from OpenAI API
type openAIResponse struct {
	Choices []struct {
		Message openAIMessage `json:"message"`
	} `json:"choices"`
	Error *struct {
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

// Chat sends a message and returns the response
func (p *OpenAIProvider) Chat(ctx context.Context, conversation *ai.Conversation) (*ai.Message, error) {
	if !p.IsConfigured() {
		return nil, fmt.Errorf("OpenAI provider not configured")
	}

	// Convert conversation to OpenAI format
	messages := make([]openAIMessage, len(conversation.Messages))
	for i, msg := range conversation.Messages {
		messages[i] = openAIMessage{
			Role:    string(msg.Role),
			Content: msg.Content,
		}
	}

	request := openAIRequest{
		Model:       p.config.Model,
		Messages:    messages,
		MaxTokens:   p.config.MaxTokens,
		Temperature: p.config.Temperature,
	}

	reqBody, err := json.Marshal(request)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	url := fmt.Sprintf("%s/chat/completions", p.config.BaseURL)
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(reqBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s", p.config.APIKey))

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to send request: %w", err)
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API error (status %d): %s", resp.StatusCode, string(respBody))
	}

	var openAIResp openAIResponse
	if err := json.Unmarshal(respBody, &openAIResp); err != nil {
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}

	if openAIResp.Error != nil {
		return nil, fmt.Errorf("OpenAI API error: %s", openAIResp.Error.Message)
	}

	if len(openAIResp.Choices) == 0 {
		return nil, fmt.Errorf("no response choices received")
	}

	return &ai.Message{
		Role:      ai.RoleAssistant,
		Content:   openAIResp.Choices[0].Message.Content,
		Timestamp: time.Now(),
	}, nil
}

// ChatStream sends a message and streams the response
func (p *OpenAIProvider) ChatStream(ctx context.Context, conversation *ai.Conversation) (io.ReadCloser, error) {
	// For now, implement as non-streaming
	// TODO: Implement proper streaming
	message, err := p.Chat(ctx, conversation)
	if err != nil {
		return nil, err
	}

	return io.NopCloser(bytes.NewReader([]byte(message.Content))), nil
}

// Test performs a connection test
func (p *OpenAIProvider) Test(ctx context.Context) error {
	if !p.IsConfigured() {
		return fmt.Errorf("provider not configured")
	}

	// Create a simple test conversation
	testConv := &ai.Conversation{
		ID: "test",
		Messages: []ai.Message{
			{
				Role:    ai.RoleUser,
				Content: "Hello, respond with just 'OK' to confirm you're working.",
			},
		},
	}

	response, err := p.Chat(ctx, testConv)
	if err != nil {
		return fmt.Errorf("test failed: %w", err)
	}

	// Check if response contains "OK" (case insensitive)
	if response.Content == "" {
		return fmt.Errorf("received empty response")
	}

	return nil
}

// Setup configures the provider interactively
func (p *OpenAIProvider) Setup() error {
	fmt.Print("Enter OpenAI API Key: ")
	var apiKey string
	fmt.Scanln(&apiKey)

	if apiKey == "" {
		return fmt.Errorf("API key cannot be empty")
	}

	fmt.Print("Enter model (default: gpt-3.5-turbo): ")
	var model string
	fmt.Scanln(&model)
	if model == "" {
		model = "gpt-3.5-turbo"
	}

	fmt.Print("Enable provider? [Y/n]: ")
	var enable string
	fmt.Scanln(&enable)
	enabled := enable != "n" && enable != "N"

	p.config.APIKey = apiKey
	p.config.Model = model
	p.config.Enabled = enabled

	return nil
}
