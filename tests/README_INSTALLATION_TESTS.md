# Installation Test Suite

This directory contains comprehensive tests for the Shell AI `install.sh` script to ensure it works correctly with various shell and terminal configurations.

## Test Coverage

The test suite covers **24 different test scenarios** combining:

### Shell Configurations
- **Simple Bash**: Basic bash configuration
- **Oh My Bash**: Oh My Bash framework with plugins and themes
- **Simple Zsh**: Basic zsh configuration  
- **Oh My Zsh**: Oh My Zsh framework with plugins and themes

### tmux Configurations
- **Simple tmux**: Basic `~/.tmux.conf` configuration
- **Oh My Tmux (.tmux.conf.local)**: Oh My Tmux with `~/.tmux.conf.local`
- **Oh My Tmux (.config/tmux/tmux.conf.local)**: Oh My Tmux with `~/.config/tmux/tmux.conf.local`

### Atuin Configuration
- **With Atuin**: Atuin shell history replacement installed
- **Without Atuin**: No Atuin installation

## Test Matrix

### Bash Tests (12 tests)
1. Simple Bash + Simple tmux + No Atuin
2. Simple Bash + Simple tmux + Atuin
3. Simple Bash + Oh My Tmux Local + No Atuin
4. Simple Bash + Oh My Tmux Local + Atuin
5. Simple Bash + Oh My Tmux Config + No Atuin
6. Simple Bash + Oh My Tmux Config + Atuin
7. Oh My Bash + Simple tmux + No Atuin
8. Oh My Bash + Simple tmux + Atuin
9. Oh My Bash + Oh My Tmux Local + No Atuin
10. Oh My Bash + Oh My Tmux Local + Atuin
11. Oh My Bash + Oh My Tmux Config + No Atuin
12. Oh My Bash + Oh My Tmux Config + Atuin

### Zsh Tests (12 tests)
13. Simple Zsh + Simple tmux + No Atuin
14. Simple Zsh + Simple tmux + Atuin
15. Simple Zsh + Oh My Tmux Local + No Atuin
16. Simple Zsh + Oh My Tmux Local + Atuin
17. Simple Zsh + Oh My Tmux Config + No Atuin
18. Simple Zsh + Oh My Tmux Config + Atuin
19. Oh My Zsh + Simple tmux + No Atuin
20. Oh My Zsh + Simple tmux + Atuin
21. Oh My Zsh + Oh My Tmux Local + No Atuin
22. Oh My Zsh + Oh My Tmux Local + Atuin
23. Oh My Zsh + Oh My Tmux Config + No Atuin
24. Oh My Zsh + Oh My Tmux Config + Atuin

## Running the Tests

### Run All Installation Tests
```bash
# From project root
bash tests/test_runner.sh install
```

### Run Installation Tests Directly
```bash
# From project root
bash tests/test_installation.sh

# Run with debug mode for first test
bash tests/test_installation.sh debug

# Run with full debug mode (shows all installer output)
SHELL_AI_TEST_DEBUG=1 bash tests/test_installation.sh
```

### Run Individual Tests
```bash
# Source the test file and run specific tests
source tests/test_installation.sh
run_test "Test Name" test_function_name
```

## What Each Test Verifies

### 1. **Shell AI Scripts Installation**
- All required scripts are copied to `~/.config/shell-ai/`
- Scripts are executable
- Scripts include: `ai-setup.sh`, `ai-shell.sh`, `ai-copy.sh`, `tmux-ai-pane.sh`, `welcome.sh`

### 2. **Shell Integration**
- Shell AI integration is added to `.bashrc` or `.zshrc`
- Shell-specific configuration file is installed (`bashrc-ai.sh` or `zshrc-ai.sh`)
- Integration is properly sourced in shell configuration
- Only single integration entry (no duplicates)

### 3. **tmux Integration**
- Shell AI integration is added to the appropriate tmux configuration file
- tmux keybindings are properly configured
- Integration detects and uses Oh My Tmux local config files when present
- Only single integration entry (no duplicates)

### 4. **Existing Configuration Preservation**
- Existing shell configurations are preserved
- Oh My Bash/Oh My Zsh configurations remain intact
- Oh My Tmux configurations are properly extended

### 5. **Atuin Compatibility**
- Installation works with and without Atuin
- Atuin configurations are preserved when present

## Test Environment

- **Isolated**: Each test runs in a completely isolated temporary environment
- **Clean**: Fresh environment for each test prevents interference
- **Safe**: No modification to actual user configurations
- **Comprehensive**: Tests all supported configuration combinations

## Test Infrastructure

### Key Components
- **Environment Setup**: Functions to simulate different shell/tmux/atuin configurations
- **Verification Functions**: Check that installations worked correctly
- **Test Framework**: Manages test execution, results, and cleanup
- **Mock Installer**: Provides automated responses to installer prompts

### Test Flow
1. **Setup**: Create isolated test environment
2. **Configure**: Set up specific shell/tmux/atuin configuration
3. **Install**: Run install.sh with automated responses
4. **Verify**: Check all installation aspects
5. **Cleanup**: Remove test environment

## Extending the Tests

To add new test scenarios:

1. **Add Environment Setup**: Create new setup functions if needed
2. **Add Test Function**: Create new test function following naming convention
3. **Add to Test Runner**: Include in main() function
4. **Add Verification**: Create specific verification functions if needed

## Dependencies

- `bash` - Test runner and framework
- `jq` - JSON processing for config files
- Standard Unix tools: `grep`, `mkdir`, `chmod`, `cat`, etc.

## Troubleshooting

### Common Issues
- **Permission Errors**: Ensure test script is executable
- **Missing Dependencies**: Install `jq` and required tools
- **Path Issues**: Run from project root directory

### Debug Mode
Set `SHELL_AI_TEST_DEBUG=1` to enable verbose output:
```bash
SHELL_AI_TEST_DEBUG=1 bash tests/test_installation.sh
```

## Integration with CI/CD

The test suite is designed to be CI/CD friendly:
- Non-interactive operation
- Clear exit codes (0 = success, 1 = failure)
- Detailed logging and error reporting
- Isolated test environments prevent conflicts 