package response

import (
	"fmt"
	"regexp"
	"strings"

	"shell-ai-go/pkg/ai"
)

// Parser handles parsing AI responses to extract commands
type Parser struct {
	dangerousCommands []string
	dangerousPatterns []*regexp.Regexp
}

// NewParser creates a new response parser
func NewParser() *Parser {
	// List of potentially dangerous commands
	dangerous := []string{
		"rm", "rmdir", "dd", "mkfs", "fdisk", "format",
		"shutdown", "reboot", "halt", "poweroff",
		"chmod", "chown", "sudo", "su",
		"iptables", "ufw", "firewall-cmd",
		"crontab", "systemctl", "service",
		"passwd", "usermod", "userdel",
		"apt", "yum", "dnf", "pacman", "snap",
		"wget", "curl", "pip", "npm", "gem",
	}

	// Compile patterns for dangerous operations
	patterns := []*regexp.Regexp{
		regexp.MustCompile(`\s+/\s*$`),                   // Operations on root directory
		regexp.MustCompile(`rm\s+.*-r.*\s*\*`),           // Recursive rm with wildcards
		regexp.MustCompile(`>\s*/dev/`),                  // Writing to device files
		regexp.MustCompile(`curl\s+.*\s*\|\s*(sh|bash)`), // Curl piped to shell
		regexp.MustCompile(`wget\s+.*\s*\|\s*(sh|bash)`), // Wget piped to shell
	}

	return &Parser{
		dangerousCommands: dangerous,
		dangerousPatterns: patterns,
	}
}

// ExtractCommands extracts shell commands from AI response
func (p *Parser) ExtractCommands(content string) *ai.CommandExtraction {
	commands := []ai.Command{}
	lines := strings.Split(content, "\n")

	inCodeBlock := false
	codeBlockLanguage := ""
	lineNumber := 0

	for _, line := range lines {
		lineNumber++
		trimmed := strings.TrimSpace(line)

		// Check for code block markers
		if strings.HasPrefix(trimmed, "```") {
			if inCodeBlock {
				inCodeBlock = false
				codeBlockLanguage = ""
			} else {
				inCodeBlock = true
				// Extract language if specified
				if len(trimmed) > 3 {
					codeBlockLanguage = strings.TrimSpace(trimmed[3:])
				}
			}
			continue
		}

		// Extract commands from code blocks
		if inCodeBlock {
			cmd := p.parseCommandLine(trimmed, lineNumber)
			if cmd != nil {
				// Mark as shell command if in bash/sh block or no language specified
				if codeBlockLanguage == "" || codeBlockLanguage == "bash" ||
					codeBlockLanguage == "sh" || codeBlockLanguage == "shell" {
					commands = append(commands, *cmd)
				}
			}
			continue
		}

		// Look for shell-like patterns outside code blocks
		if strings.HasPrefix(trimmed, "$ ") || strings.HasPrefix(trimmed, "# ") {
			cmdText := strings.TrimSpace(trimmed[2:])
			cmd := p.parseCommandLine(cmdText, lineNumber)
			if cmd != nil {
				commands = append(commands, *cmd)
			}
		} else if strings.HasPrefix(trimmed, "> ") {
			// PowerShell-like prompt
			cmdText := strings.TrimSpace(trimmed[2:])
			cmd := p.parseCommandLine(cmdText, lineNumber)
			if cmd != nil {
				commands = append(commands, *cmd)
			}
		}
	}

	// Generate explanation
	explanation := p.generateExplanation(commands)

	return &ai.CommandExtraction{
		Commands:    commands,
		Explanation: explanation,
	}
}

// parseCommandLine parses a single command line
func (p *Parser) parseCommandLine(cmdText string, lineNumber int) *ai.Command {
	if cmdText == "" || strings.HasPrefix(cmdText, "#") {
		return nil
	}

	// Skip obvious non-commands
	if strings.Contains(cmdText, "...") || strings.Contains(cmdText, "<") || strings.Contains(cmdText, ">") {
		// Check if it's actually a redirection
		if !strings.Contains(cmdText, " > ") && !strings.Contains(cmdText, " < ") &&
			!strings.Contains(cmdText, " >> ") && !strings.Contains(cmdText, " 2>") {
			return nil
		}
	}

	// Extract description if present (commands with inline comments)
	description := ""
	commentIndex := strings.Index(cmdText, " # ")
	if commentIndex > 0 {
		description = strings.TrimSpace(cmdText[commentIndex+3:])
		cmdText = strings.TrimSpace(cmdText[:commentIndex])
	}

	// Assess safety
	safe := p.assessCommandSafety(cmdText)

	return &ai.Command{
		Command:     cmdText,
		Description: description,
		Safe:        safe,
		LineNumber:  lineNumber,
	}
}

// assessCommandSafety determines if a command is safe to execute
func (p *Parser) assessCommandSafety(command string) bool {
	lowerCmd := strings.ToLower(command)

	// Split command into words to check for exact command matches
	words := strings.Fields(lowerCmd)
	if len(words) == 0 {
		return true
	}

	// Get the first word (the actual command)
	firstWord := words[0]

	// Check for dangerous commands (exact match or starts with dangerous command)
	for _, dangerous := range p.dangerousCommands {
		if firstWord == dangerous || strings.HasPrefix(firstWord, dangerous+".") {
			return false
		}
	}

	// Check for dangerous patterns
	for _, pattern := range p.dangerousPatterns {
		if pattern.MatchString(lowerCmd) {
			return false
		}
	}

	// Additional safety checks
	if strings.Contains(lowerCmd, "rm ") && (strings.Contains(lowerCmd, "*") || strings.Contains(lowerCmd, "/")) {
		return false
	}

	if strings.Contains(lowerCmd, "sudo") || strings.Contains(lowerCmd, "su ") {
		return false
	}

	return true
}

// generateExplanation creates an explanation of the extracted commands
func (p *Parser) generateExplanation(commands []ai.Command) string {
	if len(commands) == 0 {
		return "No executable commands found in the response."
	}

	var builder strings.Builder
	builder.WriteString(fmt.Sprintf("Found %d command(s):\n", len(commands)))

	safeCount := 0
	unsafeCount := 0

	for i, cmd := range commands {
		if cmd.Safe {
			safeCount++
		} else {
			unsafeCount++
		}

		status := "✅"
		if !cmd.Safe {
			status = "⚠️"
		}

		builder.WriteString(fmt.Sprintf("%d. %s %s", i+1, status, cmd.Command))
		if cmd.Description != "" {
			builder.WriteString(fmt.Sprintf(" - %s", cmd.Description))
		}
		builder.WriteString("\n")
	}

	if unsafeCount > 0 {
		builder.WriteString(fmt.Sprintf("\n⚠️  Warning: %d command(s) marked as potentially unsafe", unsafeCount))
	}

	return builder.String()
}

// FormatCommands formats commands for display
func (p *Parser) FormatCommands(commands []ai.Command) string {
	if len(commands) == 0 {
		return "No commands found."
	}

	var builder strings.Builder

	for i, cmd := range commands {
		if i > 0 {
			builder.WriteString("\n")
		}

		// Add safety indicator
		if cmd.Safe {
			builder.WriteString("✅ ")
		} else {
			builder.WriteString("⚠️  ")
		}

		builder.WriteString(cmd.Command)

		if cmd.Description != "" {
			builder.WriteString(fmt.Sprintf("  # %s", cmd.Description))
		}
	}

	return builder.String()
}

// GroupCommandsBySafety groups commands by their safety level
func (p *Parser) GroupCommandsBySafety(commands []ai.Command) (safe, unsafe []ai.Command) {
	for _, cmd := range commands {
		if cmd.Safe {
			safe = append(safe, cmd)
		} else {
			unsafe = append(unsafe, cmd)
		}
	}
	return safe, unsafe
}
