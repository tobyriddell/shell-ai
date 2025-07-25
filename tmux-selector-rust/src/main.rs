use crossterm::{
    cursor,
    event::{self, Event, KeyCode, KeyEvent, KeyModifiers},
    execute,
    style::{Color, Print, ResetColor, SetForegroundColor, Stylize},
    terminal::{self, Clear, ClearType},
    ExecutableCommand,
};
use serde::{Deserialize, Serialize};
use std::io::{self, stdout, stderr, Write};
use std::process::{Command, Stdio};
use clap::Parser;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Output format: json or plain (default: plain)
    #[arg(short, long, default_value = "plain")]
    format: String,
    
    /// Auto-select the most recently used pane
    #[arg(short, long)]
    auto: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct TmuxPane {
    session_name: String,
    window_index: String,
    pane_index: String,
    pane_title: String,
    last_used: u64,
    is_active: bool,
    full_id: String,
}

impl TmuxPane {
    fn display_name(&self) -> String {
        format!("{} - {}", self.full_id, self.pane_title)
    }
}

fn get_current_pane_id() -> Result<String, Box<dyn std::error::Error>> {
    let output = Command::new("tmux")
        .args(&["display-message", "-p", "#{session_name}:#{window_index}.#{pane_index}"])
        .output()?;
    
    if !output.status.success() {
        return Err("Failed to get current pane ID".into());
    }
    
    Ok(String::from_utf8(output.stdout)?.trim().to_string())
}

fn get_tmux_panes() -> Result<Vec<TmuxPane>, Box<dyn std::error::Error>> {
    let output = Command::new("tmux")
        .args(&[
            "list-panes",
            "-a",
            "-F",
            "#{session_name}|#{window_index}|#{pane_index}|#{pane_title}|#{t:last-used}|#{pane_active}"
        ])
        .output()?;

    if !output.status.success() {
        return Err("Failed to get tmux panes".into());
    }

    let output_str = String::from_utf8(output.stdout)?;
    let mut panes = Vec::new();

    for line in output_str.lines() {
        let parts: Vec<&str> = line.split('|').collect();
        if parts.len() >= 6 {
            let session_name = parts[0].to_string();
            let window_index = parts[1].to_string();
            let pane_index = parts[2].to_string();
            let pane_title = parts[3].to_string();
            let last_used = parts[4].parse::<u64>().unwrap_or(0);
            let is_active = parts[5] == "1";
            let full_id = format!("{}:{}.{}", session_name, window_index, pane_index);

            panes.push(TmuxPane {
                session_name,
                window_index,
                pane_index,
                pane_title,
                last_used,
                is_active,
                full_id,
            });
        }
    }

    Ok(panes)
}

fn find_most_recent_pane(panes: &[TmuxPane], current_pane_id: &str) -> Option<usize> {
    let mut best_index = 0;
    let mut best_time = 0;
    let mut found_valid = false;

    for (index, pane) in panes.iter().enumerate() {
        // Skip current pane
        if pane.full_id == current_pane_id {
            continue;
        }

        // Prioritize active panes or recently used panes
        if pane.is_active || (pane.last_used > best_time) {
            best_time = pane.last_used;
            best_index = index;
            found_valid = true;
        }
    }

    if found_valid {
        Some(best_index)
    } else {
        // If no other panes found, return first non-current pane
        panes.iter().position(|p| p.full_id != current_pane_id)
    }
}

fn display_panes(panes: &[TmuxPane], selected_index: usize) -> Result<(), Box<dyn std::error::Error>> {
    let mut stderr = stderr();
    
    // Clear screen
    stderr.execute(Clear(ClearType::All))?;
    stderr.execute(cursor::MoveTo(0, 0))?;

    // Header
    stderr.execute(SetForegroundColor(Color::Yellow))?;
    stderr.execute(Print("Select target tmux pane:\n"))?;
    stderr.execute(ResetColor)?;
    
    stderr.execute(SetForegroundColor(Color::DarkGrey))?;
    stderr.execute(Print("Use ↑↓/WS/KJ to navigate, Enter to select, q to cancel\n\n"))?;
    stderr.execute(ResetColor)?;

    // Pane list
    for (index, pane) in panes.iter().enumerate() {
        if index == selected_index {
            stderr.execute(SetForegroundColor(Color::Black))?;
            stderr.execute(cursor::MoveTo(0, (index + 3) as u16))?;
            eprint!("{}", format!("  > {}", pane.display_name()).on_white().bold());
            stderr.execute(ResetColor)?;
        } else {
            stderr.execute(cursor::MoveTo(0, (index + 3) as u16))?;
            stderr.execute(Print(format!("    {}", pane.display_name())))?;
        }
        stderr.execute(Print("\n"))?;
    }

    stderr.flush()?;
    Ok(())
}

fn interactive_pane_selector(panes: Vec<TmuxPane>) -> Result<Option<String>, Box<dyn std::error::Error>> {
    if panes.is_empty() {
        eprintln!("No tmux panes found");
        return Ok(None);
    }

    let current_pane_id = get_current_pane_id()?;
    let mut selected_index = find_most_recent_pane(&panes, &current_pane_id).unwrap_or(0);

    // Ensure selected_index is within bounds
    if selected_index >= panes.len() {
        selected_index = 0;
    }

    // Enable raw mode for input handling
    terminal::enable_raw_mode()?;

    let result = loop {
        display_panes(&panes, selected_index)?;

        match event::read()? {
            Event::Key(KeyEvent {
                code: KeyCode::Up | KeyCode::Char('w') | KeyCode::Char('W') | 
                      KeyCode::Char('k') | KeyCode::Char('K'),
                modifiers: KeyModifiers::NONE,
                ..
            }) => {
                if selected_index > 0 {
                    selected_index -= 1;
                } else {
                    selected_index = panes.len() - 1;
                }
            }
            Event::Key(KeyEvent {
                code: KeyCode::Down | KeyCode::Char('s') | KeyCode::Char('S') | 
                      KeyCode::Char('j') | KeyCode::Char('J'),
                modifiers: KeyModifiers::NONE,
                ..
            }) => {
                if selected_index < panes.len() - 1 {
                    selected_index += 1;
                } else {
                    selected_index = 0;
                }
            }
            Event::Key(KeyEvent {
                code: KeyCode::Left | KeyCode::Char('a') | KeyCode::Char('A') | 
                      KeyCode::Char('h') | KeyCode::Char('H'),
                modifiers: KeyModifiers::NONE,
                ..
            }) => {
                if selected_index > 0 {
                    selected_index -= 1;
                } else {
                    selected_index = panes.len() - 1;
                }
            }
            Event::Key(KeyEvent {
                code: KeyCode::Right | KeyCode::Char('d') | KeyCode::Char('D') | 
                      KeyCode::Char('l') | KeyCode::Char('L'),
                modifiers: KeyModifiers::NONE,
                ..
            }) => {
                if selected_index < panes.len() - 1 {
                    selected_index += 1;
                } else {
                    selected_index = 0;
                }
            }
            Event::Key(KeyEvent {
                code: KeyCode::Enter,
                modifiers: KeyModifiers::NONE,
                ..
            }) => {
                break Ok(Some(panes[selected_index].full_id.clone()));
            }
            Event::Key(KeyEvent {
                code: KeyCode::Char('q') | KeyCode::Char('Q') | KeyCode::Esc,
                modifiers: KeyModifiers::NONE,
                ..
            }) => {
                break Ok(None);
            }
            Event::Key(KeyEvent {
                code: KeyCode::Char('c'),
                modifiers: KeyModifiers::CONTROL,
                ..
            }) => {
                break Ok(None);
            }
            _ => {}
        }
    };

    // Restore terminal
    terminal::disable_raw_mode()?;
    execute!(stderr(), Clear(ClearType::All), cursor::MoveTo(0, 0))?;

    result
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    // Check if we're in tmux
    if std::env::var("TMUX").is_err() {
        eprintln!("Error: Not running in tmux");
        std::process::exit(1);
    }

    let panes = get_tmux_panes()?;
    
    if panes.is_empty() {
        eprintln!("No tmux panes found");
        std::process::exit(1);
    }

    let selected_pane_id = if args.auto {
        // Auto-select most recently used pane
        let current_pane_id = get_current_pane_id()?;
        match find_most_recent_pane(&panes, &current_pane_id) {
            Some(index) => Some(panes[index].full_id.clone()),
            None => {
                eprintln!("No suitable pane found for auto-selection");
                std::process::exit(1);
            }
        }
    } else {
        // Interactive selection
        interactive_pane_selector(panes.clone())?
    };

    match selected_pane_id {
        Some(pane_id) => {
            match args.format.as_str() {
                "json" => {
                    let selected_pane = panes.iter().find(|p| p.full_id == pane_id).unwrap();
                    let json_output = serde_json::to_string(selected_pane)?;
                    println!("{}", json_output);
                }
                "plain" | _ => {
                    println!("{}", pane_id);
                }
            }
        }
        None => {
            eprintln!("Pane selection cancelled");
            std::process::exit(1);
        }
    }

    Ok(())
} 