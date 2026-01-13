# Claude Code Configurations

This repository contains shared configurations and customizations for [Claude Code](https://claude.com/claude-code).

## Contents

### 📊 Statusline

A feature-rich custom statusline that displays comprehensive session information.

**Location:** `statusline/`

**Features:**
- Current directory with git integration
- Git branch and change statistics (insertions/deletions)
- Model information with visual icons
- Session duration and API time tracking
- Cost tracking per session
- Token usage with context window visualization
- Smart color coding based on context usage

**Quick Start:**
```bash
# Install the statusline
cp statusline/statusline-command.sh ~/.claude/statusline-command.sh
chmod +x ~/.claude/statusline-command.sh
```

Then add the configuration from `statusline/settings.json` to your `~/.claude/settings.json`.

For detailed installation instructions, see [statusline/INSTALL.md](statusline/INSTALL.md).

## Repository Structure

```
.
├── README.md                           # This file
└── statusline/                         # Statusline configuration
    ├── statusline-command.sh          # Main statusline script
    ├── settings.json                  # Settings configuration snippet
    └── INSTALL.md                     # Installation guide
```

## Contributing

Feel free to open issues or pull requests if you have improvements or additional configurations to share.

## License

MIT
