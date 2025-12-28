//go:build !debug
// +build !debug

package debug

// Init is a no-op when debug is not enabled
func Init() error {
	return nil
}

// Log is a no-op when debug is not enabled
func Log(format string, args ...interface{}) {
}

// LogPrompt is a no-op when debug is not enabled
func LogPrompt(conversationID, provider string, fullPrompt string) {
}

// LogContext is a no-op when debug is not enabled
func LogContext(ctx interface{}) {
}

// LogConversationSummary is a no-op when debug is not enabled
func LogConversationSummary(conversationID string, messageCount int, messages []interface{}) {
}

// Close is a no-op when debug is not enabled
func Close() {
}
