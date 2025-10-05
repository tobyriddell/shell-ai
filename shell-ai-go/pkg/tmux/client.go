package tmux

import (
	"fmt"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"shell-ai-go/pkg/ai"

	"github.com/gdamore/tcell/v2"
)

// Client handles tmux operations
type Client struct {
	inTmux      bool
	currentPane string
}

// TmuxPane represents a tmux pane (copied from tmux-selector-go)
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

// NewClient creates a new tmux client
func NewClient() *Client {
	return &Client{
		inTmux: os.Getenv("TMUX") != "",
	}
}

// IsInTmux returns true if running inside tmux
func (c *Client) IsInTmux() bool {
	return c.inTmux
}

// GetCurrentPaneID returns the current pane ID
func (c *Client) GetCurrentPaneID() (string, error) {
	if !c.inTmux {
		return "", fmt.Errorf("not running in tmux")
	}

	cmd := exec.Command("tmux", "display-message", "-p", "#{session_name}:#{window_index}.#{pane_index}")
	output, err := cmd.Output()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(string(output)), nil
}

// GetPanes returns all tmux panes
func (c *Client) GetPanes() ([]TmuxPane, error) {
	if !c.inTmux {
		return nil, fmt.Errorf("not running in tmux")
	}

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

// SelectPane interactively selects a tmux pane
func (c *Client) SelectPane() (*TmuxPane, error) {
	if !c.inTmux {
		return nil, fmt.Errorf("not running in tmux")
	}

	panes, err := c.GetPanes()
	if err != nil {
		return nil, fmt.Errorf("failed to get tmux panes: %w", err)
	}

	if len(panes) == 0 {
		return nil, fmt.Errorf("no tmux panes found")
	}

	return c.interactivePaneSelector(panes)
}

// SendToPane sends text to a specific tmux pane
func (c *Client) SendToPane(paneID, text string) error {
	if !c.inTmux {
		return fmt.Errorf("not running in tmux")
	}

	cmd := exec.Command("tmux", "send-keys", "-t", paneID, text, "C-m")
	return cmd.Run()
}

// SendCommandsToPane sends multiple commands to a pane with confirmation
func (c *Client) SendCommandsToPane(paneID string, commands []ai.Command) error {
	if !c.inTmux {
		return fmt.Errorf("not running in tmux")
	}

	for _, cmd := range commands {
		fmt.Printf("Send command: %s\n", cmd.Command)
		if cmd.Description != "" {
			fmt.Printf("Description: %s\n", cmd.Description)
		}
		if !cmd.Safe {
			fmt.Print("⚠️  This command may be destructive. ")
		}

		fmt.Print("Send this command? [Y/n/s(kip)]: ")
		var response string
		fmt.Scanln(&response)

		switch strings.ToLower(response) {
		case "n", "no":
			fmt.Println("Cancelled.")
			return nil
		case "s", "skip":
			fmt.Println("Skipped.")
			continue
		default:
			err := c.SendToPane(paneID, cmd.Command)
			if err != nil {
				return fmt.Errorf("failed to send command to pane: %w", err)
			}
			fmt.Println("Command sent.")
		}
	}

	return nil
}

// CapturePaneContent captures content from all panes
func (c *Client) CapturePaneContent() ([]ai.PaneContent, error) {
	if !c.inTmux {
		return nil, fmt.Errorf("not running in tmux")
	}

	panes, err := c.GetPanes()
	if err != nil {
		return nil, err
	}

	var content []ai.PaneContent

	for _, pane := range panes {
		cmd := exec.Command("tmux", "capture-pane", "-t", pane.FullID, "-p")
		output, err := cmd.Output()
		if err != nil {
			// Skip panes we can't capture
			continue
		}

		content = append(content, ai.PaneContent{
			PaneID:   pane.FullID,
			Title:    pane.PaneTitle,
			Content:  string(output),
			IsActive: pane.IsActive,
			LastUsed: int64(pane.LastUsed),
		})
	}

	return content, nil
}

// findMostRecentPane finds the most recently used pane excluding current
func (c *Client) findMostRecentPane(panes []TmuxPane, currentPaneID string) *TmuxPane {
	var bestPane *TmuxPane
	var bestTime uint64

	for i := range panes {
		pane := &panes[i]
		// Skip current pane
		if pane.FullID == currentPaneID {
			continue
		}

		// Prioritize most recently used panes (highest LastUsed timestamp)
		if pane.LastUsed > bestTime {
			bestTime = pane.LastUsed
			bestPane = pane
		}
	}

	return bestPane
}

// interactivePaneSelector provides interactive pane selection
func (c *Client) interactivePaneSelector(panes []TmuxPane) (*TmuxPane, error) {
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
	currentPaneID, _ := c.GetCurrentPaneID()
	selectedIndex := 0
	if idx := c.findMostRecentPaneIndex(panes, currentPaneID); idx >= 0 {
		selectedIndex = idx
	}

	// Main event loop
	for {
		c.displayPanes(screen, panes, selectedIndex)
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

func (c *Client) findMostRecentPaneIndex(panes []TmuxPane, currentPaneID string) int {
	bestIndex := -1
	var bestTime uint64

	for i, pane := range panes {
		// Skip current pane
		if pane.FullID == currentPaneID {
			continue
		}

		// Prioritize most recently used panes (highest LastUsed timestamp)
		if pane.LastUsed > bestTime {
			bestTime = pane.LastUsed
			bestIndex = i
		}
	}

	return bestIndex
}

func (c *Client) displayPanes(screen tcell.Screen, panes []TmuxPane, selectedIndex int) {
	screen.Clear()

	// Header
	style := tcell.StyleDefault.Foreground(tcell.ColorYellow)
	c.drawText(screen, 0, 0, "Select target tmux pane:", style)

	style = tcell.StyleDefault.Foreground(tcell.ColorGray)
	c.drawText(screen, 0, 1, "Use ↑↓/WS/KJ to navigate, Enter to select, q to cancel", style)

	// Pane list
	for i, pane := range panes {
		y := i + 3
		if i == selectedIndex {
			// Highlighted selection
			style = tcell.StyleDefault.Background(tcell.ColorWhite).Foreground(tcell.ColorBlack).Bold(true)
			text := fmt.Sprintf("  > %s", pane.DisplayName())
			c.drawText(screen, 0, y, text, style)
		} else {
			// Normal item
			style = tcell.StyleDefault
			text := fmt.Sprintf("    %s", pane.DisplayName())
			c.drawText(screen, 0, y, text, style)
		}
	}
}

func (c *Client) drawText(screen tcell.Screen, x, y int, text string, style tcell.Style) {
	for i, r := range text {
		screen.SetContent(x+i, y, r, nil, style)
	}
}
