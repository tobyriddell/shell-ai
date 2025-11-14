package ai

import (
	"context"
	"fmt"
	"sort"
	"time"

	"shell-ai-go/pkg/storage"
)

// Manager manages AI providers and conversations
type Manager struct {
	providers      map[string]Provider
	activeProvider string
	conversations  map[string]*Conversation
	storageAdapter *StorageAdapter
	useStorage     bool
}

// NewManager creates a new AI manager
func NewManager() *Manager {
	return &Manager{
		providers:     make(map[string]Provider),
		conversations: make(map[string]*Conversation),
		useStorage:    false,
	}
}

// NewManagerWithStorage creates a new AI manager with persistent storage
func NewManagerWithStorage() (*Manager, error) {
	storage, err := storage.NewSQLiteStorage()
	if err != nil {
		return nil, fmt.Errorf("failed to create storage: %w", err)
	}

	storageAdapter := NewStorageAdapter(storage)

	return &Manager{
		providers:      make(map[string]Provider),
		conversations:  make(map[string]*Conversation),
		storageAdapter: storageAdapter,
		useStorage:     true,
	}, nil
}

// RegisterProvider registers an AI provider
func (m *Manager) RegisterProvider(name string, provider Provider) {
	m.providers[name] = provider
}

// GetProvider returns a provider by name
func (m *Manager) GetProvider(name string) (Provider, bool) {
	provider, exists := m.providers[name]
	return provider, exists
}

// ListProviders returns all registered providers
func (m *Manager) ListProviders() []string {
	var names []string
	for name := range m.providers {
		names = append(names, name)
	}
	sort.Strings(names)
	return names
}

// GetEnabledProviders returns all enabled providers
func (m *Manager) GetEnabledProviders() []Provider {
	var enabled []Provider
	for _, provider := range m.providers {
		if provider.IsEnabled() && provider.IsConfigured() {
			enabled = append(enabled, provider)
		}
	}
	return enabled
}

// SetActiveProvider sets the active provider
func (m *Manager) SetActiveProvider(name string) error {
	provider, exists := m.providers[name]
	if !exists {
		return fmt.Errorf("provider %s not found", name)
	}

	if !provider.IsConfigured() {
		return fmt.Errorf("provider %s is not configured", name)
	}

	if !provider.IsEnabled() {
		return fmt.Errorf("provider %s is not enabled", name)
	}

	m.activeProvider = name
	return nil
}

// GetActiveProvider returns the current active provider
func (m *Manager) GetActiveProvider() (Provider, error) {
	if m.activeProvider == "" {
		// Try to find the first enabled provider
		enabled := m.GetEnabledProviders()
		if len(enabled) == 0 {
			return nil, fmt.Errorf("no enabled providers found")
		}
		m.activeProvider = enabled[0].Name()
	}

	provider, exists := m.providers[m.activeProvider]
	if !exists {
		return nil, fmt.Errorf("active provider %s not found", m.activeProvider)
	}

	return provider, nil
}

// GetOrCreateConversation gets or creates a conversation
func (m *Manager) GetOrCreateConversation(id string) *Conversation {
	// Check in-memory cache first
	if conv, exists := m.conversations[id]; exists {
		return conv
	}

	// If using storage, try to load from storage
	if m.useStorage && m.storageAdapter != nil {
		ctx := context.Background()
		conv, err := m.storageAdapter.GetOrCreateConversation(ctx, id)
		if err == nil {
			// Cache in memory for faster access
			m.conversations[id] = conv
			return conv
		}
		// If storage fails, fall back to in-memory
	}

	// Create new conversation in memory
	conv := &Conversation{
		ID:       id,
		Messages: make([]Message, 0),
		Created:  time.Now(),
		Updated:  time.Now(),
	}

	m.conversations[id] = conv
	return conv
}

// AddMessage adds a message to a conversation
func (m *Manager) AddMessage(conversationID string, role MessageRole, content string) {
	conv := m.GetOrCreateConversation(conversationID)

	message := Message{
		Role:      role,
		Content:   content,
		Timestamp: time.Now(),
	}

	conv.Messages = append(conv.Messages, message)
	conv.Updated = time.Now()

	// Persist to storage if available
	if m.useStorage && m.storageAdapter != nil {
		ctx := context.Background()
		if err := m.storageAdapter.AddMessage(ctx, conversationID, &message); err != nil {
			// Log error but don't fail the operation
			fmt.Printf("Warning: Failed to persist message to storage: %v\n", err)
		}
	}
}

// Chat sends a message and gets a response
func (m *Manager) Chat(ctx context.Context, conversationID, prompt string) (*Response, error) {
	provider, err := m.GetActiveProvider()
	if err != nil {
		return nil, err
	}

	// Add user message to conversation
	m.AddMessage(conversationID, RoleUser, prompt)

	// Get conversation
	conversation := m.GetOrCreateConversation(conversationID)

	// Send to provider
	start := time.Now()
	response, err := provider.Chat(ctx, conversation)
	if err != nil {
		return nil, fmt.Errorf("provider error: %w", err)
	}

	// Add assistant response to conversation
	m.AddMessage(conversationID, RoleAssistant, response.Content)

	return &Response{
		Content:      response.Content,
		Provider:     provider.Name(),
		ResponseTime: time.Since(start),
	}, nil
}

// TestProvider tests a specific provider
func (m *Manager) TestProvider(ctx context.Context, name string) error {
	provider, exists := m.providers[name]
	if !exists {
		return fmt.Errorf("provider %s not found", name)
	}

	if !provider.IsConfigured() {
		return fmt.Errorf("provider %s is not configured", name)
	}

	return provider.Test(ctx)
}

// TestAllProviders tests all configured providers
func (m *Manager) TestAllProviders(ctx context.Context) map[string]error {
	results := make(map[string]error)

	for name, provider := range m.providers {
		if provider.IsConfigured() {
			results[name] = provider.Test(ctx)
		} else {
			results[name] = fmt.Errorf("not configured")
		}
	}

	return results
}

// ListConversations returns a list of conversation summaries
func (m *Manager) ListConversations(limit int, offset int) ([]*storage.ConversationSummary, error) {
	if !m.useStorage || m.storageAdapter == nil {
		return nil, fmt.Errorf("storage not available")
	}

	ctx := context.Background()
	return m.storageAdapter.ListConversations(ctx, limit, offset)
}

// DeleteConversation deletes a conversation
func (m *Manager) DeleteConversation(id string) error {
	if !m.useStorage || m.storageAdapter == nil {
		return fmt.Errorf("storage not available")
	}

	ctx := context.Background()
	
	// Remove from memory cache
	delete(m.conversations, id)
	
	// Remove from storage
	return m.storageAdapter.DeleteConversation(ctx, id)
}

// GetStorageAdapter returns the storage adapter (for internal use)
func (m *Manager) GetStorageAdapter() *StorageAdapter {
	return m.storageAdapter
}

// SetStorageAdapter sets the storage adapter
func (m *Manager) SetStorageAdapter(adapter *StorageAdapter) {
	m.storageAdapter = adapter
}

// SetUseStorage sets whether to use storage
func (m *Manager) SetUseStorage(use bool) {
	m.useStorage = use
}

// GetConversations returns the conversations map (for internal use)
func (m *Manager) GetConversations() map[string]*Conversation {
	return m.conversations
}

// Close closes the storage connection
func (m *Manager) Close() error {
	if m.storageAdapter != nil && m.storageAdapter.storage != nil {
		return m.storageAdapter.storage.Close()
	}
	return nil
}
