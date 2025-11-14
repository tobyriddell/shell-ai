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

// OllamaProvider implements the Ollama API provider
type OllamaProvider struct {
	config *ai.ProviderConfig
}

// NewOllamaProvider creates a new Ollama provider
func NewOllamaProvider(config *ai.ProviderConfig) *OllamaProvider {
	if config.MaxTokens == 0 {
		config.MaxTokens = 2000
	}
	if config.Temperature == 0 {
		config.Temperature = 0.7
	}
	if config.Model == "" {
		config.Model = "llama3.2"
	}
	if config.BaseURL == "" {
		config.BaseURL = "http://localhost:11434"
	}

	return &OllamaProvider{config: config}
}

// Name returns the provider name
func (p *OllamaProvider) Name() string {
	return "ollama"
}

// IsConfigured checks if the provider is properly configured
func (p *OllamaProvider) IsConfigured() bool {
	// Ollama doesn't require API key, just model and URL
	return p.config != nil && p.config.Model != "" && p.config.BaseURL != ""
}

// IsEnabled checks if the provider is enabled
func (p *OllamaProvider) IsEnabled() bool {
	return p.config != nil && p.config.Enabled
}

// ollamaRequest represents the request structure for Ollama API
type ollamaRequest struct {
	Model    string          `json:"model"`
	Messages []ollamaMessage `json:"messages"`
	Stream   bool            `json:"stream"`
	Options  *ollamaOptions  `json:"options,omitempty"`
}

// ollamaMessage represents a message in the Ollama format
type ollamaMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// ollamaOptions represents options for the Ollama request
type ollamaOptions struct {
	Temperature int `json:"temperature,omitempty"`
	NumPredict  int `json:"num_predict,omitempty"`
}

// ollamaResponse represents the response from Ollama API
type ollamaResponse struct {
	Message struct {
		Role    string `json:"role"`
		Content string `json:"content"`
	} `json:"message"`
	Done  bool   `json:"done"`
	Error string `json:"error,omitempty"`
}

// Chat sends a message and returns the response
func (p *OllamaProvider) Chat(ctx context.Context, conversation *ai.Conversation) (*ai.Message, error) {
	if !p.IsConfigured() {
		return nil, fmt.Errorf("Ollama provider not configured")
	}

	// Convert conversation to Ollama format
	messages := make([]ollamaMessage, len(conversation.Messages))
	for i, msg := range conversation.Messages {
		messages[i] = ollamaMessage{
			Role:    string(msg.Role),
			Content: msg.Content,
		}
	}

	request := ollamaRequest{
		Model:    p.config.Model,
		Messages: messages,
		Stream:   false,
		Options: &ollamaOptions{
			Temperature: int(p.config.Temperature * 100), // Ollama uses 0-100 scale
			NumPredict:  p.config.MaxTokens,
		},
	}

	reqBody, err := json.Marshal(request)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	url := fmt.Sprintf("%s/api/chat", p.config.BaseURL)
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(reqBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 60 * time.Second} // Ollama can be slower
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

	var ollamaResp ollamaResponse
	if err := json.Unmarshal(respBody, &ollamaResp); err != nil {
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}

	if ollamaResp.Error != "" {
		return nil, fmt.Errorf("Ollama API error: %s", ollamaResp.Error)
	}

	if ollamaResp.Message.Content == "" {
		return nil, fmt.Errorf("no response content received")
	}

	return &ai.Message{
		Role:      ai.RoleAssistant,
		Content:   ollamaResp.Message.Content,
		Timestamp: time.Now(),
	}, nil
}

// ChatStream sends a message and streams the response
func (p *OllamaProvider) ChatStream(ctx context.Context, conversation *ai.Conversation) (io.ReadCloser, error) {
	// For now, implement as non-streaming
	// TODO: Implement proper streaming
	message, err := p.Chat(ctx, conversation)
	if err != nil {
		return nil, err
	}

	return io.NopCloser(bytes.NewReader([]byte(message.Content))), nil
}

// Test performs a connection test
func (p *OllamaProvider) Test(ctx context.Context) error {
	if !p.IsConfigured() {
		return fmt.Errorf("provider not configured")
	}

	// First check if Ollama server is reachable
	pingURL := fmt.Sprintf("%s/api/version", p.config.BaseURL)
	req, err := http.NewRequestWithContext(ctx, "GET", pingURL, nil)
	if err != nil {
		return fmt.Errorf("failed to create ping request: %w", err)
	}

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to reach Ollama server: %w", err)
	}
	resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("Ollama server not responding properly (status %d)", resp.StatusCode)
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

	// Check if response contains some content
	if response.Content == "" {
		return fmt.Errorf("received empty response")
	}

	return nil
}

// Setup configures the provider interactively
func (p *OllamaProvider) Setup() error {
	fmt.Print("Enter Ollama server URL (default: http://localhost:11434): ")
	var baseURL string
	fmt.Scanln(&baseURL)
	if baseURL == "" {
		baseURL = "http://localhost:11434"
	}

	fmt.Print("Enter model name (default: llama3.2): ")
	var model string
	fmt.Scanln(&model)
	if model == "" {
		model = "llama3.2"
	}

	fmt.Print("Enable provider? [Y/n]: ")
	var enable string
	fmt.Scanln(&enable)
	enabled := enable != "n" && enable != "N"

	p.config.BaseURL = baseURL
	p.config.Model = model
	p.config.Enabled = enabled
	// Ollama doesn't need API key
	p.config.APIKey = ""

	return nil
}
