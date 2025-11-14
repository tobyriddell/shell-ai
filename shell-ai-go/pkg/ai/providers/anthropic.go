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

// AnthropicProvider implements the Anthropic Claude API provider
type AnthropicProvider struct {
	config *ai.ProviderConfig
}

// NewAnthropicProvider creates a new Anthropic provider
func NewAnthropicProvider(config *ai.ProviderConfig) *AnthropicProvider {
	if config.MaxTokens == 0 {
		config.MaxTokens = 2000
	}
	if config.Temperature == 0 {
		config.Temperature = 0.7
	}
	if config.Model == "" {
		config.Model = "claude-3-haiku-20240307"
	}
	if config.BaseURL == "" {
		config.BaseURL = "https://api.anthropic.com/v1"
	}

	return &AnthropicProvider{config: config}
}

// Name returns the provider name
func (p *AnthropicProvider) Name() string {
	return "anthropic"
}

// IsConfigured checks if the provider is properly configured
func (p *AnthropicProvider) IsConfigured() bool {
	return p.config != nil && p.config.APIKey != ""
}

// IsEnabled checks if the provider is enabled
func (p *AnthropicProvider) IsEnabled() bool {
	return p.config != nil && p.config.Enabled
}

// anthropicRequest represents the request structure for Anthropic API
type anthropicRequest struct {
	Model       string             `json:"model"`
	MaxTokens   int                `json:"max_tokens"`
	Temperature float64            `json:"temperature"`
	Messages    []anthropicMessage `json:"messages"`
	System      string             `json:"system,omitempty"`
}

// anthropicMessage represents a message in the Anthropic format
type anthropicMessage struct {
	Role    string `json:"role"`
	Content string `json:"content"`
}

// anthropicResponse represents the response from Anthropic API
type anthropicResponse struct {
	Content []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	} `json:"content"`
	StopReason string `json:"stop_reason"`
	Error      *struct {
		Type    string `json:"type"`
		Message string `json:"message"`
	} `json:"error,omitempty"`
}

// Chat sends a message and returns the response
func (p *AnthropicProvider) Chat(ctx context.Context, conversation *ai.Conversation) (*ai.Message, error) {
	if !p.IsConfigured() {
		return nil, fmt.Errorf("Anthropic provider not configured")
	}

	// Convert conversation to Anthropic format
	// Skip system messages for the messages array, handle separately
	messages := make([]anthropicMessage, 0, len(conversation.Messages))
	var systemMessage string

	for _, msg := range conversation.Messages {
		if msg.Role == ai.RoleSystem {
			systemMessage = msg.Content
		} else {
			messages = append(messages, anthropicMessage{
				Role:    string(msg.Role),
				Content: msg.Content,
			})
		}
	}

	request := anthropicRequest{
		Model:       p.config.Model,
		MaxTokens:   p.config.MaxTokens,
		Temperature: p.config.Temperature,
		Messages:    messages,
		System:      systemMessage,
	}

	reqBody, err := json.Marshal(request)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	url := fmt.Sprintf("%s/messages", p.config.BaseURL)
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(reqBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("x-api-key", p.config.APIKey)
	req.Header.Set("anthropic-version", "2023-06-01")

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

	var anthropicResp anthropicResponse
	if err := json.Unmarshal(respBody, &anthropicResp); err != nil {
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}

	if anthropicResp.Error != nil {
		return nil, fmt.Errorf("Anthropic API error: %s", anthropicResp.Error.Message)
	}

	if len(anthropicResp.Content) == 0 {
		return nil, fmt.Errorf("no response content received")
	}

	// Combine all text content
	var content string
	for _, item := range anthropicResp.Content {
		if item.Type == "text" {
			content += item.Text
		}
	}

	return &ai.Message{
		Role:      ai.RoleAssistant,
		Content:   content,
		Timestamp: time.Now(),
	}, nil
}

// ChatStream sends a message and streams the response
func (p *AnthropicProvider) ChatStream(ctx context.Context, conversation *ai.Conversation) (io.ReadCloser, error) {
	// For now, implement as non-streaming
	// TODO: Implement proper streaming
	message, err := p.Chat(ctx, conversation)
	if err != nil {
		return nil, err
	}

	return io.NopCloser(bytes.NewReader([]byte(message.Content))), nil
}

// Test performs a connection test
func (p *AnthropicProvider) Test(ctx context.Context) error {
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

	// Check if response contains some content
	if response.Content == "" {
		return fmt.Errorf("received empty response")
	}

	return nil
}

// Setup configures the provider interactively
func (p *AnthropicProvider) Setup() error {
	fmt.Print("Enter Anthropic API Key: ")
	var apiKey string
	fmt.Scanln(&apiKey)

	if apiKey == "" {
		return fmt.Errorf("API key cannot be empty")
	}

	fmt.Print("Enter model (default: claude-3-haiku-20240307): ")
	var model string
	fmt.Scanln(&model)
	if model == "" {
		model = "claude-3-haiku-20240307"
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
