# aimux

AI pair programming workspace for tmux.

One command launches a 3-pane tmux session — file manager, git client, and AI coding assistant side by side. Your terminal becomes a fully-equipped AI development cockpit.

```
┌──────────┬─────────────────────┐
│  files   │                     │
│          │    AI assistant      │
├──────────┤                     │
│   git    │                     │
└──────────┴─────────────────────┘
```

## Why aimux?

AI coding assistants like Claude Code, Aider, and Copilot CLI work best in the terminal — but you still need quick access to your file tree and git status. Switching between windows breaks your flow.

aimux gives you everything in one view: navigate files, review diffs, and talk to your AI assistant without leaving the keyboard.

## Install

```bash
git clone https://github.com/hirokimry/aimux.git
ln -s "$(pwd)/aimux/aimux" ~/.local/bin/aimux
```

Or just copy the `aimux` script anywhere on your `$PATH`.

## Quick Start

```bash
aimux new myproject              # Start in the current directory
aimux new myproject ~/code/app   # Start in a specific directory
aimux attach myproject           # Reattach to a running session
aimux list                       # Show active sessions
```

## Configuration

Customize pane commands via environment variables or a config file at `~/.config/aimux/config`.

### Environment Variables

| Variable | Description | Default |
|---|---|---|
| `AIMUX_PANE_TOP_LEFT` | Top-left pane command | `yazi` |
| `AIMUX_PANE_BOTTOM_LEFT` | Bottom-left pane command | `lazygit` |
| `AIMUX_PANE_RIGHT` | Right pane command | *(shell)* |
| `AIMUX_RIGHT_RATIO` | Right pane width (%) | `70` |
| `AIMUX_FOCUS` | Initial focus: `right`, `top-left`, `bottom-left` | `right` |

### Config File

```bash
# ~/.config/aimux/config
AIMUX_PANE_TOP_LEFT="yazi"
AIMUX_PANE_BOTTOM_LEFT="lazygit"
AIMUX_PANE_RIGHT="claude --resume"
AIMUX_RIGHT_RATIO=70
AIMUX_FOCUS=right
```

Set `AIMUX_CONFIG` to load from a different path.

### Example Setups

**Claude Code + yazi + lazygit** (recommended):

```bash
AIMUX_PANE_RIGHT="claude --resume" aimux new dev
```

**Aider with lf and tig:**

```bash
AIMUX_PANE_TOP_LEFT="lf"
AIMUX_PANE_BOTTOM_LEFT="tig"
AIMUX_PANE_RIGHT="aider"
```

**Minimal — AI assistant only:**

```bash
AIMUX_PANE_TOP_LEFT="" AIMUX_PANE_BOTTOM_LEFT="" AIMUX_PANE_RIGHT="claude" aimux new focus
```

## Requirements

- [tmux](https://github.com/tmux/tmux) (>= 3.0)
- Bash (>= 4.0)

## License

MIT
