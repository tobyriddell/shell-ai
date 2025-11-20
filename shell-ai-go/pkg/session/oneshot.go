package session

import (
	"context"
	"fmt"
	"os"

	"shell-ai-go/pkg/ai"
	"shell-ai-go/pkg/config"
	"shell-ai-go/pkg/contextgather"
	"shell-ai-go/pkg/response"
	"shell-ai-go/pkg/tmux"

	"github.com/charmbracelet/lipgloss"
)

// OneShot handles single AI queries without conversation context
type OneShot struct {
	config          *config.Config
	aiManager       *ai.Manager
	tmuxClient      *tmux.Client
	contextGatherer *contextgather.Gatherer
	responseParser  *response.Parser
	styles          *sessionStyles
}

// NewOneShot creates a new one-shot session
func NewOneShot(cfg *config.Config, tmuxClient *tmux.Client) *OneShot {
	styles := &sessionStyles{
		prompt:    lipgloss.NewStyle().Foreground(lipgloss.Color("12")).Bold(true),
		user:      lipgloss.NewStyle().Foreground(lipgloss.Color("10")),
		assistant: lipgloss.NewStyle().Foreground(lipgloss.Color("14")),
		system:    lipgloss.NewStyle().Foreground(lipgloss.Color("7")), // Light gray (bright)
		error:     lipgloss.NewStyle().Foreground(lipgloss.Color("9")).Bold(true),
		warning:   lipgloss.NewStyle().Foreground(lipgloss.Color("11")),
		success:   lipgloss.NewStyle().Foreground(lipgloss.Color("10")),
		command:   lipgloss.NewStyle().Foreground(lipgloss.Color("13")).Bold(true),
	}

	return &OneShot{
		config:          cfg,
		aiManager:       cfg.CreateAIManager(),
		tmuxClient:      tmuxClient,
		contextGatherer: contextgather.NewGatherer(tmuxClient),
		responseParser:  response.NewParser(),
		styles:          styles,
	}
}

// Ask processes a single query and returns the response
func (o *OneShot) Ask(prompt string) error {
	// Setup context gatherer options
	o.contextGatherer.SetOptions(
		o.config.Settings.MaxHistoryLines,
		true,                    // include history
		o.tmuxClient.IsInTmux(), // include panes if in tmux
	)
	// Set pane limits for context gathering
	o.contextGatherer.SetPaneLimits(
		o.config.Settings.MaxPaneLines,
		o.config.Settings.MaxPaneContextSize,
	)

	// Show AI provider
	fmt.Print(o.styles.system.Render("🤖 Asking "))
	if provider, err := o.aiManager.GetActiveProvider(); err == nil {
		fmt.Print(o.styles.system.Render(provider.Name()))
	}
	fmt.Print(o.styles.system.Render("... "))

	// Gather context
	ctx, err := o.contextGatherer.GatherContext()
	if err != nil {
		fmt.Println(o.styles.error.Render("failed to gather context"))
		return fmt.Errorf("failed to gather context: %w", err)
	}

	// Format context (no conversation history for one-shot)
	contextStr := o.contextGatherer.FormatContext(ctx, nil)

	// Create full prompt
	fullPrompt := contextStr + "\n=== USER PROMPT ===\n" + prompt +
		"\n\nPlease provide a helpful response. If you're suggesting shell commands, format them clearly so they can be easily copied and executed."

	// Send to AI
	response, err := o.aiManager.Chat(context.Background(), "oneshot", fullPrompt)
	if err != nil {
		fmt.Println(o.styles.error.Render("failed"))
		return err
	}
	fmt.Println(o.styles.success.Render("done"))

	// Display response
	fmt.Println()
	fmt.Println(o.styles.success.Render("Response:"))
	fmt.Println(response.Content)

	// Extract and handle commands
	extraction := o.responseParser.ExtractCommands(response.Content)
	if len(extraction.Commands) > 0 {
		fmt.Println()
		fmt.Println(o.styles.command.Render("📋 Extracted Commands:"))
		fmt.Println(o.responseParser.FormatCommands(extraction.Commands))

		// Save response for potential tmux integration
		if err := o.saveLastResponse(response.Content); err != nil {
			fmt.Printf("Warning: Failed to save response: %v\n", err)
		}

		// Handle auto-copy settings
		if o.config.Settings.AutoCopy && o.tmuxClient.IsInTmux() {
			if o.config.Settings.AutoCopyPrompt {
				fmt.Print(o.styles.system.Render("\nSend commands to tmux pane? [y/N]: "))
				var answer string
				fmt.Scanln(&answer)
				if answer == "y" || answer == "Y" {
					return o.sendToPane(extraction.Commands)
				}
			} else {
				fmt.Println(o.styles.system.Render("\nAuto-sending commands to tmux pane..."))
				return o.sendToPane(extraction.Commands)
			}
		} else if o.tmuxClient.IsInTmux() {
			fmt.Println()
			fmt.Println(o.styles.system.Render("Tip: Response saved. Use 'shell-ai-copy' to send commands to tmux panes"))
		}
	}

	fmt.Println()
	return nil
}

// sendToPane sends commands to a selected tmux pane
func (o *OneShot) sendToPane(commands []ai.Command) error {
	if !o.tmuxClient.IsInTmux() {
		return fmt.Errorf("not running in tmux")
	}

	// Select pane
	fmt.Println(o.styles.system.Render("Select target tmux pane..."))
	pane, err := o.tmuxClient.SelectPane()
	if err != nil || pane == nil {
		return fmt.Errorf("pane selection cancelled or failed")
	}

	// Send commands
	fmt.Printf(o.styles.system.Render("Sending commands to pane: %s\n"), pane.FullID)
	err = o.tmuxClient.SendCommandsToPane(pane.FullID, commands)
	if err != nil {
		return fmt.Errorf("error sending commands: %w", err)
	}

	fmt.Println(o.styles.success.Render("Commands sent successfully!"))
	return nil
}

// saveLastResponse saves the response for potential use by other tools
func (o *OneShot) saveLastResponse(content string) error {
	configDir := config.GetConfigDir()
	if configDir == "" {
		return fmt.Errorf("config directory not available")
	}

	responseFile := configDir + "/last_response.txt"
	return os.WriteFile(responseFile, []byte(content), 0644)
}
