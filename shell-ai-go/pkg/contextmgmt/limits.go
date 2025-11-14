package contextmgmt

import (
	"fmt"
	"unicode/utf8"
)

// ContextLimits defines limits for context management
type ContextLimits struct {
	MaxTokens           int    `yaml:"max_tokens"`
	MaxMessages         int    `yaml:"max_messages"`
	MaxHistoryLines     int    `yaml:"max_history_lines"`
	MaxContextSize      int    `yaml:"max_context_size"`
	KeepInitialMessages int    `yaml:"keep_initial_messages"`
	TruncationStrategy  string `yaml:"truncation_strategy"` // "sliding_window" or "smart"
}

// DefaultContextLimits returns sensible defaults for context limits
func DefaultContextLimits() *ContextLimits {
	return &ContextLimits{
		MaxTokens:           8000,    // Conservative limit for most LLMs
		MaxMessages:         20,      // Keep last 20 messages
		MaxHistoryLines:     50,      // Keep last 50 shell history lines
		MaxContextSize:      50000,   // 50KB max context
		KeepInitialMessages: 3,       // Keep first 3 messages for context
		TruncationStrategy:  "smart", // Use smart truncation
	}
}

// EstimateTokens provides a rough token estimation for text
// This is a simple approximation - real tokenization would be more accurate
func EstimateTokens(text string) int {
	// Rough estimation: 1 token ≈ 4 characters for English text
	// This is conservative and works well for most cases
	charCount := utf8.RuneCountInString(text)
	return (charCount + 3) / 4 // Round up
}

// EstimateContextSize estimates the total size of context in bytes
func EstimateContextSize(text string) int {
	return len([]byte(text))
}

// ShouldTruncate checks if context should be truncated based on limits
func (cl *ContextLimits) ShouldTruncate(contextSize int, tokenCount int, messageCount int) bool {
	return contextSize > cl.MaxContextSize ||
		tokenCount > cl.MaxTokens ||
		messageCount > cl.MaxMessages
}

// GetTruncationInfo returns information about what should be truncated
func (cl *ContextLimits) GetTruncationInfo(contextSize int, tokenCount int, messageCount int) TruncationInfo {
	info := TruncationInfo{
		ShouldTruncate: cl.ShouldTruncate(contextSize, tokenCount, messageCount),
		Reason:         []string{},
	}

	if contextSize > cl.MaxContextSize {
		info.Reason = append(info.Reason, "context size exceeded")
	}
	if tokenCount > cl.MaxTokens {
		info.Reason = append(info.Reason, "token limit exceeded")
	}
	if messageCount > cl.MaxMessages {
		info.Reason = append(info.Reason, "message count exceeded")
	}

	return info
}

// TruncationInfo contains information about truncation decisions
type TruncationInfo struct {
	ShouldTruncate bool
	Reason         []string
	MessagesToKeep int
	TokensToRemove int
}

// SmartTruncate implements intelligent conversation truncation
func (cl *ContextLimits) SmartTruncate(messages []Message) []Message {
	if len(messages) <= cl.MaxMessages {
		return messages
	}

	// Keep initial context messages
	initialMessages := messages[:cl.KeepInitialMessages]

	// Calculate how many recent messages we can keep
	remainingSlots := cl.MaxMessages - cl.KeepInitialMessages
	if remainingSlots <= 0 {
		return initialMessages
	}

	// Keep the most recent messages
	recentMessages := messages[len(messages)-remainingSlots:]

	// Combine initial context with recent messages
	result := make([]Message, 0, cl.MaxMessages)
	result = append(result, initialMessages...)
	result = append(result, recentMessages...)

	return result
}

// SlidingWindowTruncate implements simple sliding window truncation
func (cl *ContextLimits) SlidingWindowTruncate(messages []Message) []Message {
	if len(messages) <= cl.MaxMessages {
		return messages
	}

	// Keep only the most recent messages
	start := len(messages) - cl.MaxMessages
	return messages[start:]
}

// Message represents a message in a conversation (compatible with AI package)
type Message struct {
	Role      string `json:"role"`
	Content   string `json:"content"`
	Timestamp string `json:"timestamp"`
}

// TruncateConversation truncates a conversation based on the configured strategy
func (cl *ContextLimits) TruncateConversation(messages []Message) []Message {
	if len(messages) <= cl.MaxMessages {
		return messages
	}

	switch cl.TruncationStrategy {
	case "smart":
		return cl.SmartTruncate(messages)
	case "sliding_window":
		return cl.SlidingWindowTruncate(messages)
	default:
		// Default to smart truncation
		return cl.SmartTruncate(messages)
	}
}

// AnalyzeContext analyzes context and provides recommendations
func (cl *ContextLimits) AnalyzeContext(contextText string, messages []Message) ContextAnalysis {
	tokenCount := EstimateTokens(contextText)
	contextSize := EstimateContextSize(contextText)
	messageCount := len(messages)

	truncationInfo := cl.GetTruncationInfo(contextSize, tokenCount, messageCount)

	return ContextAnalysis{
		TokenCount:      tokenCount,
		ContextSize:     contextSize,
		MessageCount:    messageCount,
		TruncationInfo:  truncationInfo,
		Recommendations: cl.generateRecommendations(tokenCount, contextSize, messageCount),
	}
}

// ContextAnalysis contains analysis results for context
type ContextAnalysis struct {
	TokenCount      int
	ContextSize     int
	MessageCount    int
	TruncationInfo  TruncationInfo
	Recommendations []string
}

// generateRecommendations provides recommendations based on context analysis
func (cl *ContextLimits) generateRecommendations(tokenCount, contextSize, messageCount int) []string {
	var recommendations []string

	if tokenCount > int(float64(cl.MaxTokens)*0.8) {
		recommendations = append(recommendations, "Context is approaching token limit")
	}
	if contextSize > int(float64(cl.MaxContextSize)*0.8) {
		recommendations = append(recommendations, "Context size is approaching limit")
	}
	if messageCount > int(float64(cl.MaxMessages)*0.8) {
		recommendations = append(recommendations, "Message count is approaching limit")
	}

	if tokenCount > cl.MaxTokens {
		recommendations = append(recommendations, "Consider reducing context or using shorter responses")
	}

	return recommendations
}

// FormatSize formats bytes into human-readable format
func FormatSize(bytes int) string {
	const unit = 1024
	if bytes < unit {
		return fmt.Sprintf("%d B", bytes)
	}
	div, exp := int64(unit), 0
	for n := bytes / unit; n >= unit; n /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %cB", float64(bytes)/float64(div), "KMGTPE"[exp])
}
