package contextmgmt

import (
	"fmt"
	"time"

	"shell-ai-go/pkg/ai"
	"shell-ai-go/pkg/storage"
)

// Manager handles context management with limits and truncation
type Manager struct {
	limits        *ContextLimits
	storage       storage.Storage
	lastCleanup   time.Time
	cleanupPeriod time.Duration
}

// NewManager creates a new context manager
func NewManager(limits *ContextLimits, storage storage.Storage) *Manager {
	return &Manager{
		limits:        limits,
		storage:       storage,
		cleanupPeriod: 24 * time.Hour, // Cleanup every 24 hours
	}
}

// ProcessConversation processes a conversation with context limits
func (m *Manager) ProcessConversation(conversation *ai.Conversation) (*ai.Conversation, error) {
	if conversation == nil {
		return conversation, nil
	}

	// Convert to our message format for processing
	messages := make([]Message, len(conversation.Messages))
	for i, msg := range conversation.Messages {
		messages[i] = Message{
			Role:      string(msg.Role),
			Content:   msg.Content,
			Timestamp: msg.Timestamp.Format(time.RFC3339),
		}
	}

	// Analyze current context
	contextText := m.formatContextForAnalysis(conversation)
	analysis := m.limits.AnalyzeContext(contextText, messages)

	// Log analysis if truncation is needed
	if analysis.TruncationInfo.ShouldTruncate {
		fmt.Printf("⚠️  Context truncation needed: %v\n", analysis.TruncationInfo.Reason)
		fmt.Printf("   Tokens: %d/%d, Size: %s, Messages: %d/%d\n",
			analysis.TokenCount, m.limits.MaxTokens,
			FormatSize(analysis.ContextSize), analysis.MessageCount, m.limits.MaxMessages)
	}

	// Truncate if necessary
	truncatedMessages := m.limits.TruncateConversation(messages)

	// Convert back to AI conversation format
	truncatedConversation := &ai.Conversation{
		ID:       conversation.ID,
		Messages: make([]ai.Message, len(truncatedMessages)),
		Created:  conversation.Created,
		Updated:  conversation.Updated,
	}

	for i, msg := range truncatedMessages {
		truncatedConversation.Messages[i] = ai.Message{
			Role:      ai.MessageRole(msg.Role),
			Content:   msg.Content,
			Timestamp: time.Now(), // We lose original timestamp, but that's okay for context
		}
	}

	// Log truncation results
	if len(truncatedMessages) < len(messages) {
		removed := len(messages) - len(truncatedMessages)
		fmt.Printf("📝 Truncated conversation: removed %d messages, kept %d\n", removed, len(truncatedMessages))
	}

	return truncatedConversation, nil
}

// formatContextForAnalysis creates a simplified context for analysis
func (m *Manager) formatContextForAnalysis(conversation *ai.Conversation) string {
	var totalSize int
	for _, msg := range conversation.Messages {
		totalSize += len(msg.Content)
	}
	return fmt.Sprintf("Conversation with %d messages, total size: %d bytes", len(conversation.Messages), totalSize)
}

// PerformCleanup performs cleanup of old conversations if needed
func (m *Manager) PerformCleanup() error {
	if m.storage == nil {
		return nil // No storage, no cleanup needed
	}

	now := time.Now()
	if now.Sub(m.lastCleanup) < m.cleanupPeriod {
		return nil // Not time for cleanup yet
	}

	fmt.Println("🧹 Performing conversation cleanup...")

	// Use a reasonable TTL (24 hours by default)
	ttl := 24 * time.Hour
	err := m.storage.CleanupOldConversations(nil, ttl)
	if err != nil {
		return fmt.Errorf("failed to cleanup old conversations: %w", err)
	}

	m.lastCleanup = now
	return nil
}

// GetContextStats returns statistics about context usage
func (m *Manager) GetContextStats(conversation *ai.Conversation) ContextStats {
	if conversation == nil {
		return ContextStats{}
	}

	contextText := m.formatContextForAnalysis(conversation)
	analysis := m.limits.AnalyzeContext(contextText, convertToMessages(conversation.Messages))

	return ContextStats{
		TokenCount:       analysis.TokenCount,
		ContextSize:      analysis.ContextSize,
		MessageCount:     analysis.MessageCount,
		MaxTokens:        m.limits.MaxTokens,
		MaxMessages:      m.limits.MaxMessages,
		MaxContextSize:   m.limits.MaxContextSize,
		TruncationNeeded: analysis.TruncationInfo.ShouldTruncate,
		LastCleanup:      m.lastCleanup,
	}
}

// ContextStats contains context usage statistics
type ContextStats struct {
	TokenCount       int
	ContextSize      int
	MessageCount     int
	MaxTokens        int
	MaxMessages      int
	MaxContextSize   int
	TruncationNeeded bool
	LastCleanup      time.Time
}

// convertToMessages converts AI messages to our message format
func convertToMessages(aiMessages []ai.Message) []Message {
	messages := make([]Message, len(aiMessages))
	for i, msg := range aiMessages {
		messages[i] = Message{
			Role:      string(msg.Role),
			Content:   msg.Content,
			Timestamp: msg.Timestamp.Format(time.RFC3339),
		}
	}
	return messages
}

// FormatStats formats context stats for display
func (cs *ContextStats) FormatStats() string {
	return fmt.Sprintf(
		"Context Stats: %d/%d tokens, %s/%s size, %d/%d messages%s",
		cs.TokenCount, cs.MaxTokens,
		FormatSize(cs.ContextSize), FormatSize(cs.MaxContextSize),
		cs.MessageCount, cs.MaxMessages,
		func() string {
			if cs.TruncationNeeded {
				return " ⚠️"
			}
			return ""
		}(),
	)
}
