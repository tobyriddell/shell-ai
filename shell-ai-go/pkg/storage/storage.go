package storage

import (
	"context"
	"time"
)

// MessageRole represents the role of a message in a conversation
type MessageRole string

const (
	RoleUser      MessageRole = "user"
	RoleAssistant MessageRole = "assistant"
	RoleSystem    MessageRole = "system"
)

// Message represents a single message in a conversation
type Message struct {
	Role      MessageRole `json:"role"`
	Content   string      `json:"content"`
	Timestamp time.Time   `json:"timestamp"`
}

// Conversation represents a conversation with multiple messages
type Conversation struct {
	ID       string    `json:"id"`
	Messages []Message `json:"messages"`
	Created  time.Time `json:"created"`
	Updated  time.Time `json:"updated"`
}

// Storage defines the interface for conversation persistence
type Storage interface {
	// SaveConversation saves a conversation to persistent storage
	SaveConversation(ctx context.Context, conversation *Conversation) error
	
	// LoadConversation loads a conversation by ID
	LoadConversation(ctx context.Context, id string) (*Conversation, error)
	
	// ListConversations returns a list of conversation summaries
	ListConversations(ctx context.Context, limit int, offset int) ([]*ConversationSummary, error)
	
	// DeleteConversation deletes a conversation by ID
	DeleteConversation(ctx context.Context, id string) error
	
	// AddMessage adds a message to an existing conversation
	AddMessage(ctx context.Context, conversationID string, message *Message) error
	
	// GetOrCreateConversation gets an existing conversation or creates a new one
	GetOrCreateConversation(ctx context.Context, id string) (*Conversation, error)
	
	// CleanupOldConversations removes conversations older than the specified duration
	CleanupOldConversations(ctx context.Context, olderThan time.Duration) error
	
	// Close closes the storage connection
	Close() error
}

// ConversationSummary provides a lightweight view of a conversation
type ConversationSummary struct {
	ID          string    `json:"id"`
	Title       string    `json:"title"`
	MessageCount int      `json:"message_count"`
	Created     time.Time `json:"created"`
	Updated     time.Time `json:"updated"`
	LastMessage string    `json:"last_message"`
}
