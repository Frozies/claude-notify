# Contributing to Claude Notify

Thank you for your interest in contributing to Claude Notify! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Commit Messages](#commit-messages)
- [Pull Request Process](#pull-request-process)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Features](#suggesting-features)

## Code of Conduct

This project adheres to a Code of Conduct. By participating, you are expected to uphold this code. Please read [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) before contributing.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/your-username/claude-notify.git
   cd claude-notify
   ```
3. Add the upstream repository as a remote:
   ```bash
   git remote add upstream https://github.com/original-owner/claude-notify.git
   ```
4. Create a branch for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## How to Contribute

### Types of Contributions

We welcome several types of contributions:

- **Bug fixes** - Fix issues reported in the issue tracker
- **New features** - Add new notification backends or functionality
- **Documentation** - Improve or add documentation
- **Tests** - Add or improve test coverage
- **Platform support** - Extend support to new platforms

### Before You Start

1. Check the [issue tracker](https://github.com/original-owner/claude-notify/issues) for existing issues or feature requests
2. For major changes, open an issue first to discuss your proposed changes
3. Check the [TODO.md](TODO.md) file for planned features and their status

## Development Setup

### Prerequisites

- Git
- Bash (Linux/macOS) or PowerShell (Windows)
- A text editor or IDE

### Linux Development

```bash
# Ensure notify-send is installed
sudo apt install libnotify-bin  # Debian/Ubuntu
sudo dnf install libnotify      # Fedora
sudo pacman -S libnotify        # Arch

# Clone and setup
git clone https://github.com/your-username/claude-notify.git
cd claude-notify

# Test the notification script directly
./hooks/notify.sh --test
```

### macOS Development

```bash
# Optional: Install terminal-notifier for richer notifications
brew install terminal-notifier

# Clone and setup
git clone https://github.com/your-username/claude-notify.git
cd claude-notify

# Test the notification script
./hooks/notify.sh --test
```

### Windows Development

```powershell
# Optional: Install BurntToast for rich notifications
Install-Module -Name BurntToast -Scope CurrentUser

# Clone and setup
git clone https://github.com/your-username/claude-notify.git
cd claude-notify

# Test the notification script
.\hooks\notify.ps1 -Test
```

## Coding Standards

### Shell Scripts (Bash)

- Use `#!/usr/bin/env bash` shebang
- Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use `shellcheck` to lint your scripts:
  ```bash
  shellcheck hooks/notify.sh install.sh uninstall.sh
  ```
- Quote all variables: `"${variable}"` not `$variable`
- Use `[[ ]]` for conditionals instead of `[ ]`
- Add comments for non-obvious logic

### PowerShell Scripts

- Follow [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/strongly-encouraged-development-guidelines)
- Use approved verbs for function names
- Include comment-based help for functions
- Use `PSScriptAnalyzer` for linting

### JSON Configuration

- Use 2-space indentation
- Include comments explaining non-obvious options (where supported)
- Validate JSON before committing:
  ```bash
  cat config/config.example.json | jq .
  ```

## Commit Messages

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Examples

```
feat(ntfy): add support for ntfy.sh push notifications

fix(linux): handle missing notify-send gracefully

docs(readme): add Windows installation instructions

chore(ci): add GitHub Actions workflow
```

## Pull Request Process

1. **Update documentation** - If your changes affect user-facing behavior, update the README and any relevant documentation

2. **Test your changes** - Ensure your changes work on the relevant platform(s):
   ```bash
   # Test notification
   ./hooks/notify.sh --test

   # Test installation (use --dry-run first)
   ./install.sh --dry-run
   ```

3. **Update the changelog** - Add an entry to [CHANGELOG.md](CHANGELOG.md) under "Unreleased"

4. **Create the pull request**:
   - Use a clear, descriptive title
   - Reference any related issues (e.g., "Fixes #123")
   - Describe what changes you made and why
   - Include screenshots for UI changes

5. **Address review feedback** - Be responsive to review comments and make requested changes

### PR Checklist

- [ ] Code follows project coding standards
- [ ] Self-reviewed the code changes
- [ ] Added/updated documentation as needed
- [ ] Added/updated tests as needed
- [ ] Updated CHANGELOG.md
- [ ] All tests pass
- [ ] Commits follow conventional commit format

## Reporting Bugs

When reporting bugs, please include:

1. **Environment information**:
   - Operating system and version
   - Shell version (bash --version or $PSVersionTable)
   - Claude Code version
   - Claude Notify version (cat VERSION)

2. **Steps to reproduce**:
   - Exact commands you ran
   - Expected behavior
   - Actual behavior

3. **Relevant logs/output**:
   - Error messages
   - Debug output if available

### Bug Report Template

```markdown
## Environment
- OS: [e.g., Ubuntu 22.04]
- Shell: [e.g., bash 5.1.16]
- Claude Code: [version]
- Claude Notify: [version from VERSION file]

## Description
[Clear description of the bug]

## Steps to Reproduce
1. [First step]
2. [Second step]
3. [...]

## Expected Behavior
[What you expected to happen]

## Actual Behavior
[What actually happened]

## Additional Context
[Any other relevant information, logs, screenshots]
```

## Suggesting Features

We welcome feature suggestions! When suggesting a feature:

1. **Check existing issues** - Your idea may already be proposed or in development
2. **Check TODO.md** - The feature might already be planned
3. **Open an issue** with:
   - Clear description of the feature
   - Use case / motivation
   - Proposed implementation (if you have ideas)
   - Any alternatives you've considered

### Feature Request Template

```markdown
## Feature Description
[Clear description of the proposed feature]

## Motivation
[Why is this feature needed? What problem does it solve?]

## Proposed Implementation
[If you have ideas on how to implement this]

## Alternatives Considered
[Any alternative approaches you've thought about]

## Additional Context
[Any other relevant information]
```

## Adding a New Notification Backend

To add support for a new notification service:

1. **Create the backend script** in `hooks/`:
   - Follow existing patterns (see `notify.sh` for reference)
   - Support standard options: `--title`, `--message`, `--urgency`, `--icon`
   - Include a `--test` option for verification

2. **Update configuration**:
   - Add backend options to `config/config.example.json`
   - Document configuration in README.md

3. **Update the main notify script**:
   - Add detection/selection logic for the new backend
   - Ensure graceful fallback if the backend is unavailable

4. **Add documentation**:
   - Document setup requirements
   - Add troubleshooting section
   - Include example configuration

5. **Test thoroughly**:
   - Test on the target platform(s)
   - Test with various configuration options
   - Test error handling

## Questions?

If you have questions about contributing, feel free to:

- Open an issue with the "question" label
- Check existing documentation and issues first

Thank you for contributing to Claude Notify!
