package ai

import (
	"context"
	"io"
	"time"
)

// Message represents a single message in a conversation
type Message struct {
	Role      MessageRole `json:"role"`
	Content   string      `json:"content"`
	Timestamp time.Time   `json:"timestamp"`
}

// MessageRole defines the role of a message sender
type MessageRole string

const (
	RoleUser      MessageRole = "user"
	RoleAssistant MessageRole = "assistant"
	RoleSystem    MessageRole = "system"
)

// Conversation represents a full conversation context
type Conversation struct {
	ID       string    `json:"id"`
	Messages []Message `json:"messages"`
	Created  time.Time `json:"created"`
	Updated  time.Time `json:"updated"`
}

// Provider represents an AI provider interface
type Provider interface {
	// Name returns the provider name
	Name() string

	// IsConfigured returns true if the provider is properly configured
	IsConfigured() bool

	// IsEnabled returns true if the provider is enabled
	IsEnabled() bool

	// Chat sends a message and returns the response
	Chat(ctx context.Context, conversation *Conversation) (*Message, error)

	// ChatStream sends a message and streams the response
	ChatStream(ctx context.Context, conversation *Conversation) (io.ReadCloser, error)

	// Test performs a connection test
	Test(ctx context.Context) error

	// Setup configures the provider interactively
	Setup() error
}

// ProviderConfig contains configuration for a specific provider
type ProviderConfig struct {
	Name        string                 `yaml:"name"`
	Enabled     bool                   `yaml:"enabled"`
	Model       string                 `yaml:"model,omitempty"`
	APIKey      string                 `yaml:"api_key,omitempty"`
	BaseURL     string                 `yaml:"base_url,omitempty"`
	MaxTokens   int                    `yaml:"max_tokens,omitempty"`
	Temperature float64                `yaml:"temperature,omitempty"`
	Extra       map[string]interface{} `yaml:"extra,omitempty"`
}

// Response represents an AI response with metadata
type Response struct {
	Content      string            `json:"content"`
	Provider     string            `json:"provider"`
	Model        string            `json:"model"`
	TokensUsed   int               `json:"tokens_used,omitempty"`
	ResponseTime time.Duration     `json:"response_time"`
	Metadata     map[string]string `json:"metadata,omitempty"`
}

// ContextData represents the context sent to the AI
type ContextData struct {
	SystemInfo   SystemInfo    `json:"system_info"`
	ShellHistory []string      `json:"shell_history"`
	TmuxContent  []PaneContent `json:"tmux_content"`
	WorkingDir   string        `json:"working_dir"`
	Environment  []string      `json:"environment"`
	Conversation *Conversation `json:"conversation,omitempty"`
}

// SystemInfo contains system information
type SystemInfo struct {
	OS       string `json:"os"`
	Shell    string `json:"shell"`
	Hostname string `json:"hostname"`
	User     string `json:"user"`
}

// PaneContent represents tmux pane content
type PaneContent struct {
	PaneID   string `json:"pane_id"`
	Title    string `json:"title"`
	Content  string `json:"content"`
	IsActive bool   `json:"is_active"`
	LastUsed int64  `json:"last_used"`
}

// CommandExtraction represents extracted commands from AI response
type CommandExtraction struct {
	Commands    []Command `json:"commands"`
	Explanation string    `json:"explanation"`
}

// Command represents a shell command
type Command struct {
	Command     string `json:"command"`
	Description string `json:"description,omitempty"`
	Safe        bool   `json:"safe"`
	LineNumber  int    `json:"line_number,omitempty"`
}
