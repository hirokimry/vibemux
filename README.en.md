# vibemux

> The canonical README is the Japanese version ([README.md](README.md)). This English version is kept for reference and may lag behind.

[日本語](README.md)

Vibe coding workspace for tmux.

One command launches a 2-pane tmux session — git client and AI coding assistant side-by-side. Your terminal becomes a fully-equipped vibe coding cockpit.

```text
┌──────────┬─────────────────────┐
│          │                     │
│ lazygit  │    AI assistant     │
│          │                     │
└──────────┴─────────────────────┘
```

## Why vibemux?

In AI-driven development, you instruct an agent in the shell and verify changes in lazygit — these two activities cover the human's main work. vibemux puts both in one view so you never break your flow switching windows.

## Install

```bash
git clone https://github.com/hirokimry/vibemux.git
cd vibemux
make install
```

`make install` creates an absolute-path symlink at `~/.local/bin/vibemux`. If `~/.local/bin` is not on your `$PATH`, the command prints instructions for adding it.

Prefer not to use `make`? Just copy the `vibemux` script anywhere on your `$PATH`.

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
| `VIBEMUX_PANE_LEFT` | Left pane command | `lazygit` |
| `VIBEMUX_PANE_RIGHT` | Right pane command | *(shell)* |
| `VIBEMUX_RIGHT_RATIO` | Right pane width (%) | `70` |
| `VIBEMUX_FOCUS` | Initial focus: `right`, `left` | `right` |

### Config File

```bash
# ~/.config/vibemux/config
VIBEMUX_PANE_LEFT="lazygit"
VIBEMUX_PANE_RIGHT="claude --resume"
VIBEMUX_RIGHT_RATIO=70
VIBEMUX_FOCUS=right
```

Set `VIBEMUX_CONFIG` to load from a different path.

### Example Setups

**Claude Code + lazygit** (recommended):

```bash
VIBEMUX_PANE_RIGHT="claude --resume" vibemux new dev
```

**Aider + tig:**

```bash
VIBEMUX_PANE_LEFT="tig"
VIBEMUX_PANE_RIGHT="aider"
```

**Minimal — AI assistant only:**

```bash
VIBEMUX_PANE_LEFT="" VIBEMUX_PANE_RIGHT="claude" vibemux new focus
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
