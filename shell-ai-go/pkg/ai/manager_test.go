package ai

import (
	"context"
	"io"
	"testing"
	"time"
)

// mockProvider implements Provider interface for testing
type mockProvider struct {
	name        string
	configured  bool
	enabled     bool
	shouldError bool
	response    string
}

func (m *mockProvider) Name() string       { return m.name }
func (m *mockProvider) IsConfigured() bool { return m.configured }
func (m *mockProvider) IsEnabled() bool    { return m.enabled }
func (m *mockProvider) Setup() error       { return nil }
func (m *mockProvider) ChatStream(ctx context.Context, conv *Conversation) (io.ReadCloser, error) {
	return nil, nil
}

func (m *mockProvider) Chat(ctx context.Context, conv *Conversation) (*Message, error) {
	if m.shouldError {
		return nil, context.DeadlineExceeded
	}
	return &Message{
		Role:      RoleAssistant,
		Content:   m.response,
		Timestamp: time.Now(),
	}, nil
}

func (m *mockProvider) Test(ctx context.Context) error {
	if m.shouldError {
		return context.DeadlineExceeded
	}
	return nil
}

func TestManager_RegisterProvider(t *testing.T) {
	manager := NewManager()
	provider := &mockProvider{name: "test", configured: true, enabled: true}

	manager.RegisterProvider("test", provider)

	if len(manager.providers) != 1 {
		t.Errorf("Expected 1 provider, got %d", len(manager.providers))
	}

	retrieved, exists := manager.GetProvider("test")
	if !exists {
		t.Error("Provider not found")
	}
	if retrieved.Name() != "test" {
		t.Errorf("Expected provider name 'test', got '%s'", retrieved.Name())
	}
}

func TestManager_GetEnabledProviders(t *testing.T) {
	manager := NewManager()

	// Add enabled provider
	enabledProvider := &mockProvider{name: "enabled", configured: true, enabled: true}
	manager.RegisterProvider("enabled", enabledProvider)

	// Add disabled provider
	disabledProvider := &mockProvider{name: "disabled", configured: true, enabled: false}
	manager.RegisterProvider("disabled", disabledProvider)

	// Add unconfigured provider
	unconfiguredProvider := &mockProvider{name: "unconfigured", configured: false, enabled: true}
	manager.RegisterProvider("unconfigured", unconfiguredProvider)

	enabled := manager.GetEnabledProviders()
	if len(enabled) != 1 {
		t.Errorf("Expected 1 enabled provider, got %d", len(enabled))
	}
	if enabled[0].Name() != "enabled" {
		t.Errorf("Expected enabled provider, got '%s'", enabled[0].Name())
	}
}

func TestManager_SetActiveProvider(t *testing.T) {
	manager := NewManager()
	provider := &mockProvider{name: "test", configured: true, enabled: true}
	manager.RegisterProvider("test", provider)

	// Test setting valid provider
	err := manager.SetActiveProvider("test")
	if err != nil {
		t.Errorf("Unexpected error: %v", err)
	}

	// Test setting non-existent provider
	err = manager.SetActiveProvider("nonexistent")
	if err == nil {
		t.Error("Expected error for non-existent provider")
	}

	// Test setting disabled provider
	disabledProvider := &mockProvider{name: "disabled", configured: true, enabled: false}
	manager.RegisterProvider("disabled", disabledProvider)
	err = manager.SetActiveProvider("disabled")
	if err == nil {
		t.Error("Expected error for disabled provider")
	}
}

func TestManager_GetActiveProvider(t *testing.T) {
	manager := NewManager()
	provider := &mockProvider{name: "test", configured: true, enabled: true}
	manager.RegisterProvider("test", provider)

	// Test with no active provider set - should auto-select first enabled
	active, err := manager.GetActiveProvider()
	if err != nil {
		t.Errorf("Unexpected error: %v", err)
	}
	if active.Name() != "test" {
		t.Errorf("Expected 'test', got '%s'", active.Name())
	}

	// Test with active provider set
	manager.SetActiveProvider("test")
	active, err = manager.GetActiveProvider()
	if err != nil {
		t.Errorf("Unexpected error: %v", err)
	}
	if active.Name() != "test" {
		t.Errorf("Expected 'test', got '%s'", active.Name())
	}
}

func TestManager_Conversation(t *testing.T) {
	manager := NewManager()

	// Test creating new conversation
	conv1 := manager.GetOrCreateConversation("test1")
	if conv1.ID != "test1" {
		t.Errorf("Expected conversation ID 'test1', got '%s'", conv1.ID)
	}
	if len(conv1.Messages) != 0 {
		t.Errorf("Expected empty conversation, got %d messages", len(conv1.Messages))
	}

	// Test getting existing conversation
	conv2 := manager.GetOrCreateConversation("test1")
	if conv1 != conv2 {
		t.Error("Expected same conversation instance")
	}

	// Test adding messages
	manager.AddMessage("test1", RoleUser, "Hello")
	manager.AddMessage("test1", RoleAssistant, "Hi there!")

	conv3 := manager.GetOrCreateConversation("test1")
	if len(conv3.Messages) != 2 {
		t.Errorf("Expected 2 messages, got %d", len(conv3.Messages))
	}
	if conv3.Messages[0].Role != RoleUser {
		t.Errorf("Expected first message to be user, got %s", conv3.Messages[0].Role)
	}
	if conv3.Messages[1].Role != RoleAssistant {
		t.Errorf("Expected second message to be assistant, got %s", conv3.Messages[1].Role)
	}
}

func TestManager_Chat(t *testing.T) {
	manager := NewManager()
	provider := &mockProvider{
		name:        "test",
		configured:  true,
		enabled:     true,
		response:    "Test response",
		shouldError: false,
	}
	manager.RegisterProvider("test", provider)
	manager.SetActiveProvider("test")

	// Test successful chat
	response, err := manager.Chat(context.Background(), "test-conv", "Hello")
	if err != nil {
		t.Errorf("Unexpected error: %v", err)
	}
	if response.Content != "Test response" {
		t.Errorf("Expected 'Test response', got '%s'", response.Content)
	}
	if response.Provider != "test" {
		t.Errorf("Expected provider 'test', got '%s'", response.Provider)
	}

	// Verify conversation was updated
	conv := manager.GetOrCreateConversation("test-conv")
	if len(conv.Messages) != 2 {
		t.Errorf("Expected 2 messages in conversation, got %d", len(conv.Messages))
	}
	if conv.Messages[0].Content != "Hello" {
		t.Errorf("Expected user message 'Hello', got '%s'", conv.Messages[0].Content)
	}
	if conv.Messages[1].Content != "Test response" {
		t.Errorf("Expected assistant message 'Test response', got '%s'", conv.Messages[1].Content)
	}
}

func TestManager_TestProviders(t *testing.T) {
	manager := NewManager()

	// Add working provider
	workingProvider := &mockProvider{
		name:        "working",
		configured:  true,
		enabled:     true,
		shouldError: false,
	}
	manager.RegisterProvider("working", workingProvider)

	// Add failing provider
	failingProvider := &mockProvider{
		name:        "failing",
		configured:  true,
		enabled:     true,
		shouldError: true,
	}
	manager.RegisterProvider("failing", failingProvider)

	// Add unconfigured provider
	unconfiguredProvider := &mockProvider{
		name:        "unconfigured",
		configured:  false,
		enabled:     true,
		shouldError: false,
	}
	manager.RegisterProvider("unconfigured", unconfiguredProvider)

	results := manager.TestAllProviders(context.Background())

	if len(results) != 3 {
		t.Errorf("Expected 3 test results, got %d", len(results))
	}

	if results["working"] != nil {
		t.Errorf("Expected working provider to pass, got error: %v", results["working"])
	}

	if results["failing"] == nil {
		t.Error("Expected failing provider to fail")
	}

	if results["unconfigured"] == nil {
		t.Error("Expected unconfigured provider to fail")
	}
}

func TestManager_ListProviders(t *testing.T) {
	manager := NewManager()

	// Test empty list
	providers := manager.ListProviders()
	if len(providers) != 0 {
		t.Errorf("Expected empty list, got %d providers", len(providers))
	}

	// Add providers
	manager.RegisterProvider("b", &mockProvider{name: "b"})
	manager.RegisterProvider("a", &mockProvider{name: "a"})
	manager.RegisterProvider("c", &mockProvider{name: "c"})

	providers = manager.ListProviders()
	if len(providers) != 3 {
		t.Errorf("Expected 3 providers, got %d", len(providers))
	}

	// Should be sorted alphabetically
	expected := []string{"a", "b", "c"}
	for i, provider := range providers {
		if provider != expected[i] {
			t.Errorf("Expected provider %s at index %d, got %s", expected[i], i, provider)
		}
	}
}
