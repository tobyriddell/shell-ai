package input

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/chzyer/readline"
)

// ReadlineManager manages readline functionality with history
type ReadlineManager struct {
	rl          *readline.Instance
	historyFile string
	prompt      string
}

// NewReadlineManager creates a new readline manager with history support
func NewReadlineManager(prompt string) (*ReadlineManager, error) {
	// Get user's home directory for history file
	homeDir, err := os.UserHomeDir()
	if err != nil {
		homeDir = "."
	}

	// Create config directory if it doesn't exist
	configDir := filepath.Join(homeDir, ".config", "shell-ai")
	if err := os.MkdirAll(configDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create config directory: %w", err)
	}

	historyFile := filepath.Join(configDir, "history")

	// Configure readline
	config := &readline.Config{
		Prompt:              prompt,
		HistoryFile:         historyFile,
		AutoComplete:        createCompleter(),
		InterruptPrompt:     "^C",
		EOFPrompt:           "exit",
		HistorySearchFold:   true,
		FuncFilterInputRune: filterInput,
	}

	rl, err := readline.NewEx(config)
	if err != nil {
		return nil, fmt.Errorf("failed to initialize readline: %w", err)
	}

	return &ReadlineManager{
		rl:          rl,
		historyFile: historyFile,
		prompt:      prompt,
	}, nil
}

// ReadLine reads a line of input with history and editing support
func (rm *ReadlineManager) ReadLine() (string, error) {
	line, err := rm.rl.Readline()
	if err != nil {
		return "", err
	}

	// Trim whitespace and return
	return strings.TrimSpace(line), nil
}

// SetPrompt updates the prompt string
func (rm *ReadlineManager) SetPrompt(prompt string) {
	rm.prompt = prompt
	rm.rl.SetPrompt(prompt)
}

// Close cleanly shuts down the readline instance
func (rm *ReadlineManager) Close() error {
	return rm.rl.Close()
}

// GetHistoryFile returns the path to the history file
func (rm *ReadlineManager) GetHistoryFile() string {
	return rm.historyFile
}

// ClearHistory clears the readline history
func (rm *ReadlineManager) ClearHistory() {
	// Note: chzyer/readline doesn't have a ClearHistory method
	// History is managed through the history file
	// To clear history, we would need to delete the history file
}

// AddToHistory adds a line to the history
func (rm *ReadlineManager) AddToHistory(line string) {
	if strings.TrimSpace(line) != "" {
		rm.rl.SaveHistory(line)
	}
}

// createCompleter creates an auto-completer for shell-ai commands
func createCompleter() readline.AutoCompleter {
	return readline.NewPrefixCompleter(
		readline.PcItem("/help"),
		readline.PcItem("/h"),
		readline.PcItem("/context"),
		readline.PcItem("/ctx"),
		readline.PcItem("/clear"),
		readline.PcItem("/c"),
		readline.PcItem("/send"),
		readline.PcItem("/s"),
		readline.PcItem("/quit"),
		readline.PcItem("/q"),
		readline.PcItem("/exit"),
		readline.PcItem("/provider",
			readline.PcItem("openai"),
			readline.PcItem("anthropic"),
			readline.PcItem("google"),
			readline.PcItem("ollama"),
		),
	)
}

// filterInput filters input runes (can be used to block certain characters)
func filterInput(r rune) (rune, bool) {
	// Allow all printable characters and control characters
	return r, true
}
