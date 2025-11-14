package tmux

import (
	"os"
	"testing"

	"shell-ai-go/pkg/ai"
)

func TestClient_IsInTmux(t *testing.T) {
	// Test without TMUX environment variable
	os.Unsetenv("TMUX")
	client := NewClient()
	if client.IsInTmux() {
		t.Error("Expected IsInTmux to return false when TMUX env var is not set")
	}

	// Test with TMUX environment variable set
	os.Setenv("TMUX", "/tmp/tmux-1000/default,12345,0")
	defer os.Unsetenv("TMUX")
	client2 := NewClient()
	if !client2.IsInTmux() {
		t.Error("Expected IsInTmux to return true when TMUX env var is set")
	}
}

func TestTmuxPane_DisplayName(t *testing.T) {
	pane := TmuxPane{
		SessionName: "main",
		WindowIndex: "0",
		PaneIndex:   "1",
		PaneTitle:   "bash",
		FullID:      "main:0.1",
	}

	expected := "main:0.1 - bash"
	if pane.DisplayName() != expected {
		t.Errorf("Expected display name '%s', got '%s'", expected, pane.DisplayName())
	}
}

func TestClient_GetCurrentPaneID_NotInTmux(t *testing.T) {
	os.Unsetenv("TMUX")
	client := NewClient()

	_, err := client.GetCurrentPaneID()
	if err == nil {
		t.Error("Expected error when not in tmux")
	}
}

func TestClient_GetPanes_NotInTmux(t *testing.T) {
	os.Unsetenv("TMUX")
	client := NewClient()

	_, err := client.GetPanes()
	if err == nil {
		t.Error("Expected error when not in tmux")
	}
}

func TestClient_SelectPane_NotInTmux(t *testing.T) {
	os.Unsetenv("TMUX")
	client := NewClient()

	_, err := client.SelectPane()
	if err == nil {
		t.Error("Expected error when not in tmux")
	}
}

func TestClient_SendToPane_NotInTmux(t *testing.T) {
	os.Unsetenv("TMUX")
	client := NewClient()

	err := client.SendToPane("test:0.1", "echo hello")
	if err == nil {
		t.Error("Expected error when not in tmux")
	}
}

func TestClient_SendCommandsToPane_NotInTmux(t *testing.T) {
	os.Unsetenv("TMUX")
	client := NewClient()

	commands := []ai.Command{
		{Command: "echo hello", Safe: true},
	}

	err := client.SendCommandsToPane("test:0.1", commands)
	if err == nil {
		t.Error("Expected error when not in tmux")
	}
}

func TestClient_CapturePaneContent_NotInTmux(t *testing.T) {
	os.Unsetenv("TMUX")
	client := NewClient()

	_, err := client.CapturePaneContent()
	if err == nil {
		t.Error("Expected error when not in tmux")
	}
}

func TestClient_FindMostRecentPane(t *testing.T) {
	client := NewClient()

	panes := []TmuxPane{
		{FullID: "main:0.0", LastUsed: 1000, IsActive: false},
		{FullID: "main:0.1", LastUsed: 2000, IsActive: false},
		{FullID: "main:0.2", LastUsed: 1500, IsActive: true},
		{FullID: "main:1.0", LastUsed: 500, IsActive: false},
	}

	// Test excluding current pane - should find most recent
	recent := client.findMostRecentPane(panes, "main:0.0")
	if recent == nil {
		t.Fatal("Expected to find a recent pane")
	}
	if recent.FullID != "main:0.1" {
		t.Errorf("Expected most recent pane 'main:0.1', got '%s'", recent.FullID)
	}

	// Test excluding current pane and most recent - should find active
	recent2 := client.findMostRecentPane(panes, "main:0.1")
	if recent2 == nil {
		t.Fatal("Expected to find a recent pane")
	}
	if recent2.FullID != "main:0.2" {
		t.Errorf("Expected active pane 'main:0.2', got '%s'", recent2.FullID)
	}

	// Test excluding all but one - should find the remaining one
	recent3 := client.findMostRecentPane(panes, "main:0.2")
	if recent3 == nil {
		t.Fatal("Expected to find a recent pane")
	}
	// Should be main:0.1 (highest LastUsed among remaining)
	if recent3.FullID != "main:0.1" {
		t.Errorf("Expected pane 'main:0.1', got '%s'", recent3.FullID)
	}
}

func TestClient_FindMostRecentPaneIndex(t *testing.T) {
	client := NewClient()

	panes := []TmuxPane{
		{FullID: "main:0.0", LastUsed: 1000, IsActive: false}, // index 0
		{FullID: "main:0.1", LastUsed: 2000, IsActive: false}, // index 1
		{FullID: "main:0.2", LastUsed: 1500, IsActive: true},  // index 2
		{FullID: "main:1.0", LastUsed: 500, IsActive: false},  // index 3
	}

	// Test excluding current pane at index 0
	index := client.findMostRecentPaneIndex(panes, "main:0.0")
	if index != 1 {
		t.Errorf("Expected index 1 (main:0.1), got %d", index)
	}

	// Test excluding current pane at index 1
	index2 := client.findMostRecentPaneIndex(panes, "main:0.1")
	if index2 != 2 {
		t.Errorf("Expected index 2 (main:0.2 - active), got %d", index2)
	}

	// Test excluding all but last pane
	index3 := client.findMostRecentPaneIndex(panes, "main:1.0")
	if index3 != 1 {
		t.Errorf("Expected index 1 (main:0.1 - highest LastUsed), got %d", index3)
	}

	// Test when no suitable pane found (all panes excluded)
	singlePane := []TmuxPane{
		{FullID: "main:0.0", LastUsed: 1000, IsActive: false},
	}
	index4 := client.findMostRecentPaneIndex(singlePane, "main:0.0")
	if index4 != -1 {
		t.Errorf("Expected index -1 when no suitable pane found, got %d", index4)
	}
}

// Test helper functions for pane parsing (if we wanted to test tmux command parsing)
func TestParseTmuxPaneOutput(t *testing.T) {
	// This would test parsing tmux list-panes output
	// For now, this is a placeholder since the parsing is done in GetPanes
	// and would require mocking exec.Command which is complex

	// Example tmux output:
	// main|0|0|bash|1642678800|1
	// main|0|1|vim|1642678750|0

	// We could test this by extracting the parsing logic to a separate function
	// and then testing that function independently
}

// Integration test placeholder
func TestClient_Integration(t *testing.T) {
	// This would be an integration test that actually requires tmux to be running
	// We skip it in normal test runs
	if os.Getenv("TMUX") == "" {
		t.Skip("Skipping integration test - not running in tmux")
	}

	client := NewClient()

	// Test getting current pane ID
	paneID, err := client.GetCurrentPaneID()
	if err != nil {
		t.Errorf("Error getting current pane ID: %v", err)
	}
	if paneID == "" {
		t.Error("Expected non-empty pane ID")
	}

	// Test getting panes
	panes, err := client.GetPanes()
	if err != nil {
		t.Errorf("Error getting panes: %v", err)
	}
	if len(panes) == 0 {
		t.Error("Expected at least one pane")
	}

	// Test capturing pane content
	content, err := client.CapturePaneContent()
	if err != nil {
		t.Errorf("Error capturing pane content: %v", err)
	}
	if len(content) == 0 {
		t.Error("Expected at least one pane content")
	}
}
