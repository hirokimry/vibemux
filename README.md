# vibemux

[日本語](README.ja.md)

Vibe coding workspace for tmux.

One command launches a 3-pane tmux session — file manager, git client, and AI coding assistant side by side. Your terminal becomes a fully-equipped vibe coding cockpit.

```
┌──────────┬─────────────────────┐
│  files   │                     │
│          │    AI assistant      │
├──────────┤                     │
│   git    │                     │
└──────────┴─────────────────────┘
```

## Why vibemux?

Vibe coding with Claude Code, Aider, and Copilot CLI works best in the terminal — but you still need quick access to your file tree and git status. Switching between windows breaks your flow.

vibemux gives you everything in one view: navigate files, review diffs, and talk to your AI assistant without leaving the keyboard.

## Install

```bash
git clone https://github.com/hirokimry/vibemux.git
ln -s "$(pwd)/vibemux/vibemux" ~/.local/bin/vibemux
```

Or just copy the `vibemux` script anywhere on your `$PATH`.

## Quick Start

```bash
vibemux new myproject              # Start in the current directory
vibemux new myproject ~/code/app   # Start in a specific directory
vibemux attach myproject           # Reattach to a running session
vibemux list                       # Show active sessions
```

## Configuration

Customize pane commands via environment variables or a config file at `~/.config/vibemux/config`.

### Environment Variables

| Variable | Description | Default |
|---|---|---|
| `VIBEMUX_PANE_TOP_LEFT` | Top-left pane command | `yazi` |
| `VIBEMUX_PANE_BOTTOM_LEFT` | Bottom-left pane command | `lazygit` |
| `VIBEMUX_PANE_RIGHT` | Right pane command | *(shell)* |
| `VIBEMUX_RIGHT_RATIO` | Right pane width (%) | `70` |
| `VIBEMUX_FOCUS` | Initial focus: `right`, `top-left`, `bottom-left` | `right` |

### Config File

```bash
# ~/.config/vibemux/config
VIBEMUX_PANE_TOP_LEFT="yazi"
VIBEMUX_PANE_BOTTOM_LEFT="lazygit"
VIBEMUX_PANE_RIGHT="claude --resume"
VIBEMUX_RIGHT_RATIO=70
VIBEMUX_FOCUS=right
```

Set `VIBEMUX_CONFIG` to load from a different path.

### Example Setups

**Claude Code + yazi + lazygit** (recommended):

```bash
VIBEMUX_PANE_RIGHT="claude --resume" vibemux new dev
```

**Aider with lf and tig:**

```bash
VIBEMUX_PANE_TOP_LEFT="lf"
VIBEMUX_PANE_BOTTOM_LEFT="tig"
VIBEMUX_PANE_RIGHT="aider"
```

**Minimal — AI assistant only:**

```bash
VIBEMUX_PANE_TOP_LEFT="" VIBEMUX_PANE_BOTTOM_LEFT="" VIBEMUX_PANE_RIGHT="claude" vibemux new focus
```

## Contributing

```bash
git clone https://github.com/hirokimry/vibemux.git
cd vibemux
make setup-hooks   # Enable git hooks
make check         # Run lint + tests locally
```

## Requirements

- [tmux](https://github.com/tmux/tmux) (>= 3.0)
- Bash (>= 4.0)

## License

MIT
