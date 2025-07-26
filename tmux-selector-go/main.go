package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"github.com/gdamore/tcell/v2"
	"github.com/spf13/cobra"
)

type TmuxPane struct {
	SessionName string `json:"session_name"`
	WindowIndex string `json:"window_index"`
	PaneIndex   string `json:"pane_index"`
	PaneTitle   string `json:"pane_title"`
	LastUsed    uint64 `json:"last_used"`
	IsActive    bool   `json:"is_active"`
	FullID      string `json:"full_id"`
}

func (p *TmuxPane) DisplayName() string {
	return fmt.Sprintf("%s - %s", p.FullID, p.PaneTitle)
}

var (
	outputFormat string
	autoSelect   bool
)

var rootCmd = &cobra.Command{
	Use:   "tmux-selector",
	Short: "High-performance tmux pane selector",
	Long:  "A fast, interactive tmux pane selector with keyboard navigation and multiple output formats",
	RunE:  runSelector,
}

func init() {
	rootCmd.Flags().StringVarP(&outputFormat, "format", "f", "plain", "Output format: json or plain")
	rootCmd.Flags().BoolVarP(&autoSelect, "auto", "a", false, "Auto-select the most recently used pane")
}

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func runSelector(cmd *cobra.Command, args []string) error {
	// Check if we're in tmux
	if os.Getenv("TMUX") == "" {
		return fmt.Errorf("Not running in tmux")
	}

	panes, err := getTmuxPanes()
	if err != nil {
		return fmt.Errorf("Failed to get tmux panes: %v", err)
	}

	if len(panes) == 0 {
		return fmt.Errorf("No tmux panes found")
	}

	var selectedPane *TmuxPane

	if autoSelect {
		// Auto-select most recently used pane
		currentPaneID, err := getCurrentPaneID()
		if err != nil {
			return fmt.Errorf("Failed to get current pane ID: %v", err)
		}

		selectedPane = findMostRecentPane(panes, currentPaneID)
		if selectedPane == nil {
			return fmt.Errorf("No suitable pane found for auto-selection")
		}
	} else {
		// Interactive selection
		selectedPane, err = interactivePaneSelector(panes)
		if err != nil {
			return err
		}
		if selectedPane == nil {
			return fmt.Errorf("Pane selection cancelled")
		}
	}

	// Output result based on format
	switch outputFormat {
	case "json":
		jsonOutput, err := json.Marshal(selectedPane)
		if err != nil {
			return fmt.Errorf("Failed to marshal JSON: %v", err)
		}
		fmt.Println(string(jsonOutput))
	default:
		fmt.Println(selectedPane.FullID)
	}

	return nil
}

func getCurrentPaneID() (string, error) {
	cmd := exec.Command("tmux", "display-message", "-p", "#{session_name}:#{window_index}.#{pane_index}")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

func getTmuxPanes() ([]TmuxPane, error) {
	cmd := exec.Command("tmux", "list-panes", "-a", "-F",
		"#{session_name}|#{window_index}|#{pane_index}|#{pane_title}|#{t:last-used}|#{pane_active}")
	output, err := cmd.Output()
	if err != nil {
		return nil, err
	}

	lines := strings.Split(strings.TrimSpace(string(output)), "\n")
	panes := make([]TmuxPane, 0, len(lines))

	for _, line := range lines {
		if line == "" {
			continue
		}

		parts := strings.Split(line, "|")
		if len(parts) < 6 {
			continue
		}

		lastUsed, _ := strconv.ParseUint(parts[4], 10, 64)
		isActive := parts[5] == "1"
		fullID := fmt.Sprintf("%s:%s.%s", parts[0], parts[1], parts[2])

		pane := TmuxPane{
			SessionName: parts[0],
			WindowIndex: parts[1],
			PaneIndex:   parts[2],
			PaneTitle:   parts[3],
			LastUsed:    lastUsed,
			IsActive:    isActive,
			FullID:      fullID,
		}

		panes = append(panes, pane)
	}

	return panes, nil
}

func findMostRecentPane(panes []TmuxPane, currentPaneID string) *TmuxPane {
	var bestPane *TmuxPane
	var bestTime uint64

	for i := range panes {
		pane := &panes[i]
		// Skip current pane
		if pane.FullID == currentPaneID {
			continue
		}

		// Prioritize active panes or recently used panes
		if pane.IsActive || pane.LastUsed > bestTime {
			bestTime = pane.LastUsed
			bestPane = pane
		}
	}

	return bestPane
}

func interactivePaneSelector(panes []TmuxPane) (*TmuxPane, error) {
	// Initialize screen
	screen, err := tcell.NewScreen()
	if err != nil {
		return nil, err
	}

	if err := screen.Init(); err != nil {
		return nil, err
	}
	defer screen.Fini()

	// Find initial selection (most recently used)
	currentPaneID, _ := getCurrentPaneID()
	selectedIndex := 0
	if idx := findMostRecentPaneIndex(panes, currentPaneID); idx >= 0 {
		selectedIndex = idx
	}

	// Main event loop
	for {
		displayPanes(screen, panes, selectedIndex)
		screen.Show()

		// Handle events
		ev := screen.PollEvent()
		switch ev := ev.(type) {
		case *tcell.EventKey:
			switch ev.Key() {
			case tcell.KeyUp, tcell.KeyCtrlK:
				selectedIndex = (selectedIndex - 1 + len(panes)) % len(panes)
			case tcell.KeyDown, tcell.KeyCtrlJ:
				selectedIndex = (selectedIndex + 1) % len(panes)
			case tcell.KeyLeft, tcell.KeyCtrlH:
				selectedIndex = (selectedIndex - 1 + len(panes)) % len(panes)
			case tcell.KeyRight, tcell.KeyCtrlL:
				selectedIndex = (selectedIndex + 1) % len(panes)
			case tcell.KeyEnter:
				return &panes[selectedIndex], nil
			case tcell.KeyEscape, tcell.KeyCtrlC:
				return nil, nil
			case tcell.KeyRune:
				switch ev.Rune() {
				case 'w', 'W', 'k', 'K':
					selectedIndex = (selectedIndex - 1 + len(panes)) % len(panes)
				case 's', 'S', 'j', 'J':
					selectedIndex = (selectedIndex + 1) % len(panes)
				case 'a', 'A', 'h', 'H':
					selectedIndex = (selectedIndex - 1 + len(panes)) % len(panes)
				case 'd', 'D', 'l', 'L':
					selectedIndex = (selectedIndex + 1) % len(panes)
				case 'q', 'Q':
					return nil, nil
				}
			}
		case *tcell.EventResize:
			screen.Sync()
		}
	}
}

func findMostRecentPaneIndex(panes []TmuxPane, currentPaneID string) int {
	bestIndex := -1
	var bestTime uint64

	for i, pane := range panes {
		// Skip current pane
		if pane.FullID == currentPaneID {
			continue
		}

		// Prioritize active panes or recently used panes
		if pane.IsActive || pane.LastUsed > bestTime {
			bestTime = pane.LastUsed
			bestIndex = i
		}
	}

	return bestIndex
}

func displayPanes(screen tcell.Screen, panes []TmuxPane, selectedIndex int) {
	screen.Clear()

	// Header
	style := tcell.StyleDefault.Foreground(tcell.ColorYellow)
	drawText(screen, 0, 0, "Select target tmux pane:", style)

	style = tcell.StyleDefault.Foreground(tcell.ColorGray)
	drawText(screen, 0, 1, "Use ↑↓/WS/KJ to navigate, Enter to select, q to cancel", style)

	// Pane list
	for i, pane := range panes {
		y := i + 3
		if i == selectedIndex {
			// Highlighted selection
			style = tcell.StyleDefault.Background(tcell.ColorWhite).Foreground(tcell.ColorBlack).Bold(true)
			text := fmt.Sprintf("  > %s", pane.DisplayName())
			drawText(screen, 0, y, text, style)
		} else {
			// Normal item
			style = tcell.StyleDefault
			text := fmt.Sprintf("    %s", pane.DisplayName())
			drawText(screen, 0, y, text, style)
		}
	}
}

func drawText(screen tcell.Screen, x, y int, text string, style tcell.Style) {
	for i, r := range text {
		screen.SetContent(x+i, y, r, nil, style)
	}
} 