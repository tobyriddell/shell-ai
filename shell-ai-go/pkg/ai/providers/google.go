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

// GoogleProvider implements the Google Gemini API provider
type GoogleProvider struct {
	config *ai.ProviderConfig
}

// NewGoogleProvider creates a new Google provider
func NewGoogleProvider(config *ai.ProviderConfig) *GoogleProvider {
	if config.MaxTokens == 0 {
		config.MaxTokens = 2000
	}
	if config.Temperature == 0 {
		config.Temperature = 0.7
	}
	if config.Model == "" {
		config.Model = "gemini-1.5-flash"
	}
	if config.BaseURL == "" {
		config.BaseURL = "https://generativelanguage.googleapis.com/v1beta"
	}

	return &GoogleProvider{config: config}
}

// Name returns the provider name
func (p *GoogleProvider) Name() string {
	return "google"
}

// IsConfigured checks if the provider is properly configured
func (p *GoogleProvider) IsConfigured() bool {
	return p.config != nil && p.config.APIKey != ""
}

// IsEnabled checks if the provider is enabled
func (p *GoogleProvider) IsEnabled() bool {
	return p.config != nil && p.config.Enabled
}

// googleRequest represents the request structure for Google Gemini API
type googleRequest struct {
	Contents         []googleContent        `json:"contents"`
	GenerationConfig googleGenerationConfig `json:"generationConfig"`
}

// googleContent represents content in the Google format
type googleContent struct {
	Parts []googlePart `json:"parts"`
	Role  string       `json:"role,omitempty"`
}

// googlePart represents a part of content
type googlePart struct {
	Text string `json:"text"`
}

// googleGenerationConfig represents generation configuration
type googleGenerationConfig struct {
	Temperature     float64 `json:"temperature"`
	MaxOutputTokens int     `json:"maxOutputTokens"`
	TopP            float64 `json:"topP,omitempty"`
	TopK            int     `json:"topK,omitempty"`
}

// googleResponse represents the response from Google Gemini API
type googleResponse struct {
	Candidates []struct {
		Content struct {
			Parts []googlePart `json:"parts"`
			Role  string       `json:"role"`
		} `json:"content"`
		FinishReason string `json:"finishReason"`
	} `json:"candidates"`
	Error *struct {
		Code    int    `json:"code"`
		Message string `json:"message"`
		Status  string `json:"status"`
	} `json:"error,omitempty"`
}

// Chat sends a message and returns the response
func (p *GoogleProvider) Chat(ctx context.Context, conversation *ai.Conversation) (*ai.Message, error) {
	if !p.IsConfigured() {
		return nil, fmt.Errorf("Google provider not configured")
	}

	// Convert conversation to Google format
	contents := make([]googleContent, 0, len(conversation.Messages))

	for _, msg := range conversation.Messages {
		// Skip system messages for now (Google handles them differently)
		if msg.Role == ai.RoleSystem {
			continue
		}

		role := "user"
		if msg.Role == ai.RoleAssistant {
			role = "model"
		}

		contents = append(contents, googleContent{
			Parts: []googlePart{{Text: msg.Content}},
			Role:  role,
		})
	}

	request := googleRequest{
		Contents: contents,
		GenerationConfig: googleGenerationConfig{
			Temperature:     p.config.Temperature,
			MaxOutputTokens: p.config.MaxTokens,
			TopP:            0.8,
			TopK:            10,
		},
	}

	reqBody, err := json.Marshal(request)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	url := fmt.Sprintf("%s/models/%s:generateContent?key=%s", p.config.BaseURL, p.config.Model, p.config.APIKey)
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewReader(reqBody))
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

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

	var googleResp googleResponse
	if err := json.Unmarshal(respBody, &googleResp); err != nil {
		return nil, fmt.Errorf("failed to parse response: %w", err)
	}

	if googleResp.Error != nil {
		return nil, fmt.Errorf("Google API error: %s", googleResp.Error.Message)
	}

	if len(googleResp.Candidates) == 0 {
		return nil, fmt.Errorf("no response candidates received")
	}

	// Combine all text parts
	var content string
	for _, part := range googleResp.Candidates[0].Content.Parts {
		content += part.Text
	}

	return &ai.Message{
		Role:      ai.RoleAssistant,
		Content:   content,
		Timestamp: time.Now(),
	}, nil
}

// ChatStream sends a message and streams the response
func (p *GoogleProvider) ChatStream(ctx context.Context, conversation *ai.Conversation) (io.ReadCloser, error) {
	// For now, implement as non-streaming
	// TODO: Implement proper streaming
	message, err := p.Chat(ctx, conversation)
	if err != nil {
		return nil, err
	}

	return io.NopCloser(bytes.NewReader([]byte(message.Content))), nil
}

// Test performs a connection test
func (p *GoogleProvider) Test(ctx context.Context) error {
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
func (p *GoogleProvider) Setup() error {
	fmt.Print("Enter Google AI API Key: ")
	var apiKey string
	fmt.Scanln(&apiKey)

	if apiKey == "" {
		return fmt.Errorf("API key cannot be empty")
	}

	fmt.Print("Enter model (default: gemini-1.5-flash): ")
	var model string
	fmt.Scanln(&model)
	if model == "" {
		model = "gemini-1.5-flash"
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
