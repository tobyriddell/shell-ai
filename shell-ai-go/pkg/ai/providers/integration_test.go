package providers

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"

	"shell-ai-go/pkg/ai"
)

// Helper function to check if API key is available from environment
func getAPIKey(providerName string) string {
	// Check environment variables first (common patterns)
	envVars := map[string][]string{
		"openai":    {"OPENAI_API_KEY", "SHELL_AI_PROVIDERS_OPENAI_API_KEY"},
		"anthropic": {"ANTHROPIC_API_KEY", "SHELL_AI_PROVIDERS_ANTHROPIC_API_KEY"},
		"google":    {"GOOGLE_API_KEY", "GOOGLE_AI_API_KEY", "SHELL_AI_PROVIDERS_GOOGLE_API_KEY"},
		"ollama":    {"OLLAMA_API_KEY", "SHELL_AI_PROVIDERS_OLLAMA_API_KEY"},
	}

	if vars, ok := envVars[providerName]; ok {
		for _, envVar := range vars {
			if apiKey := os.Getenv(envVar); apiKey != "" {
				return apiKey
			}
		}
	}

	return ""
}

// Helper function to create a test provider with API key from environment
func createTestProvider(providerName string) (ai.Provider, error) {
	apiKey := getAPIKey(providerName)
	if apiKey == "" && providerName != "ollama" {
		return nil, nil // No API key available
	}

	config := &ai.ProviderConfig{
		Name:        providerName,
		APIKey:      apiKey,
		Enabled:     true,
		MaxTokens:   500, // Use smaller tokens for tests
		Temperature: 0.7,
	}

	var provider ai.Provider
	switch providerName {
	case "openai":
		config.Model = "gpt-3.5-turbo"
		provider = NewOpenAIProvider(config)
	case "anthropic":
		config.Model = "claude-3-haiku-20240307"
		provider = NewAnthropicProvider(config)
	case "google":
		config.Model = "gemini-2.0-flash-exp"
		provider = NewGoogleProvider(config)
	case "ollama":
		config.Model = "llama2"
		config.BaseURL = "http://localhost:11434"
		provider = NewOllamaProvider(config)
	default:
		return nil, nil
	}

	return provider, nil
}

// Helper function to skip test with helpful message
func skipIfNoAPIKey(t *testing.T, providerName string, envVarNames []string) {
	apiKey := getAPIKey(providerName)
	if apiKey == "" {
		var envVarList strings.Builder
		for i, name := range envVarNames {
			if i > 0 {
				envVarList.WriteString(", ")
			}
			envVarList.WriteString(name)
		}
		t.Skipf("Skipping %s integration test: API key not found. Set one of these environment variables: %s", providerName, envVarList.String())
	}
}

func TestOpenAIProvider_RealChat(t *testing.T) {
	skipIfNoAPIKey(t, "openai", []string{"OPENAI_API_KEY", "SHELL_AI_PROVIDERS_OPENAI_API_KEY"})

	provider, err := createTestProvider("openai")
	if err != nil {
		t.Fatalf("Failed to create provider: %v", err)
	}
	if provider == nil {
		t.Fatal("Provider is nil (API key not available)")
	}

	if !provider.IsConfigured() {
		t.Skip("OpenAI provider is not configured")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Create a simple test conversation
	conv := &ai.Conversation{
		ID: "test-openai",
		Messages: []ai.Message{
			{
				Role:    ai.RoleUser,
				Content: "Say 'Hello, this is a test' and nothing else.",
			},
		},
	}

	response, err := provider.Chat(ctx, conv)
	if err != nil {
		t.Fatalf("Chat failed: %v", err)
	}

	if response == nil {
		t.Fatal("Response is nil")
	}

	if response.Content == "" {
		t.Error("Response content is empty")
	}

	// Check that response contains expected content (case insensitive)
	content := strings.ToLower(response.Content)
	if !strings.Contains(content, "hello") && !strings.Contains(content, "test") {
		t.Logf("Response: %s", response.Content)
		t.Error("Response doesn't seem to match the prompt (expected 'hello' or 'test' in response)")
	}

	t.Logf("OpenAI response received: %s", response.Content)
}

func TestAnthropicProvider_RealChat(t *testing.T) {
	skipIfNoAPIKey(t, "anthropic", []string{"ANTHROPIC_API_KEY", "SHELL_AI_PROVIDERS_ANTHROPIC_API_KEY"})

	provider, err := createTestProvider("anthropic")
	if err != nil {
		t.Fatalf("Failed to create provider: %v", err)
	}
	if provider == nil {
		t.Fatal("Provider is nil (API key not available)")
	}

	if !provider.IsConfigured() {
		t.Skip("Anthropic provider is not configured")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Create a simple test conversation
	conv := &ai.Conversation{
		ID: "test-anthropic",
		Messages: []ai.Message{
			{
				Role:    ai.RoleUser,
				Content: "Say 'Hello, this is a test' and nothing else.",
			},
		},
	}

	response, err := provider.Chat(ctx, conv)
	if err != nil {
		t.Fatalf("Chat failed: %v", err)
	}

	if response == nil {
		t.Fatal("Response is nil")
	}

	if response.Content == "" {
		t.Error("Response content is empty")
	}

	// Check that response contains expected content (case insensitive)
	content := strings.ToLower(response.Content)
	if !strings.Contains(content, "hello") && !strings.Contains(content, "test") {
		t.Logf("Response: %s", response.Content)
		t.Error("Response doesn't seem to match the prompt (expected 'hello' or 'test' in response)")
	}

	t.Logf("Anthropic response received: %s", response.Content)
}

func TestGoogleProvider_RealChat(t *testing.T) {
	skipIfNoAPIKey(t, "google", []string{"GOOGLE_API_KEY", "GOOGLE_AI_API_KEY", "SHELL_AI_PROVIDERS_GOOGLE_API_KEY"})

	provider, err := createTestProvider("google")
	if err != nil {
		t.Fatalf("Failed to create provider: %v", err)
	}
	if provider == nil {
		t.Fatal("Provider is nil (API key not available)")
	}

	if !provider.IsConfigured() {
		t.Skip("Google provider is not configured")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Create a simple test conversation
	conv := &ai.Conversation{
		ID: "test-google",
		Messages: []ai.Message{
			{
				Role:    ai.RoleUser,
				Content: "What is the capital of France?",
			},
		},
	}

	response, err := provider.Chat(ctx, conv)
	if err != nil {
		t.Fatalf("Chat failed: %v", err)
	}

	if response == nil {
		t.Fatal("Response is nil")
	}

	if response.Content == "" {
		t.Error("Response content is empty")
	}

	// Check that response contains expected content (case insensitive)
	content := strings.ToLower(response.Content)
	if !strings.Contains(content, "paris") {
		t.Logf("Response: %s", response.Content)
		t.Error("Response doesn't contain 'Paris' as expected for the capital of France")
	}

	t.Logf("Google response received: %s", response.Content)
}

func TestOllamaProvider_RealChat(t *testing.T) {
	// Ollama doesn't require an API key, but we should check if it's running
	provider, err := createTestProvider("ollama")
	if err != nil {
		t.Fatalf("Failed to create provider: %v", err)
	}
	if provider == nil {
		t.Skip("Skipping Ollama test: Ollama provider not available (check if Ollama is running on http://localhost:11434)")
	}

	if !provider.IsConfigured() {
		t.Skip("Ollama provider is not configured")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	// Test connection first
	if err := provider.Test(ctx); err != nil {
		t.Skipf("Skipping Ollama test: Ollama is not running or not accessible: %v", err)
	}

	// Create a simple test conversation
	conv := &ai.Conversation{
		ID: "test-ollama",
		Messages: []ai.Message{
			{
				Role:    ai.RoleUser,
				Content: "Say 'Hello, this is a test' and nothing else.",
			},
		},
	}

	response, err := provider.Chat(ctx, conv)
	if err != nil {
		t.Fatalf("Chat failed: %v", err)
	}

	if response == nil {
		t.Fatal("Response is nil")
	}

	if response.Content == "" {
		t.Error("Response content is empty")
	}

	// Check that response contains expected content (case insensitive)
	content := strings.ToLower(response.Content)
	if !strings.Contains(content, "hello") && !strings.Contains(content, "test") {
		t.Logf("Response: %s", response.Content)
		t.Error("Response doesn't seem to match the prompt (expected 'hello' or 'test' in response)")
	}

	t.Logf("Ollama response received: %s", response.Content)
}

func TestProvider_RealChatWithCommands(t *testing.T) {
	// Try to find any available provider
	providersToTest := []string{"openai", "anthropic", "google", "ollama"}
	var availableProvider ai.Provider
	var providerName string

	for _, name := range providersToTest {
		provider, err := createTestProvider(name)
		if err == nil && provider != nil && provider.IsConfigured() {
			// For Ollama, test connection first
			if name == "ollama" {
				ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
				if err := provider.Test(ctx); err != nil {
					cancel()
					continue
				}
				cancel()
			}
			availableProvider = provider
			providerName = name
			break
		}
	}

	if availableProvider == nil {
		t.Skip("Skipping command extraction test: No AI provider configured. Set one of: OPENAI_API_KEY, ANTHROPIC_API_KEY, GOOGLE_API_KEY, or ensure Ollama is running")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	// Test a prompt that should generate shell commands
	prompt := "List the files in the current directory. Provide the command to do this in a code block."
	conv := &ai.Conversation{
		ID: "test-commands",
		Messages: []ai.Message{
			{
				Role:    ai.RoleUser,
				Content: prompt,
			},
		},
	}

	response, err := availableProvider.Chat(ctx, conv)
	if err != nil {
		t.Fatalf("Chat failed: %v", err)
	}

	if response == nil || response.Content == "" {
		t.Fatal("Response is nil or empty")
	}

	// Check that response contains a command (ls, dir, or similar)
	content := strings.ToLower(response.Content)
	hasCommand := strings.Contains(content, "ls") ||
		strings.Contains(content, "dir") ||
		strings.Contains(content, "```") ||
		strings.Contains(content, "$")

	if !hasCommand {
		t.Logf("Response: %s", response.Content)
		t.Error("Response doesn't appear to contain shell commands as requested")
	}

	t.Logf("Command extraction test response from %s: %s", providerName, response.Content)
}
