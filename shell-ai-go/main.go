package main

import (
	"fmt"
	"os"

	"shell-ai-go/pkg/config"
	"shell-ai-go/pkg/session"
	"shell-ai-go/pkg/tmux"

	"github.com/spf13/cobra"
)

var (
	version        = "1.0.0"
	cfgFile        string
	provider       string
	contextLines   int
	noHistory      bool
	noPanes        bool
	conversational bool
)

var rootCmd = &cobra.Command{
	Use:   "shell-ai",
	Short: "AI-enhanced shell with conversational context",
	Long: `Shell AI Integration (Go) - An AI-enhanced shell environment that integrates
multiple AI providers with tmux for intelligent command assistance and context-aware
conversations.`,
	RunE: runShellAI,
}

var interactiveCmd = &cobra.Command{
	Use:   "interactive [initial-question]",
	Short: "Start interactive conversational session",
	Long:  "Start an interactive session with the AI that maintains conversation context. Optionally provide an initial question to start the conversation.",
	Args:  cobra.MaximumNArgs(1),
	RunE:  runInteractiveSession,
}

var oneShotCmd = &cobra.Command{
	Use:   "ask [prompt]",
	Short: "Ask a single question to the AI",
	Args:  cobra.MinimumNArgs(1),
	RunE:  runOneShot,
}

var setupCmd = &cobra.Command{
	Use:   "setup",
	Short: "Configure AI providers",
	RunE:  runSetup,
}

var testCmd = &cobra.Command{
	Use:   "test",
	Short: "Test AI provider connections",
	RunE:  runTest,
}

func init() {
	cobra.OnInitialize(initConfig)

	// Global flags
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.config/shell-ai/config.yaml)")
	rootCmd.PersistentFlags().StringVarP(&provider, "provider", "p", "", "AI provider to use (openai, anthropic, google, ollama)")
	rootCmd.PersistentFlags().IntVarP(&contextLines, "context-lines", "c", 50, "number of context lines to include")
	rootCmd.PersistentFlags().BoolVar(&noHistory, "no-history", false, "exclude shell history from context")
	rootCmd.PersistentFlags().BoolVar(&noPanes, "no-panes", false, "exclude tmux pane content from context")

	// Interactive session flags
	interactiveCmd.Flags().BoolVarP(&conversational, "conversational", "C", true, "maintain conversation context")

	// Add subcommands
	rootCmd.AddCommand(interactiveCmd)
	rootCmd.AddCommand(oneShotCmd)
	rootCmd.AddCommand(setupCmd)
	rootCmd.AddCommand(testCmd)
}

func initConfig() {
	config.InitConfig(cfgFile)
}

func runShellAI(cmd *cobra.Command, args []string) error {
	// Check if we're in tmux
	if os.Getenv("TMUX") == "" {
		fmt.Println("Warning: Not running in tmux. Some features may be limited.")
	}

	// If no args provided, start interactive session
	if len(args) == 0 {
		return runInteractiveSession(cmd, args)
	}

	// Otherwise, treat as one-shot query
	return runOneShot(cmd, args)
}

func runInteractiveSession(cmd *cobra.Command, args []string) error {
	cfg, err := config.LoadConfig()
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	// Initialize tmux integration
	tmuxClient := tmux.NewClient()
	if !tmuxClient.IsInTmux() {
		fmt.Println("Warning: Not running in tmux. Pane selection features will be disabled.")
	}

	// Create interactive session
	sess := session.NewInteractiveSession(cfg, tmuxClient)

	// If an initial question is provided, pass it to the session
	var initialQuestion string
	if len(args) > 0 {
		initialQuestion = args[0]
	}

	return sess.RunWithInitialQuestion(initialQuestion)
}

func runOneShot(cmd *cobra.Command, args []string) error {
	cfg, err := config.LoadConfig()
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	tmuxClient := tmux.NewClient()
	sess := session.NewOneShot(cfg, tmuxClient)

	// Join args into a single prompt
	prompt := ""
	for i, arg := range args {
		if i > 0 {
			prompt += " "
		}
		prompt += arg
	}

	return sess.Ask(prompt)
}

func runSetup(cmd *cobra.Command, args []string) error {
	cfg, err := config.LoadConfig()
	if err != nil {
		// If config doesn't exist, create a default one
		cfg = config.NewDefaultConfig()
	}

	return config.RunSetup(cfg)
}

func runTest(cmd *cobra.Command, args []string) error {
	cfg, err := config.LoadConfig()
	if err != nil {
		return fmt.Errorf("failed to load config: %w", err)
	}

	return config.TestProviders(cfg)
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
