package session

import (
	"context"
	"fmt"
	"io"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"syscall"
	"time"

	"shell-ai-go/pkg/ai"
	"shell-ai-go/pkg/config"
	"shell-ai-go/pkg/contextgather"
	"shell-ai-go/pkg/contextmgmt"
	"shell-ai-go/pkg/debug"
	"shell-ai-go/pkg/input"
	"shell-ai-go/pkg/response"
	"shell-ai-go/pkg/storage"
	"shell-ai-go/pkg/tmux"

	"github.com/charmbracelet/lipgloss"
	"github.com/chzyer/readline"
)

// InteractiveSession manages an interactive AI conversation session
type InteractiveSession struct {
	config          *config.Config
	aiManager       *ai.Manager
	tmuxClient      *tmux.Client
	contextGatherer *contextgather.Gatherer
	responseParser  *response.Parser
	conversationID  string
	styles          *sessionStyles
	readlineManager *input.ReadlineManager
	contextManager  *contextmgmt.Manager
}

// sessionStyles contains styling for the interactive session
type sessionStyles struct {
	prompt    lipgloss.Style
	user      lipgloss.Style
	assistant lipgloss.Style
	system    lipgloss.Style
	error     lipgloss.Style
	warning   lipgloss.Style
	success   lipgloss.Style
	command   lipgloss.Style
}

// NewInteractiveSession creates a new interactive session
func NewInteractiveSession(cfg *config.Config, tmuxClient *tmux.Client) *InteractiveSession {
	styles := &sessionStyles{
		prompt:    lipgloss.NewStyle().Foreground(lipgloss.Color("12")).Bold(true), // Bright blue
		user:      lipgloss.NewStyle().Foreground(lipgloss.Color("10")),            // Bright green
		assistant: lipgloss.NewStyle().Foreground(lipgloss.Color("14")),            // Bright cyan
		system:    lipgloss.NewStyle().Foreground(lipgloss.Color("7")),             // Light gray (bright)
		error:     lipgloss.NewStyle().Foreground(lipgloss.Color("9")).Bold(true),  // Bright red
		warning:   lipgloss.NewStyle().Foreground(lipgloss.Color("11")),            // Bright yellow
		success:   lipgloss.NewStyle().Foreground(lipgloss.Color("10")),            // Bright green
		command:   lipgloss.NewStyle().Foreground(lipgloss.Color("13")).Bold(true), // Bright magenta
	}

	// Initialize readline manager
	readlineManager, err := input.NewReadlineManager("🤖 AI> ")
	if err != nil {
		fmt.Printf("Warning: Failed to initialize readline: %v\n", err)
		readlineManager = nil
	}

	// Create AI manager
	aiManager := cfg.CreateAIManager()

	// Always enable storage for interactive sessions (required for conversation persistence)
	var storageInstance storage.Storage
	storage, err := storage.NewSQLiteStorage()
	if err != nil {
		fmt.Printf("Warning: Failed to initialize storage: %v\n", err)
		fmt.Printf("Warning: Conversation persistence and commands like /list, /load, /delete will not be available\n")
	} else {
		storageInstance = storage
		storageAdapter := ai.NewStorageAdapter(storage)
		aiManager.SetStorageAdapter(storageAdapter)
		aiManager.SetUseStorage(true)
	}

	// Create context manager
	contextLimits := cfg.CreateContextLimits()
	contextManager := contextmgmt.NewManager(contextLimits, storageInstance)

	// Initialize debug logger
	debug.Init()

	return &InteractiveSession{
		config:          cfg,
		aiManager:       aiManager,
		tmuxClient:      tmuxClient,
		contextGatherer: contextgather.NewGatherer(tmuxClient),
		responseParser:  response.NewParser(),
		conversationID:  fmt.Sprintf("session-%d", time.Now().Unix()),
		styles:          styles,
		readlineManager: readlineManager,
		contextManager:  contextManager,
	}
}

// Run starts the interactive session
func (s *InteractiveSession) Run() error {
	// Ensure debug logger is closed on exit
	defer debug.Close()

	// Ensure readline manager is cleaned up on exit
	if s.readlineManager != nil {
		defer s.readlineManager.Close()
	}

	// Setup signal handling for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// Print welcome message
	s.printWelcome()

	// Setup context gatherer options
	s.contextGatherer.SetOptions(
		s.config.Settings.MaxHistoryLines,
		true,                    // include history
		s.tmuxClient.IsInTmux(), // include panes if in tmux
	)
	// Set pane limits for context gathering
	s.contextGatherer.SetPaneLimits(
		s.config.Settings.MaxPaneLines,
		s.config.Settings.MaxPaneContextSize,
	)

	// Perform cleanup of old conversations
	if err := s.contextManager.PerformCleanup(); err != nil {
		fmt.Printf("Warning: Failed to cleanup old conversations: %v\n", err)
	}

	// Main interaction loop
	for {
		var input string
		var err error

		// Build prompt with context usage indicator
		prompt := s.buildPrompt()

		// Check if readline is available
		if s.readlineManager != nil {
			// Use readline for input with history and editing
			s.readlineManager.SetPrompt(prompt)
			input, err = s.readlineManager.ReadLine()
			if err != nil {
				if err == readline.ErrInterrupt {
					// Handle Ctrl+C
					fmt.Println("\n" + s.styles.system.Render("Session interrupted. Goodbye!"))
					return nil
				} else if err == io.EOF {
					// Handle Ctrl+D
					fmt.Println("\n" + s.styles.system.Render("Session ended (Ctrl-D). Goodbye!"))
					return nil
				}
				return fmt.Errorf("readline error: %w", err)
			}
		} else {
			// Fallback to basic input if readline failed to initialize
			fmt.Print(s.styles.prompt.Render(prompt))

			// Create channels for concurrent input and signal handling
			inputChan := make(chan string, 1)
			errChan := make(chan error, 1)

			// Read input in a goroutine for signal handling
			go func() {
				var line string
				fmt.Scanln(&line)
				inputChan <- line
			}()

			// Wait for input or signal
			select {
			case <-sigChan:
				fmt.Println("\n" + s.styles.system.Render("Session interrupted. Goodbye!"))
				return nil
			case input = <-inputChan:
				// Continue with input processing
			case err := <-errChan:
				if err == io.EOF {
					fmt.Println("\n" + s.styles.system.Render("Session ended (Ctrl-D). Goodbye!"))
					return nil
				}
				return fmt.Errorf("input error: %w", err)
			}
		}

		// Skip empty input
		if input == "" {
			continue
		}

		// Add to history if using readline
		if s.readlineManager != nil {
			s.readlineManager.AddToHistory(input)
		}

		// Handle special commands
		if s.handleSpecialCommands(input) {
			continue
		}

		// Process AI query
		if err := s.processQuery(input); err != nil {
			fmt.Println(s.styles.error.Render(fmt.Sprintf("Error: %v", err)))
		}
	}
}

// printWelcome displays the welcome message
func (s *InteractiveSession) printWelcome() {
	fmt.Println(s.styles.success.Render("🚀 Shell AI Interactive Session"))
	fmt.Println(s.styles.system.Render("===================================="))
	fmt.Println()

	// Show active provider
	if provider, err := s.aiManager.GetActiveProvider(); err == nil {
		fmt.Println(s.styles.system.Render(fmt.Sprintf("Active AI Provider: %s", provider.Name())))
	} else {
		fmt.Println(s.styles.warning.Render("Warning: No active AI provider configured"))
	}

	// Show tmux status
	if s.tmuxClient.IsInTmux() {
		fmt.Println(s.styles.system.Render("Tmux integration: Enabled"))
	} else {
		fmt.Println(s.styles.warning.Render("Tmux integration: Disabled (not in tmux)"))
	}

	fmt.Println()
	fmt.Println(s.styles.system.Render("Commands:"))
	fmt.Println(s.styles.system.Render("  Type your questions naturally"))
	fmt.Println(s.styles.system.Render("  /help     - Show help"))
	fmt.Println(s.styles.system.Render("  /context  - Show current context"))
	fmt.Println(s.styles.system.Render("  /clear    - Clear conversation"))
	fmt.Println(s.styles.system.Render("  /history  - Show command history location"))
	fmt.Println(s.styles.system.Render("  /list     - List saved conversations"))
	fmt.Println(s.styles.system.Render("  /load     - Load a conversation by ID"))
	fmt.Println(s.styles.system.Render("  /delete   - Delete a conversation"))
	fmt.Println(s.styles.system.Render("  /stats    - Show context usage statistics"))
	fmt.Println(s.styles.system.Render("  /context-usage - Show current context usage"))
	fmt.Println(s.styles.system.Render("  /context-max <size> - Set maximum context size (bytes, KB, MB)"))
	fmt.Println(s.styles.system.Render("  /send     - Send last response to tmux pane"))
	fmt.Println(s.styles.system.Render("  /quit     - Exit session"))
	fmt.Println(s.styles.system.Render("  Ctrl-D    - Exit session"))
	fmt.Println()
	fmt.Println(s.styles.system.Render("History Features:"))
	fmt.Println(s.styles.system.Render("  ↑/↓ arrows - Navigate history"))
	fmt.Println(s.styles.system.Render("  Ctrl-R     - Search history"))
	fmt.Println(s.styles.system.Render("  Tab        - Auto-complete commands"))
	fmt.Println()
}

// handleSpecialCommands processes special session commands
func (s *InteractiveSession) handleSpecialCommands(input string) bool {
	switch strings.ToLower(input) {
	case "/help", "/h":
		s.showHelp()
		return true
	case "/context", "/ctx":
		s.showContext()
		return true
	case "/clear", "/c":
		s.clearConversation()
		return true
	case "/history", "/hist":
		s.showHistory()
		return true
	case "/list", "/ls":
		s.listConversations()
		return true
	case "/stats":
		s.showContextStats()
		return true
	case "/context-usage", "/ctx-usage", "/ctxusage":
		s.showContextUsageSummary()
		return true
	case "/send", "/s":
		s.sendToPane()
		return true
	case "/quit", "/q", "/exit":
		fmt.Println(s.styles.system.Render("Goodbye!"))
		os.Exit(0)
		return true
	default:
		if strings.HasPrefix(input, "/provider ") {
			s.switchProvider(strings.TrimSpace(input[10:]))
			return true
		} else if strings.HasPrefix(input, "/load ") {
			s.loadConversation(strings.TrimSpace(input[6:]))
			return true
		} else if strings.HasPrefix(input, "/delete ") {
			s.deleteConversation(strings.TrimSpace(input[8:]))
			return true
		} else if strings.HasPrefix(strings.ToLower(input), "/context-max ") {
			s.setMaxContextSize(strings.TrimSpace(input[len("/context-max "):]))
			return true
		}
		return false
	}
}

// processQuery processes an AI query
func (s *InteractiveSession) processQuery(query string) error {
	// Gather context
	fmt.Print(s.styles.system.Render("Gathering context... "))
	ctx, err := s.contextGatherer.GatherContext()
	if err != nil {
		fmt.Println(s.styles.error.Render("failed"))
		return fmt.Errorf("failed to gather context: %w", err)
	}
	fmt.Println(s.styles.success.Render("done"))

	// Get conversation
	conversation := s.aiManager.GetOrCreateConversation(s.conversationID)

	// Process conversation with context limits
	processedConversation, err := s.contextManager.ProcessConversation(conversation)
	if err != nil {
		return fmt.Errorf("failed to process conversation: %w", err)
	}

	// Format context with limits
	contextLimits := s.config.CreateContextLimits()
	contextStr := s.contextGatherer.FormatContextWithLimits(ctx, processedConversation, contextLimits)

	// Log context for debugging
	debug.LogContext(ctx)

	// Log conversation summary for debugging
	messages := make([]interface{}, len(processedConversation.Messages))
	for i, msg := range processedConversation.Messages {
		contentPreview := msg.Content
		if len(contentPreview) > 100 {
			contentPreview = contentPreview[:100] + "..."
		}
		messages[i] = map[string]interface{}{
			"role":    string(msg.Role),
			"content": contentPreview,
			"time":    msg.Timestamp.Format(time.RFC3339),
		}
	}
	debug.LogConversationSummary(s.conversationID, len(processedConversation.Messages), messages)

	// Create full prompt using configurable default prompt
	defaultPrompt := s.config.Settings.DefaultPrompt
	if defaultPrompt == "" {
		defaultPrompt = "Please provide a helpful response. If you're suggesting shell commands, format them clearly so they can be easily copied and executed."
	}
	fullPrompt := contextStr + "\n=== USER PROMPT ===\n" + query + "\n\n" + defaultPrompt

	// Get provider name for logging
	providerName := "unknown"
	if provider, err := s.aiManager.GetActiveProvider(); err == nil {
		providerName = provider.Name()
	}

	// Log prompt for debugging
	debug.LogPrompt(s.conversationID, providerName, fullPrompt)

	// Show thinking indicator
	fmt.Print(s.styles.system.Render("Thinking... "))

	// Send to AI
	response, err := s.aiManager.Chat(context.Background(), s.conversationID, fullPrompt)
	if err != nil {
		fmt.Println(s.styles.error.Render("failed"))
		return err
	}
	fmt.Println(s.styles.success.Render("done"))

	// Display response
	fmt.Println()
	fmt.Println(s.styles.assistant.Render("🤖 Assistant:"))
	fmt.Println(response.Content)
	fmt.Println()

	// Extract and display commands if any
	extraction := s.responseParser.ExtractCommands(response.Content)
	if len(extraction.Commands) > 0 {
		fmt.Println(s.styles.command.Render("📋 Extracted Commands:"))
		fmt.Println(s.responseParser.FormatCommands(extraction.Commands))
		fmt.Println()

		if s.tmuxClient.IsInTmux() {
			fmt.Println(s.styles.system.Render("Use '/send' to send commands to a tmux pane"))
		}
		fmt.Println()
	}

	return nil
}

// showHelp displays help information
func (s *InteractiveSession) showHelp() {
	fmt.Println(s.styles.system.Render("Shell AI Help"))
	fmt.Println(s.styles.system.Render("=============="))
	fmt.Println()
	fmt.Println(s.styles.system.Render("Available Commands:"))
	fmt.Println(s.styles.system.Render("  /help              - Show this help"))
	fmt.Println(s.styles.system.Render("  /context           - Show current context"))
	fmt.Println(s.styles.system.Render("  /clear             - Clear conversation history"))
	fmt.Println(s.styles.system.Render("  /history           - Show command history location"))
	fmt.Println(s.styles.system.Render("  /list              - List saved conversations"))
	fmt.Println(s.styles.system.Render("  /load <id>         - Load a conversation by ID"))
	fmt.Println(s.styles.system.Render("  /delete <id>       - Delete a conversation"))
	fmt.Println(s.styles.system.Render("  /stats             - Show context usage statistics"))
	fmt.Println(s.styles.system.Render("  /context-usage     - Show current context usage"))
	fmt.Println(s.styles.system.Render("  /context-max <size>- Set maximum context size (bytes, KB, MB)"))
	fmt.Println(s.styles.system.Render("  /send              - Send last commands to tmux pane"))
	fmt.Println(s.styles.system.Render("  /provider <name>   - Switch AI provider"))
	fmt.Println(s.styles.system.Render("  /quit              - Exit session"))
	fmt.Println()
	fmt.Println(s.styles.system.Render("History Features:"))
	fmt.Println(s.styles.system.Render("  ↑/↓ arrows        - Navigate through command history"))
	fmt.Println(s.styles.system.Render("  Ctrl-R             - Search command history"))
	fmt.Println(s.styles.system.Render("  Tab                - Auto-complete commands"))
	fmt.Println()
	fmt.Println(s.styles.system.Render("Tips:"))
	fmt.Println(s.styles.system.Render("  - Ask natural questions about shell commands"))
	fmt.Println(s.styles.system.Render("  - Context includes your shell history and tmux content"))
	fmt.Println(s.styles.system.Render("  - Commands are automatically extracted and safety-checked"))
	fmt.Println(s.styles.system.Render("  - Use Ctrl-D to exit gracefully"))
	fmt.Println()
}

// showContext displays the current context
func (s *InteractiveSession) showContext() {
	fmt.Println(s.styles.system.Render("Current Context"))
	fmt.Println(s.styles.system.Render("==============="))
	fmt.Println()

	ctx, err := s.contextGatherer.GatherContext()
	if err != nil {
		fmt.Println(s.styles.error.Render(fmt.Sprintf("Error gathering context: %v", err)))
		return
	}

	conversation := s.aiManager.GetOrCreateConversation(s.conversationID)

	// Process conversation with context limits (same as regular queries)
	processedConversation, err := s.contextManager.ProcessConversation(conversation)
	if err != nil {
		fmt.Println(s.styles.error.Render(fmt.Sprintf("Error processing conversation: %v", err)))
		return
	}

	// Format context with limits (same as regular queries)
	contextLimits := s.config.CreateContextLimits()
	contextStr := s.contextGatherer.FormatContextWithLimits(ctx, processedConversation, contextLimits)

	fmt.Println(contextStr)
}

// showHistory displays history information
func (s *InteractiveSession) showHistory() {
	fmt.Println(s.styles.system.Render("Command History"))
	fmt.Println(s.styles.system.Render("==============="))
	fmt.Println()

	if s.readlineManager != nil {
		historyFile := s.readlineManager.GetHistoryFile()
		fmt.Println(s.styles.system.Render(fmt.Sprintf("History file: %s", historyFile)))

		// Check if history file exists and get stats
		if info, err := os.Stat(historyFile); err == nil {
			fmt.Println(s.styles.system.Render(fmt.Sprintf("History file size: %d bytes", info.Size())))
			fmt.Println(s.styles.system.Render(fmt.Sprintf("Last modified: %s", info.ModTime().Format("2006-01-02 15:04:05"))))
		} else {
			fmt.Println(s.styles.warning.Render("History file does not exist yet"))
		}

		fmt.Println()
		fmt.Println(s.styles.system.Render("Usage:"))
		fmt.Println(s.styles.system.Render("  ↑/↓ arrows - Navigate through history"))
		fmt.Println(s.styles.system.Render("  Ctrl-R      - Search history backwards"))
		fmt.Println(s.styles.system.Render("  Ctrl-S      - Search history forwards"))
		fmt.Println(s.styles.system.Render("  Tab         - Auto-complete commands"))
	} else {
		fmt.Println(s.styles.warning.Render("Readline not available - history features disabled"))
	}
	fmt.Println()
}

// listConversations lists saved conversations
func (s *InteractiveSession) listConversations() {
	fmt.Println(s.styles.system.Render("Saved Conversations"))
	fmt.Println(s.styles.system.Render("==================="))
	fmt.Println()

	summaries, err := s.aiManager.ListConversations(20, 0)
	if err != nil {
		if err.Error() == "storage not available" {
			fmt.Println(s.styles.error.Render("Storage is not available. This may happen if:"))
			fmt.Println(s.styles.error.Render("  - The database file could not be created"))
			fmt.Println(s.styles.error.Render("  - There are permission issues with ~/.config/shell-ai/"))
			fmt.Println(s.styles.error.Render("  - Storage initialization failed during session startup"))
			fmt.Println()
			fmt.Println(s.styles.system.Render("Check the startup warnings for more details."))
		} else {
			fmt.Println(s.styles.error.Render(fmt.Sprintf("Error listing conversations: %v", err)))
		}
		return
	}

	if len(summaries) == 0 {
		fmt.Println(s.styles.system.Render("No saved conversations found."))
		return
	}

	for i, summary := range summaries {
		status := ""
		if summary.ID == s.conversationID {
			status = s.styles.success.Render(" (current)")
		}

		fmt.Printf("%2d. %s%s\n", i+1, s.styles.command.Render(summary.ID), status)
		if summary.Title != "" {
			fmt.Printf("    %s\n", s.styles.system.Render(summary.Title))
		}
		fmt.Printf("    %s messages, updated %s\n",
			s.styles.system.Render(fmt.Sprintf("%d", summary.MessageCount)),
			s.styles.system.Render(summary.Updated.Format("2006-01-02 15:04:05")))
		if summary.LastMessage != "" {
			lastMsg := summary.LastMessage
			if len(lastMsg) > 60 {
				lastMsg = lastMsg[:57] + "..."
			}
			fmt.Printf("    %s\n", s.styles.system.Render(fmt.Sprintf("Last: %s", lastMsg)))
		}
		fmt.Println()
	}
}

// loadConversation loads a conversation by ID
func (s *InteractiveSession) loadConversation(id string) {
	if id == "" {
		fmt.Println(s.styles.error.Render("Usage: /load <conversation_id>"))
		return
	}

	// Load conversation from storage
	storageAdapter := s.aiManager.GetStorageAdapter()
	if storageAdapter == nil {
		fmt.Println(s.styles.error.Render("Storage is not available. This may happen if:"))
		fmt.Println(s.styles.error.Render("  - The database file could not be created"))
		fmt.Println(s.styles.error.Render("  - There are permission issues with ~/.config/shell-ai/"))
		fmt.Println(s.styles.error.Render("  - Storage initialization failed during session startup"))
		fmt.Println()
		fmt.Println(s.styles.system.Render("Check the startup warnings for more details."))
		return
	}

	ctx := context.Background()
	conversation, err := storageAdapter.GetOrCreateConversation(ctx, id)
	if err != nil {
		fmt.Println(s.styles.error.Render(fmt.Sprintf("Error loading conversation: %v", err)))
		return
	}

	// Switch to the loaded conversation
	s.conversationID = id
	s.aiManager.GetConversations()[id] = conversation

	fmt.Println(s.styles.success.Render(fmt.Sprintf("Loaded conversation: %s", id)))
	fmt.Println(s.styles.system.Render(fmt.Sprintf("Messages: %d", len(conversation.Messages))))
}

// deleteConversation deletes a conversation by ID
func (s *InteractiveSession) deleteConversation(id string) {
	if id == "" {
		fmt.Println(s.styles.error.Render("Usage: /delete <conversation_id>"))
		return
	}

	// Confirm deletion
	fmt.Printf("Are you sure you want to delete conversation '%s'? (y/N): ", id)
	var response string
	fmt.Scanln(&response)

	if strings.ToLower(response) != "y" && strings.ToLower(response) != "yes" {
		fmt.Println(s.styles.system.Render("Deletion cancelled."))
		return
	}

	err := s.aiManager.DeleteConversation(id)
	if err != nil {
		if err.Error() == "storage not available" {
			fmt.Println(s.styles.error.Render("Storage is not available. This may happen if:"))
			fmt.Println(s.styles.error.Render("  - The database file could not be created"))
			fmt.Println(s.styles.error.Render("  - There are permission issues with ~/.config/shell-ai/"))
			fmt.Println(s.styles.error.Render("  - Storage initialization failed during session startup"))
			fmt.Println()
			fmt.Println(s.styles.system.Render("Check the startup warnings for more details."))
		} else {
			fmt.Println(s.styles.error.Render(fmt.Sprintf("Error deleting conversation: %v", err)))
		}
		return
	}

	// If we deleted the current conversation, create a new one
	if id == s.conversationID {
		s.conversationID = fmt.Sprintf("session-%d", time.Now().Unix())
		fmt.Println(s.styles.success.Render("Conversation deleted. Started new conversation."))
	} else {
		fmt.Println(s.styles.success.Render("Conversation deleted."))
	}
}

// showContextStats displays context usage statistics
func (s *InteractiveSession) showContextStats() {
	fmt.Println(s.styles.system.Render("Context Usage Statistics"))
	fmt.Println(s.styles.system.Render("========================="))
	fmt.Println()

	// Get current conversation
	conversation := s.aiManager.GetOrCreateConversation(s.conversationID)

	// Get context stats
	stats := s.contextManager.GetContextStats(conversation)

	// Display stats
	fmt.Printf("Current Conversation: %s\n", s.styles.command.Render(s.conversationID))
	fmt.Printf("Messages: %d/%d\n", stats.MessageCount, stats.MaxMessages)
	fmt.Printf("Estimated Tokens: %d/%d\n", stats.TokenCount, stats.MaxTokens)
	fmt.Printf("Context Size: %s/%s\n",
		contextmgmt.FormatSize(stats.ContextSize),
		contextmgmt.FormatSize(stats.MaxContextSize))

	if stats.TruncationNeeded {
		fmt.Println(s.styles.warning.Render("⚠️  Context truncation is needed"))
	} else {
		fmt.Println(s.styles.success.Render("✅ Context within limits"))
	}

	fmt.Println()
	fmt.Println(s.styles.system.Render("Configuration:"))
	fmt.Printf("  Max Messages: %d\n", stats.MaxMessages)
	fmt.Printf("  Max Tokens: %d\n", stats.MaxTokens)
	fmt.Printf("  Max Context Size: %s\n", contextmgmt.FormatSize(stats.MaxContextSize))
	fmt.Printf("  Keep Initial Messages: %d\n", s.config.Settings.KeepInitialMessages)
	fmt.Printf("  Truncation Strategy: %s\n", s.config.Settings.TruncationStrategy)

	if !stats.LastCleanup.IsZero() {
		fmt.Printf("  Last Cleanup: %s\n", stats.LastCleanup.Format("2006-01-02 15:04:05"))
	}

	fmt.Println()
}

// showContextUsageSummary displays a concise view of context usage
func (s *InteractiveSession) showContextUsageSummary() {
	stats := s.getContextStats()

	fmt.Println(s.styles.system.Render("Context Usage"))
	fmt.Println(s.styles.system.Render("=============="))

	if stats.MaxContextSize <= 0 {
		fmt.Println(s.styles.warning.Render("Context usage information is not available (max size is zero)."))
		return
	}

	indicator := s.buildContextUsageIndicator(stats)
	usagePercent := s.calculateUsagePercent(stats)

	fmt.Printf("%s  %s/%s (%.0f%%)\n",
		s.styles.command.Render(indicator),
		contextmgmt.FormatSize(stats.ContextSize),
		contextmgmt.FormatSize(stats.MaxContextSize),
		usagePercent)

	if stats.TruncationNeeded {
		fmt.Println(s.styles.warning.Render("⚠️  Context exceeds current limit"))
	} else {
		fmt.Println(s.styles.success.Render("✅ Context within limit"))
	}

	fmt.Println()
}

// setMaxContextSize updates the maximum context size setting
func (s *InteractiveSession) setMaxContextSize(value string) {
	if strings.TrimSpace(value) == "" {
		fmt.Println(s.styles.error.Render("Usage: /context-max <bytes|KB|MB>"))
		return
	}

	bytes, err := parseSizeString(value)
	if err != nil {
		fmt.Println(s.styles.error.Render(fmt.Sprintf("Invalid size: %v", err)))
		return
	}

	if bytes <= 0 {
		fmt.Println(s.styles.error.Render("Context size must be greater than zero."))
		return
	}

	s.config.Settings.MaxContextSize = bytes
	if err := config.SaveConfig(s.config); err != nil {
		fmt.Println(s.styles.error.Render(fmt.Sprintf("Failed to save config: %v", err)))
		return
	}

	// Update manager limits immediately
	s.contextManager.UpdateLimits(s.config.CreateContextLimits())

	fmt.Println(s.styles.success.Render(
		fmt.Sprintf("Max context size set to %s", contextmgmt.FormatSize(bytes)),
	))
}

// buildPrompt constructs the dynamic prompt with context usage indicator
func (s *InteractiveSession) buildPrompt() string {
	stats := s.getContextStats()
	indicator := s.buildContextUsageIndicator(stats)

	if indicator == "" {
		return "🤖 AI> "
	}

	return fmt.Sprintf("%s 🤖 AI> ", indicator)
}

// getContextStats retrieves context stats for the current conversation
func (s *InteractiveSession) getContextStats() contextmgmt.ContextStats {
	conversation := s.aiManager.GetOrCreateConversation(s.conversationID)
	return s.contextManager.GetContextStats(conversation)
}

// buildContextUsageIndicator generates a bar indicator for context usage
func (s *InteractiveSession) buildContextUsageIndicator(stats contextmgmt.ContextStats) string {
	if stats.MaxContextSize <= 0 {
		return ""
	}

	usagePercent := s.calculateUsagePercent(stats)
	if usagePercent < 0 {
		usagePercent = 0
	}

	if usagePercent > 100 {
		usagePercent = 100
	}

	const barWidth = 10
	filledBars := int((usagePercent / 100) * barWidth)
	if filledBars > barWidth {
		filledBars = barWidth
	}

	bar := strings.Repeat("█", filledBars) + strings.Repeat("░", barWidth-filledBars)
	return fmt.Sprintf("[%s] %3.0f%%", bar, usagePercent)
}

// calculateUsagePercent calculates usage percentage for context stats
func (s *InteractiveSession) calculateUsagePercent(stats contextmgmt.ContextStats) float64 {
	if stats.MaxContextSize <= 0 {
		return 0
	}

	return (float64(stats.ContextSize) / float64(stats.MaxContextSize)) * 100
}

// parseSizeString parses size strings like "50k", "20MB", etc.
func parseSizeString(value string) (int, error) {
	value = strings.TrimSpace(strings.ToLower(value))
	if value == "" {
		return 0, fmt.Errorf("empty size")
	}

	multipliers := map[string]int{
		"kb": 1024,
		"k":  1024,
		"mb": 1024 * 1024,
		"m":  1024 * 1024,
		"gb": 1024 * 1024 * 1024,
		"g":  1024 * 1024 * 1024,
	}

	multiplier := 1
	for suffix, mult := range multipliers {
		if strings.HasSuffix(value, suffix) {
			value = strings.TrimSpace(strings.TrimSuffix(value, suffix))
			multiplier = mult
			break
		}
	}

	number, err := strconv.ParseFloat(value, 64)
	if err != nil {
		return 0, err
	}

	bytes := int(number * float64(multiplier))
	if bytes <= 0 {
		return 0, fmt.Errorf("size must be greater than zero")
	}

	return bytes, nil
}

// clearConversation clears the current conversation
func (s *InteractiveSession) clearConversation() {
	// Create new conversation ID
	s.conversationID = fmt.Sprintf("session-%d", time.Now().Unix())
	fmt.Println(s.styles.success.Render("Conversation cleared. Starting fresh context."))
}

// sendToPane sends the last response commands to a tmux pane
func (s *InteractiveSession) sendToPane() {
	if !s.tmuxClient.IsInTmux() {
		fmt.Println(s.styles.warning.Render("Not running in tmux. Cannot send to pane."))
		return
	}

	// Get the last conversation
	conversation := s.aiManager.GetOrCreateConversation(s.conversationID)
	if len(conversation.Messages) == 0 {
		fmt.Println(s.styles.warning.Render("No conversation to send."))
		return
	}

	// Find the last assistant message
	var lastResponse string
	for i := len(conversation.Messages) - 1; i >= 0; i-- {
		if conversation.Messages[i].Role == ai.RoleAssistant {
			lastResponse = conversation.Messages[i].Content
			break
		}
	}

	if lastResponse == "" {
		fmt.Println(s.styles.warning.Render("No assistant response to send."))
		return
	}

	// Extract commands
	extraction := s.responseParser.ExtractCommands(lastResponse)
	if len(extraction.Commands) == 0 {
		fmt.Println(s.styles.warning.Render("No commands found in last response."))
		return
	}

	// Select pane
	fmt.Println(s.styles.system.Render("Select target tmux pane..."))
	pane, err := s.tmuxClient.SelectPane()
	if err != nil || pane == nil {
		fmt.Println(s.styles.error.Render("Pane selection cancelled or failed."))
		return
	}

	// Send commands
	fmt.Println(s.styles.system.Render(fmt.Sprintf("Sending commands to pane: %s", pane.FullID)))
	err = s.tmuxClient.SendCommandsToPane(pane.FullID, extraction.Commands)
	if err != nil {
		fmt.Println(s.styles.error.Render(fmt.Sprintf("Error sending commands: %v", err)))
	} else {
		fmt.Println(s.styles.success.Render("Commands sent successfully!"))
	}
}

// switchProvider switches the active AI provider
func (s *InteractiveSession) switchProvider(providerName string) {
	if providerName == "" {
		providers := s.aiManager.ListProviders()
		fmt.Println(s.styles.system.Render("Available providers:"))
		for _, p := range providers {
			if provider, exists := s.aiManager.GetProvider(p); exists {
				status := "❌"
				if provider.IsEnabled() && provider.IsConfigured() {
					status = "✅"
				}
				fmt.Printf("  %s %s\n", status, p)
			}
		}
		return
	}

	err := s.aiManager.SetActiveProvider(providerName)
	if err != nil {
		fmt.Println(s.styles.error.Render(fmt.Sprintf("Error switching provider: %v", err)))
	} else {
		fmt.Println(s.styles.success.Render(fmt.Sprintf("Switched to provider: %s", providerName)))
	}
}

// RunWithInitialQuestion starts an interactive session with an optional initial question
func (s *InteractiveSession) RunWithInitialQuestion(initialQuestion string) error {
	// If no initial question provided, just run normally
	if initialQuestion == "" {
		return s.Run()
	}

	// Ensure debug logger is closed on exit
	defer debug.Close()

	// Ensure readline manager is cleaned up on exit
	if s.readlineManager != nil {
		defer s.readlineManager.Close()
	}

	// Setup signal handling for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// Print welcome message
	s.printWelcome()

	// Setup context gatherer options
	s.contextGatherer.SetOptions(
		s.config.Settings.MaxHistoryLines,
		true,                    // include history
		s.tmuxClient.IsInTmux(), // include panes if in tmux
	)
	// Set pane limits for context gathering
	s.contextGatherer.SetPaneLimits(
		s.config.Settings.MaxPaneLines,
		s.config.Settings.MaxPaneContextSize,
	)

	// Perform cleanup of old conversations
	if err := s.contextManager.PerformCleanup(); err != nil {
		fmt.Printf("Warning: Failed to cleanup old conversations: %v\n", err)
	}

	// Process the initial question first
	fmt.Println(s.styles.system.Render(fmt.Sprintf("Starting with question: %s", initialQuestion)))
	fmt.Println(s.styles.system.Render("---"))

	// Process the initial question
	if err := s.processQuery(initialQuestion); err != nil {
		fmt.Println(s.styles.error.Render(fmt.Sprintf("Error processing initial question: %v", err)))
	}

	// Add the initial question to readline history for reference
	if s.readlineManager != nil {
		s.readlineManager.AddToHistory(initialQuestion)
	}

	fmt.Println(s.styles.system.Render("---"))
	fmt.Println(s.styles.system.Render("✅ Initial question answered. Interactive session ready for follow-up questions."))
	fmt.Println(s.styles.system.Render("💡 Tip: Use ↑/↓ arrows to see your previous questions, or ask follow-up questions."))
	fmt.Println()

	// Continue with the normal interaction loop
	for {
		var input string
		var err error

		// Check if readline is available
		if s.readlineManager != nil {
			// Use readline for input with history and editing
			input, err = s.readlineManager.ReadLine()
			if err != nil {
				if err == readline.ErrInterrupt {
					// Handle Ctrl+C
					fmt.Println("\n" + s.styles.system.Render("Session interrupted. Goodbye!"))
					return nil
				} else if err == io.EOF {
					// Handle Ctrl+D
					fmt.Println("\n" + s.styles.system.Render("Session ended (Ctrl-D). Goodbye!"))
					return nil
				}
				return fmt.Errorf("readline error: %w", err)
			}
		} else {
			// Fallback to basic input if readline failed to initialize
			fmt.Print(s.styles.prompt.Render("🤖 AI> "))

			// Create channels for concurrent input and signal handling
			inputChan := make(chan string, 1)
			errChan := make(chan error, 1)

			// Read input in a goroutine for signal handling
			go func() {
				var line string
				fmt.Scanln(&line)
				inputChan <- line
			}()

			// Wait for input or signal
			select {
			case <-sigChan:
				fmt.Println("\n" + s.styles.system.Render("Session interrupted. Goodbye!"))
				return nil
			case input = <-inputChan:
				// Continue with input processing
			case err := <-errChan:
				if err == io.EOF {
					fmt.Println("\n" + s.styles.system.Render("Session ended (Ctrl-D). Goodbye!"))
					return nil
				}
				return fmt.Errorf("input error: %w", err)
			}
		}

		// Skip empty input
		if input == "" {
			continue
		}

		// Add to history if using readline
		if s.readlineManager != nil {
			s.readlineManager.AddToHistory(input)
		}

		// Handle special commands
		if s.handleSpecialCommands(input) {
			continue
		}

		// Process AI query
		if err := s.processQuery(input); err != nil {
			fmt.Println(s.styles.error.Render(fmt.Sprintf("Error: %v", err)))
		}
	}
}
