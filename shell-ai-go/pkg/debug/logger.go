//go:build debug
// +build debug

package debug

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"
)

var (
	logFile  *os.File
	logMutex sync.Mutex
	enabled  = false
	initOnce sync.Once
)

// Init initializes the debug logger
func Init() error {
	var err error
	initOnce.Do(func() {
		homeDir, err := os.UserHomeDir()
		if err != nil {
			return
		}

		configDir := filepath.Join(homeDir, ".config", "shell-ai")
		if err := os.MkdirAll(configDir, 0755); err != nil {
			return
		}

		logPath := filepath.Join(configDir, "debug.log")
		logFile, err = os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err != nil {
			return
		}

		enabled = true
		Log("=== Debug logging started ===")
	})
	return err
}

// Log writes a debug message to the log file
func Log(format string, args ...interface{}) {
	if !enabled {
		return
	}

	logMutex.Lock()
	defer logMutex.Unlock()

	if logFile == nil {
		return
	}

	timestamp := time.Now().Format("2006-01-02 15:04:05.000")
	message := fmt.Sprintf(format, args...)
	fmt.Fprintf(logFile, "[%s] %s\n", timestamp, message)
	logFile.Sync()
}

// LogPrompt logs a full prompt being sent to the LLM
func LogPrompt(conversationID, provider string, fullPrompt string) {
	Log("=== PROMPT ===")
	Log("Conversation ID: %s", conversationID)
	Log("Provider: %s", provider)
	Log("Full Prompt Length: %d characters", len(fullPrompt))
	Log("--- Full Prompt ---")
	Log("%s", fullPrompt)
	Log("--- End Prompt ---")
}

// LogContext logs the gathered context
func LogContext(ctx interface{}) {
	Log("=== CONTEXT ===")
	Log("Context Data: %+v", ctx)
	Log("--- End Context ---")
}

// LogConversationSummary logs a summary of the current conversation
func LogConversationSummary(conversationID string, messageCount int, messages []interface{}) {
	Log("=== CONVERSATION SUMMARY ===")
	Log("Conversation ID: %s", conversationID)
	Log("Message Count: %d", messageCount)
	Log("--- Messages ---")
	for i, msg := range messages {
		Log("Message %d: %+v", i+1, msg)
	}
	Log("--- End Conversation Summary ---")
}

// Close closes the debug log file
func Close() {
	logMutex.Lock()
	defer logMutex.Unlock()

	if logFile != nil {
		logFile.Close()
		logFile = nil
		enabled = false
	}
}
