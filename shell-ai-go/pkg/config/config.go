package config

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"shell-ai-go/pkg/ai"
	"shell-ai-go/pkg/ai/providers"
	"shell-ai-go/pkg/contextmgmt"

	"github.com/spf13/viper"
)

// Config represents the application configuration
type Config struct {
	Providers map[string]*ai.ProviderConfig `yaml:"providers"`
	Settings  *Settings                     `yaml:"settings"`
}

// Settings contains application settings
type Settings struct {
	AutoCopy           bool   `yaml:"auto_copy"`
	AutoCopyPrompt     bool   `yaml:"auto_copy_prompt"`
	DefaultProvider    string `yaml:"default_provider"`
	DefaultPrompt      string `yaml:"default_prompt"` // Default prompt appended to user queries
	MaxHistoryLines    int    `yaml:"max_history_lines"`
	MaxPaneLines       int    `yaml:"max_pane_lines"`
	MaxPaneContextSize int    `yaml:"max_pane_context_size"` // Max total size (bytes) for all pane content
	ConversationTTL    int    `yaml:"conversation_ttl_hours"`
	EnableStorage      bool   `yaml:"enable_storage"`
	SharedStorage      bool   `yaml:"shared_storage"`

	// Context management settings
	MaxTokens           int    `yaml:"max_tokens"`
	MaxMessages         int    `yaml:"max_messages"`
	MaxContextSize      int    `yaml:"max_context_size"`
	KeepInitialMessages int    `yaml:"keep_initial_messages"`
	TruncationStrategy  string `yaml:"truncation_strategy"`
}

var (
	configDir  string
	configFile string
)

// InitConfig initializes the configuration system
func InitConfig(cfgFile string) {
	if cfgFile != "" {
		viper.SetConfigFile(cfgFile)
	} else {
		home, err := os.UserHomeDir()
		if err != nil {
			fmt.Printf("Error getting home directory: %v\n", err)
			os.Exit(1)
		}

		configDir = filepath.Join(home, ".config", "shell-ai")
		configFile = filepath.Join(configDir, "config.yaml")

		// Create config directory if it doesn't exist
		if err := os.MkdirAll(configDir, 0755); err != nil {
			fmt.Printf("Error creating config directory: %v\n", err)
			os.Exit(1)
		}

		viper.AddConfigPath(configDir)
		viper.SetConfigName("config")
		viper.SetConfigType("yaml")
	}

	// Set defaults
	viper.SetDefault("settings.auto_copy", false)
	viper.SetDefault("settings.auto_copy_prompt", true)
	viper.SetDefault("settings.default_prompt", "Please provide a helpful response. If you're suggesting shell commands, format them clearly so they can be easily copied and executed.")
	viper.SetDefault("settings.max_history_lines", 50)
	viper.SetDefault("settings.max_pane_lines", 100)
	viper.SetDefault("settings.max_pane_context_size", 20000) // 20KB default for all pane content
	viper.SetDefault("settings.conversation_ttl_hours", 24)
	viper.SetDefault("settings.enable_storage", true)
	viper.SetDefault("settings.shared_storage", true)

	// Context management defaults
	viper.SetDefault("settings.max_tokens", 8000)
	viper.SetDefault("settings.max_messages", 20)
	viper.SetDefault("settings.max_context_size", 50000)
	viper.SetDefault("settings.keep_initial_messages", 3)
	viper.SetDefault("settings.truncation_strategy", "smart")

	// Read environment variables
	viper.AutomaticEnv()
	viper.SetEnvPrefix("SHELL_AI")

	// Try to read config file
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			fmt.Printf("Error reading config file: %v\n", err)
		}
	}
}

// LoadConfig loads the configuration
func LoadConfig() (*Config, error) {
	config := &Config{}

	// Try to read the config file
	if err := viper.ReadInConfig(); err != nil {
		// If config file doesn't exist, return a default config
		if _, ok := err.(viper.ConfigFileNotFoundError); ok {
			return NewDefaultConfig(), nil
		}
		return nil, fmt.Errorf("failed to read config: %w", err)
	}

	if err := viper.Unmarshal(config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	// Manually unmarshal settings if they're not properly loaded
	if config.Settings != nil {
		settingsMap := viper.GetStringMap("settings")
		if settingsMap != nil {
			// Always try to load from viper if available, regardless of current values
			if maxTokens, ok := settingsMap["max_tokens"].(int); ok && maxTokens > 0 {
				config.Settings.MaxTokens = maxTokens
			}
			if maxMessages, ok := settingsMap["max_messages"].(int); ok && maxMessages > 0 {
				config.Settings.MaxMessages = maxMessages
			}
			if maxHistoryLines, ok := settingsMap["max_history_lines"].(int); ok && maxHistoryLines > 0 {
				config.Settings.MaxHistoryLines = maxHistoryLines
			}
			if maxPaneLines, ok := settingsMap["max_pane_lines"].(int); ok && maxPaneLines > 0 {
				config.Settings.MaxPaneLines = maxPaneLines
			}
			if maxPaneContextSize, ok := settingsMap["max_pane_context_size"].(int); ok && maxPaneContextSize > 0 {
				config.Settings.MaxPaneContextSize = maxPaneContextSize
			}
			if maxContextSize, ok := settingsMap["max_context_size"].(int); ok && maxContextSize > 0 {
				config.Settings.MaxContextSize = maxContextSize
			}
			if keepInitialMessages, ok := settingsMap["keep_initial_messages"].(int); ok && keepInitialMessages > 0 {
				config.Settings.KeepInitialMessages = keepInitialMessages
			}
			if truncationStrategy, ok := settingsMap["truncation_strategy"].(string); ok && truncationStrategy != "" {
				config.Settings.TruncationStrategy = truncationStrategy
			}
			if defaultPrompt, ok := settingsMap["default_prompt"].(string); ok && defaultPrompt != "" {
				config.Settings.DefaultPrompt = defaultPrompt
			}
		}
	}

	// Ensure settings exist
	if config.Settings == nil {
		config.Settings = NewDefaultSettings()
	}

	// Ensure providers map exists
	if config.Providers == nil {
		config.Providers = make(map[string]*ai.ProviderConfig)
	}

	// Manually unmarshal providers if they're not properly loaded
	providersMap := viper.GetStringMap("providers")
	if providersMap != nil {
		for providerName, providerData := range providersMap {
			if providerMap, ok := providerData.(map[string]interface{}); ok {
				if provider, exists := config.Providers[providerName]; exists {
					// Update provider config with values from viper
					if apiKey, ok := providerMap["api_key"].(string); ok && apiKey != "" {
						provider.APIKey = apiKey
					}
					if enabled, ok := providerMap["enabled"].(bool); ok {
						provider.Enabled = enabled
					}
					if model, ok := providerMap["model"].(string); ok && model != "" {
						provider.Model = model
					}
					if baseURL, ok := providerMap["base_url"].(string); ok && baseURL != "" {
						provider.BaseURL = baseURL
					}
					if maxTokens, ok := providerMap["max_tokens"].(int); ok && maxTokens > 0 {
						provider.MaxTokens = maxTokens
					}
					if temperature, ok := providerMap["temperature"].(float64); ok {
						provider.Temperature = temperature
					}
				}
			}
		}
	}

	// Set defaults for providers if they don't exist
	if _, exists := config.Providers["openai"]; !exists {
		config.Providers["openai"] = &ai.ProviderConfig{
			Name:        "openai",
			Enabled:     false,
			Model:       "gpt-3.5-turbo",
			MaxTokens:   2000,
			Temperature: 0.7,
		}
	}

	if _, exists := config.Providers["anthropic"]; !exists {
		config.Providers["anthropic"] = &ai.ProviderConfig{
			Name:        "anthropic",
			Enabled:     false,
			Model:       "claude-3-haiku-20240307",
			MaxTokens:   2000,
			Temperature: 0.7,
		}
	}

	if _, exists := config.Providers["google"]; !exists {
		config.Providers["google"] = &ai.ProviderConfig{
			Name:        "google",
			Enabled:     false,
			Model:       "gemini-2.5-pro",
			MaxTokens:   2000,
			Temperature: 0.7,
		}
	}

	if _, exists := config.Providers["ollama"]; !exists {
		config.Providers["ollama"] = &ai.ProviderConfig{
			Name:        "ollama",
			Enabled:     false,
			Model:       "llama2",
			BaseURL:     "http://localhost:11434",
			MaxTokens:   2000,
			Temperature: 0.7,
		}
	}

	return config, nil
}

// SaveConfig saves the configuration
func SaveConfig(config *Config) error {
	// Update viper with new config
	viper.Set("providers", config.Providers)
	viper.Set("settings", config.Settings)

	// Try to write config, if file doesn't exist, create it
	if err := viper.WriteConfig(); err != nil {
		// If the config file doesn't exist, create it
		if _, ok := err.(viper.ConfigFileNotFoundError); ok {
			return viper.SafeWriteConfig()
		}
		return err
	}
	return nil
}

// NewDefaultConfig creates a default configuration
func NewDefaultConfig() *Config {
	return &Config{
		Providers: map[string]*ai.ProviderConfig{
			"openai": {
				Name:        "openai",
				Enabled:     false,
				Model:       "gpt-3.5-turbo",
				MaxTokens:   2000,
				Temperature: 0.7,
			},
			"anthropic": {
				Name:        "anthropic",
				Enabled:     false,
				Model:       "claude-3-haiku-20240307",
				MaxTokens:   2000,
				Temperature: 0.7,
			},
			"google": {
				Name:        "google",
				Enabled:     false,
				Model:       "gemini-2.5-pro",
				MaxTokens:   2000,
				Temperature: 0.7,
			},
			"ollama": {
				Name:        "ollama",
				Enabled:     false,
				Model:       "llama2",
				BaseURL:     "http://localhost:11434",
				MaxTokens:   2000,
				Temperature: 0.7,
			},
		},
		Settings: NewDefaultSettings(),
	}
}

// NewDefaultSettings creates default settings
func NewDefaultSettings() *Settings {
	return &Settings{
		AutoCopy:            false,
		AutoCopyPrompt:      true,
		DefaultPrompt:       "Please provide a helpful response. If you're suggesting shell commands, format them clearly so they can be easily copied and executed.",
		MaxHistoryLines:     50,
		MaxPaneLines:        100,
		MaxPaneContextSize:  20000,
		ConversationTTL:     24,
		MaxTokens:           8000,
		MaxMessages:         20,
		MaxContextSize:      50000,
		KeepInitialMessages: 3,
		TruncationStrategy:  "smart",
	}
}

// GetConfigDir returns the configuration directory
func GetConfigDir() string {
	return configDir
}

// CreateAIManager creates an AI manager from the configuration
func (c *Config) CreateAIManager() *ai.Manager {
	var manager *ai.Manager

	// Create manager (storage will be enabled later if needed)
	manager = ai.NewManager()

	// Register providers
	for name, providerConfig := range c.Providers {
		var provider ai.Provider

		switch name {
		case "openai":
			provider = providers.NewOpenAIProvider(providerConfig)
		case "anthropic":
			provider = providers.NewAnthropicProvider(providerConfig)
		case "google":
			provider = providers.NewGoogleProvider(providerConfig)
		case "ollama":
			provider = providers.NewOllamaProvider(providerConfig)
		default:
			continue
		}

		manager.RegisterProvider(name, provider)
	}

	// Set default provider if configured
	if c.Settings.DefaultProvider != "" {
		manager.SetActiveProvider(c.Settings.DefaultProvider)
	}

	return manager
}

// RunSetup runs the interactive setup process
func RunSetup(config *Config) error {
	fmt.Println("Shell AI Configuration Setup")
	fmt.Println("============================")
	fmt.Println()

	// Setup each provider
	for name, providerConfig := range config.Providers {
		fmt.Printf("Configure %s provider? [y/N]: ", name)
		var response string
		fmt.Scanln(&response)

		if response == "y" || response == "Y" {
			var provider ai.Provider

			switch name {
			case "openai":
				provider = providers.NewOpenAIProvider(providerConfig)
			case "anthropic":
				provider = providers.NewAnthropicProvider(providerConfig)
			case "google":
				provider = providers.NewGoogleProvider(providerConfig)
			case "ollama":
				provider = providers.NewOllamaProvider(providerConfig)
			}

			if provider != nil {
				if err := provider.Setup(); err != nil {
					fmt.Printf("Error setting up %s: %v\n", name, err)
				} else {
					fmt.Printf("%s configured successfully!\n", name)
				}
			}
		}
		fmt.Println()
	}

	// General settings
	fmt.Println("General Settings")
	fmt.Println("----------------")

	fmt.Printf("Auto-copy responses to tmux panes? [y/N]: ")
	var autoCopy string
	fmt.Scanln(&autoCopy)
	config.Settings.AutoCopy = autoCopy == "y" || autoCopy == "Y"

	defaultMaxHistoryLines := 50
	fmt.Printf("Max shell history lines (default: %d): ", defaultMaxHistoryLines)
	var histLines string
	fmt.Scanln(&histLines)
	if histLines != "" {
		var lines int
		if _, err := fmt.Sscanf(histLines, "%d", &lines); err == nil && lines > 0 {
			config.Settings.MaxHistoryLines = lines
		}
	} else {
		// Use default value if no input provided
		config.Settings.MaxHistoryLines = defaultMaxHistoryLines
	}

	// Save configuration
	return SaveConfig(config)
}

// TestProviders tests all configured providers
func TestProviders(config *Config) error {
	manager := config.CreateAIManager()

	fmt.Println("Testing AI Providers")
	fmt.Println("===================")
	fmt.Println()

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	results := manager.TestAllProviders(ctx)

	for provider, err := range results {
		if err != nil {
			fmt.Printf("❌ %s: %v\n", provider, err)
		} else {
			fmt.Printf("✅ %s: OK\n", provider)
		}
	}

	fmt.Println()
	return nil
}

// CreateContextLimits creates context limits from config settings
func (c *Config) CreateContextLimits() *contextmgmt.ContextLimits {
	limits := &contextmgmt.ContextLimits{
		MaxTokens:           c.Settings.MaxTokens,
		MaxMessages:         c.Settings.MaxMessages,
		MaxHistoryLines:     c.Settings.MaxHistoryLines,
		MaxContextSize:      c.Settings.MaxContextSize,
		KeepInitialMessages: c.Settings.KeepInitialMessages,
		TruncationStrategy:  c.Settings.TruncationStrategy,
	}

	return limits
}
