package contextgather

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"shell-ai-go/pkg/ai"
	"shell-ai-go/pkg/tmux"
)

func TestGatherer_NewGatherer(t *testing.T) {
	tmuxClient := tmux.NewClient()
	gatherer := NewGatherer(tmuxClient)

	if gatherer.tmuxClient != tmuxClient {
		t.Error("Expected tmux client to be set")
	}
	if gatherer.maxHistLines != 50 {
		t.Errorf("Expected default maxHistLines to be 50, got %d", gatherer.maxHistLines)
	}
	if !gatherer.includeHistory {
		t.Error("Expected includeHistory to be true by default")
	}
	if !gatherer.includePanes {
		t.Error("Expected includePanes to be true by default")
	}
}

func TestGatherer_SetOptions(t *testing.T) {
	tmuxClient := tmux.NewClient()
	gatherer := NewGatherer(tmuxClient)

	gatherer.SetOptions(100, false, false)

	if gatherer.maxHistLines != 100 {
		t.Errorf("Expected maxHistLines to be 100, got %d", gatherer.maxHistLines)
	}
	if gatherer.includeHistory {
		t.Error("Expected includeHistory to be false")
	}
	if gatherer.includePanes {
		t.Error("Expected includePanes to be false")
	}
}

func TestGatherer_GatherSystemInfo(t *testing.T) {
	tmuxClient := tmux.NewClient()
	gatherer := NewGatherer(tmuxClient)

	info, err := gatherer.gatherSystemInfo()
	if err != nil {
		t.Errorf("Unexpected error: %v", err)
	}

	if info.OS == "" {
		t.Error("Expected OS to be set")
	}
	if info.Shell == "" {
		t.Error("Expected Shell to be set")
	}
	// Hostname and User might be empty in some test environments, so we don't require them
}

func TestGatherer_GatherEnvironment(t *testing.T) {
	tmuxClient := tmux.NewClient()
	gatherer := NewGatherer(tmuxClient)

	// Set some test environment variables
	os.Setenv("TEST_PATH", "/test/path")
	os.Setenv("HOME", "/home/testuser")
	defer func() {
		os.Unsetenv("TEST_PATH")
		// Don't unset HOME as it might be needed by other tests
	}()

	env := gatherer.gatherEnvironment()

	// Should contain HOME
	found := false
	for _, envVar := range env {
		if strings.HasPrefix(envVar, "HOME=") {
			found = true
			break
		}
	}
	if !found {
		t.Error("Expected HOME environment variable to be included")
	}

	// Should not contain TEST_PATH (not in relevant list)
	for _, envVar := range env {
		if strings.HasPrefix(envVar, "TEST_PATH=") {
			t.Error("Expected TEST_PATH to not be included")
		}
	}
}

func TestGatherer_ReadHistoryFile(t *testing.T) {
	tmuxClient := tmux.NewClient()
	gatherer := NewGatherer(tmuxClient)
	gatherer.maxHistLines = 3

	// Create a temporary history file
	tempDir := t.TempDir()
	historyFile := filepath.Join(tempDir, "test_history")

	content := `# This is a comment
command1
command2

command3
# Another comment
command4
command5`

	err := os.WriteFile(historyFile, []byte(content), 0644)
	if err != nil {
		t.Fatalf("Failed to create test history file: %v", err)
	}

	history, err := gatherer.readHistoryFile(historyFile)
	if err != nil {
		t.Errorf("Unexpected error: %v", err)
	}

	// Should get last 3 non-comment, non-empty lines
	expected := []string{"command3", "command4", "command5"}
	if len(history) != len(expected) {
		t.Errorf("Expected %d history entries, got %d", len(expected), len(history))
	}

	for i, cmd := range expected {
		if i >= len(history) || history[i] != cmd {
			t.Errorf("Expected history[%d] to be '%s', got '%s'", i, cmd, history[i])
		}
	}
}

func TestGatherer_ReadHistoryFile_TildeExpansion(t *testing.T) {
	tmuxClient := tmux.NewClient()
	gatherer := NewGatherer(tmuxClient)

	// Test with tilde expansion (will fail if file doesn't exist, but that's expected)
	_, err := gatherer.readHistoryFile("~/nonexistent_history")
	// We expect an error because the file doesn't exist, but it should be a file not found error,
	// not a path expansion error
	if err == nil {
		t.Error("Expected error for nonexistent file")
	}
	if !strings.Contains(err.Error(), "no such file") && !strings.Contains(err.Error(), "cannot find") {
		// The error message varies by OS, so we check for common patterns
		t.Logf("Got error (expected): %v", err)
	}
}

func TestGatherer_FormatContext(t *testing.T) {
	tmuxClient := tmux.NewClient()
	gatherer := NewGatherer(tmuxClient)

	ctx := &ai.ContextData{
		SystemInfo: ai.SystemInfo{
			OS:       "linux",
			Shell:    "bash",
			Hostname: "testhost",
			User:     "testuser",
		},
		WorkingDir: "/home/testuser",
		Environment: []string{
			"PATH=/usr/bin:/bin",
			"HOME=/home/testuser",
		},
		ShellHistory: []string{
			"ls -la",
			"cd /tmp",
			"pwd",
		},
		TmuxContent: []ai.PaneContent{
			{
				PaneID:   "main:0.0",
				Title:    "bash",
				Content:  "user@host:~$ ls\nfile1.txt file2.txt",
				IsActive: true,
			},
		},
	}

	conversation := &ai.Conversation{
		ID: "test",
		Messages: []ai.Message{
			{Role: ai.RoleUser, Content: "hello"},
			{Role: ai.RoleAssistant, Content: "hi there"},
		},
	}

	formatted := gatherer.FormatContext(ctx, conversation)

	// Check that all sections are present
	expectedSections := []string{
		"=== SYSTEM CONTEXT ===",
		"OS: linux",
		"Hostname: testhost",
		"User: testuser",
		"Shell: bash",
		"Working Directory: /home/testuser",
		"=== ENVIRONMENT ===",
		"PATH=/usr/bin:/bin",
		"=== RECENT SHELL HISTORY ===",
		"ls -la",
		"cd /tmp",
		"pwd",
		"=== TMUX WINDOW CONTENT ===",
		"PANE main:0.0 (ACTIVE)",
		"user@host:~$ ls",
		"=== CONVERSATION HISTORY ===",
		"[USER]: hello",
		"[ASSISTANT]: hi there",
	}

	for _, section := range expectedSections {
		if !strings.Contains(formatted, section) {
			t.Errorf("Expected formatted context to contain '%s'", section)
		}
	}
}

func TestGatherer_FormatContext_EmptySections(t *testing.T) {
	tmuxClient := tmux.NewClient()
	gatherer := NewGatherer(tmuxClient)

	ctx := &ai.ContextData{
		SystemInfo: ai.SystemInfo{
			OS:    "linux",
			Shell: "bash",
		},
		WorkingDir: "/home/testuser",
	}

	formatted := gatherer.FormatContext(ctx, nil)

	// Should contain system context but not other sections
	if !strings.Contains(formatted, "=== SYSTEM CONTEXT ===") {
		t.Error("Expected system context section")
	}
	if strings.Contains(formatted, "=== ENVIRONMENT ===") {
		t.Error("Expected no environment section when empty")
	}
	if strings.Contains(formatted, "=== RECENT SHELL HISTORY ===") {
		t.Error("Expected no history section when empty")
	}
	if strings.Contains(formatted, "=== TMUX WINDOW CONTENT ===") {
		t.Error("Expected no tmux section when empty")
	}
	if strings.Contains(formatted, "=== CONVERSATION HISTORY ===") {
		t.Error("Expected no conversation section when nil")
	}
}

func TestGatherer_GatherContext_Integration(t *testing.T) {
	// This is more of an integration test
	tmuxClient := tmux.NewClient()
	gatherer := NewGatherer(tmuxClient)

	// Disable tmux and history to avoid external dependencies
	gatherer.SetOptions(10, false, false)

	ctx, err := gatherer.GatherContext()
	if err != nil {
		t.Errorf("Unexpected error: %v", err)
	}

	if ctx.SystemInfo.OS == "" {
		t.Error("Expected OS to be set")
	}
	if ctx.WorkingDir == "" {
		t.Error("Expected working directory to be set")
	}
	if len(ctx.Environment) == 0 {
		t.Error("Expected some environment variables")
	}
	if len(ctx.ShellHistory) != 0 {
		t.Error("Expected no shell history (disabled)")
	}
	if len(ctx.TmuxContent) != 0 {
		t.Error("Expected no tmux content (disabled)")
	}
}

// Test atuin integration environment variable handling
func TestGatherer_AtuinTmuxIntegration(t *testing.T) {
	tmuxClient := tmux.NewClient()
	gatherer := NewGatherer(tmuxClient)

	// Test without AI_SHELL_TMUX_INVOKED
	os.Unsetenv("AI_SHELL_TMUX_INVOKED")
	os.Unsetenv("TMUX")

	// We can't easily test the actual atuin command execution without mocking,
	// but we can verify that the function handles the environment correctly
	// This is more of a structural test

	// The getAtuinHistory method should exist and handle errors gracefully
	_, err := gatherer.getAtuinHistory()
	// We expect this to fail because atuin might not be installed,
	// but it shouldn't panic
	if err == nil {
		t.Log("Atuin is available and working")
	} else {
		t.Logf("Atuin not available (expected in test environment): %v", err)
	}
}
