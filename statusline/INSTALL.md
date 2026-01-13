# Statusline Installation Guide

This custom statusline for Claude Code displays rich information including directory, git status, model, session cost, duration, and token usage.

## Installation

1. **Copy the script to your Claude configuration directory:**

```bash
cp statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

2. **Update your Claude Code settings:**

Add the following to your `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh",
    "padding": 0
  }
}
```

Or merge with your existing settings if you already have a settings file.

## Requirements

- `jq` - JSON processor (install via `brew install jq` on macOS)
- `bc` - Basic calculator (usually pre-installed)
- Git (for git repository information)

## Features

The statusline displays:

- **Current directory** (with tilde notation for home directory)
- **Git information** (branch name and change stats)
- **Model information** (with emoji icons: 🎭 Opus, 🎵 Sonnet, 🌸 Haiku)
- **Session duration** (total and API time)
- **Session cost** (in USD)
- **Token usage**:
  - ↓ Total input tokens
  - ↑ Total output tokens
  - Current context / Context window size
  - Context usage percentage with emoji indicators:
    - 🧠 Low usage (<40%)
    - 🤖 Normal usage (40-70%)
    - 🥴 High usage (>70%)

## Example Output

```
~/www/myproject | main (+145,-23) | 🎵 Sonnet 4.5 | ⏱️ 5m23s (2m45s API) | $0.0234 | ↓15.2K ↑8.4K | 123.5K/1M (🧠 12%)
```

## Customization

You can customize the script by modifying:
- Color codes (defined in the `CYAN`, `YELLOW`, etc. variables)
- Model icons (in the `case "$name_lower"` block)
- Context usage thresholds (in the token display section)
- Display format (in the final echo statements)
