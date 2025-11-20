package contextgather

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"runtime"
	"strings"

	"shell-ai-go/pkg/ai"
	"shell-ai-go/pkg/contextmgmt"
	"shell-ai-go/pkg/tmux"
)

// Gatherer collects context information for AI requests
type Gatherer struct {
	tmuxClient         *tmux.Client
	maxHistLines       int
	maxPaneLines       int
	maxPaneContextSize int
	includeHistory     bool
	includePanes       bool
}

// NewGatherer creates a new context gatherer
func NewGatherer(tmuxClient *tmux.Client) *Gatherer {
	return &Gatherer{
		tmuxClient:     tmuxClient,
		maxHistLines:   50,
		includeHistory: true,
		includePanes:   true,
	}
}

// SetOptions configures the gatherer
func (g *Gatherer) SetOptions(maxHistLines int, includeHistory, includePanes bool) {
	g.maxHistLines = maxHistLines
	g.includeHistory = includeHistory
	g.includePanes = includePanes
}

// SetPaneLimits sets limits for pane content gathering
func (g *Gatherer) SetPaneLimits(maxPaneLines, maxPaneContextSize int) {
	g.maxPaneLines = maxPaneLines
	g.maxPaneContextSize = maxPaneContextSize
}

// GatherContext collects all context information
func (g *Gatherer) GatherContext() (*ai.ContextData, error) {
	context := &ai.ContextData{}

	// System information
	sysInfo, err := g.gatherSystemInfo()
	if err != nil {
		return nil, fmt.Errorf("failed to gather system info: %w", err)
	}
	context.SystemInfo = *sysInfo

	// Working directory
	wd, err := os.Getwd()
	if err != nil {
		wd = "unknown"
	}
	context.WorkingDir = wd

	// Environment variables (filtered)
	context.Environment = g.gatherEnvironment()

	// Shell history
	if g.includeHistory {
		history, err := g.gatherShellHistory()
		if err == nil {
			context.ShellHistory = history
		}
	}

	// Tmux pane content
	if g.includePanes && g.tmuxClient.IsInTmux() {
		// Use configured limits for pane content
		paneContent, err := g.tmuxClient.CapturePaneContentWithLimits(g.maxPaneLines, g.maxPaneContextSize)
		if err == nil {
			context.TmuxContent = paneContent
		}
	}

	return context, nil
}

// gatherSystemInfo collects system information
func (g *Gatherer) gatherSystemInfo() (*ai.SystemInfo, error) {
	info := &ai.SystemInfo{
		OS: runtime.GOOS,
	}

	// Get hostname
	hostname, err := os.Hostname()
	if err == nil {
		info.Hostname = hostname
	}

	// Get current user
	currentUser, err := user.Current()
	if err == nil {
		info.User = currentUser.Username
	}

	// Get shell
	shell := os.Getenv("SHELL")
	if shell == "" {
		shell = "unknown"
	} else {
		shell = filepath.Base(shell)
	}
	info.Shell = shell

	return info, nil
}

// gatherEnvironment collects relevant environment variables
func (g *Gatherer) gatherEnvironment() []string {
	// Only include relevant environment variables
	relevant := []string{
		"PATH", "HOME", "USER", "SHELL", "TERM", "PWD",
		"LANG", "LC_ALL", "EDITOR", "PAGER",
	}

	var env []string
	for _, key := range relevant {
		if value := os.Getenv(key); value != "" {
			env = append(env, fmt.Sprintf("%s=%s", key, value))
		}
	}

	return env
}

// gatherShellHistory collects shell command history
func (g *Gatherer) gatherShellHistory() ([]string, error) {
	// Try atuin first (enhanced history)
	if history, err := g.getAtuinHistory(); err == nil && len(history) > 0 {
		return history, nil
	}

	// Fall back to shell-specific history
	shell := os.Getenv("SHELL")
	if strings.Contains(shell, "zsh") {
		return g.getZshHistory()
	} else if strings.Contains(shell, "bash") {
		return g.getBashHistory()
	}

	return nil, fmt.Errorf("unsupported shell for history: %s", shell)
}

// getAtuinHistory gets history from atuin if available
func (g *Gatherer) getAtuinHistory() ([]string, error) {
	// Check if invoked from tmux - if so, use global history instead of session-specific
	var cmd *exec.Cmd
	if os.Getenv("AI_SHELL_TMUX_INVOKED") != "" || g.tmuxClient.IsInTmux() {
		// Use global history when invoked from tmux (drop -s flag)
		cmd = exec.Command("atuin", "history", "list", "-f", "{command}")
	} else {
		// Use session-specific history for normal invocations
		cmd = exec.Command("atuin", "history", "list", "-s", "-f", "{command}")
	}

	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	lines := strings.Split(string(output), "\n")

	// Filter out empty lines and get last N lines
	var filteredLines []string
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line != "" {
			filteredLines = append(filteredLines, line)
		}
	}

	// Get last N lines
	start := 0
	if len(filteredLines) > g.maxHistLines {
		start = len(filteredLines) - g.maxHistLines
	}

	return filteredLines[start:], nil
}

// getZshHistory gets history from zsh
func (g *Gatherer) getZshHistory() ([]string, error) {
	// Try fc command first
	cmd := exec.Command("fc", "-l", fmt.Sprintf("-%d", g.maxHistLines))
	output, err := cmd.Output()
	if err == nil {
		lines := strings.Split(string(output), "\n")
		var history []string
		for _, line := range lines {
			// Remove line numbers from fc output
			if idx := strings.Index(line, " "); idx > 0 && idx < 10 {
				cmd := strings.TrimSpace(line[idx:])
				if cmd != "" {
					history = append(history, cmd)
				}
			}
		}
		return history, nil
	}

	// Fall back to history file
	return g.readHistoryFile("~/.zsh_history")
}

// getBashHistory gets history from bash
func (g *Gatherer) getBashHistory() ([]string, error) {
	return g.readHistoryFile("~/.bash_history")
}

// readHistoryFile reads commands from a history file
func (g *Gatherer) readHistoryFile(filename string) ([]string, error) {
	// Expand home directory
	home, err := os.UserHomeDir()
	if err != nil {
		return nil, err
	}

	if strings.HasPrefix(filename, "~/") {
		filename = filepath.Join(home, filename[2:])
	}

	file, err := os.Open(filename)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var lines []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line != "" && !strings.HasPrefix(line, "#") {
			lines = append(lines, line)
		}
	}

	// Get last N lines
	start := 0
	if len(lines) > g.maxHistLines {
		start = len(lines) - g.maxHistLines
	}

	return lines[start:], scanner.Err()
}

// FormatContext formats context data for AI consumption
func (g *Gatherer) FormatContext(ctx *ai.ContextData, conversation *ai.Conversation) string {
	return g.FormatContextWithLimits(ctx, conversation, nil)
}

// FormatContextWithLimits formats context data with optional context limits
func (g *Gatherer) FormatContextWithLimits(ctx *ai.ContextData, conversation *ai.Conversation, limits *contextmgmt.ContextLimits) string {
	var builder strings.Builder

	// System context
	builder.WriteString("=== SYSTEM CONTEXT ===\n")
	builder.WriteString(fmt.Sprintf("OS: %s\n", ctx.SystemInfo.OS))
	builder.WriteString(fmt.Sprintf("Hostname: %s\n", ctx.SystemInfo.Hostname))
	builder.WriteString(fmt.Sprintf("User: %s\n", ctx.SystemInfo.User))
	builder.WriteString(fmt.Sprintf("Shell: %s\n", ctx.SystemInfo.Shell))
	builder.WriteString(fmt.Sprintf("Working Directory: %s\n", ctx.WorkingDir))
	builder.WriteString("\n")

	// Environment
	if len(ctx.Environment) > 0 {
		builder.WriteString("=== ENVIRONMENT ===\n")
		for _, env := range ctx.Environment {
			builder.WriteString(fmt.Sprintf("%s\n", env))
		}
		builder.WriteString("\n")
	}

	// Shell history
	if len(ctx.ShellHistory) > 0 {
		builder.WriteString("=== RECENT SHELL HISTORY ===\n")
		for _, cmd := range ctx.ShellHistory {
			builder.WriteString(fmt.Sprintf("%s\n", cmd))
		}
		builder.WriteString("=== END OF SHELL HISTORY ===\n\n")
	}

	// Tmux content
	if len(ctx.TmuxContent) > 0 {
		builder.WriteString("=== TMUX WINDOW CONTENT ===\n")
		for _, pane := range ctx.TmuxContent {
			marker := fmt.Sprintf("PANE %s", pane.PaneID)
			if pane.IsActive {
				marker += " (ACTIVE)"
			}
			if pane.Title != "" && pane.Title != "bash" && pane.Title != "zsh" {
				marker += fmt.Sprintf(" - %s", pane.Title)
			}

			builder.WriteString(fmt.Sprintf("\n--- %s ---\n", marker))
			if pane.Content != "" {
				builder.WriteString(pane.Content)
				builder.WriteString("\n")
			} else {
				builder.WriteString("(empty pane)\n")
			}
		}
		builder.WriteString("\n=== END TMUX CONTENT ===\n\n")
	}

	// Conversation history with optional truncation
	if conversation != nil && len(conversation.Messages) > 0 {
		builder.WriteString("=== CONVERSATION HISTORY ===\n")

		// Apply context limits if provided
		messages := conversation.Messages
		if limits != nil && len(messages) > limits.MaxMessages {
			// Convert to context messages for truncation
			contextMessages := make([]contextmgmt.Message, len(messages))
			for i, msg := range messages {
				contextMessages[i] = contextmgmt.Message{
					Role:      string(msg.Role),
					Content:   msg.Content,
					Timestamp: msg.Timestamp.Format("2006-01-02 15:04:05"),
				}
			}

			// Truncate using context limits
			truncated := limits.TruncateConversation(contextMessages)

			// Convert back to AI messages
			messages = make([]ai.Message, len(truncated))
			for i, msg := range truncated {
				messages[i] = ai.Message{
					Role:      ai.MessageRole(msg.Role),
					Content:   msg.Content,
					Timestamp: conversation.Messages[0].Timestamp, // Use original timestamp
				}
			}

			// Log truncation if it occurred
			if len(truncated) < len(conversation.Messages) {
				removed := len(conversation.Messages) - len(truncated)
				builder.WriteString(fmt.Sprintf("(Truncated: removed %d old messages, showing %d most recent)\n", removed, len(truncated)))
			}
		}

		for _, msg := range messages {
			role := strings.ToUpper(string(msg.Role))
			builder.WriteString(fmt.Sprintf("[%s]: %s\n\n", role, msg.Content))
		}
		builder.WriteString("=== END CONVERSATION HISTORY ===\n\n")
	}

	return builder.String()
}
