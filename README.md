# MikoCode

MikoCode is a macOS setup script plus launcher command for a focused coding workspace:

- `tmux` session with 3 panes: editor, shell, AI
- `neovim` preconfigured with file tree, diff tools, telescope, statusline, etc.
- one command to open any project in the same layout every time

The installer creates a `mikocode` command in your PATH.

## What this repo contains

- `install.sh` - installs dependencies and writes all configs/scripts

This is intentionally opinionated. It manages your local tmux/nvim setup to match the MikoCode workflow.

## Requirements

- macOS (Darwin)
- [Homebrew](https://brew.sh)

## Install

From this repo:

```bash
chmod +x install.sh
./install.sh
source ~/.zshrc
tmux kill-server
mikocode .
```

## What install.sh does

- installs tools with Homebrew (`tmux`, `neovim`, `git`, `ripgrep`, `fzf`, etc.)
- installs Nerd Fonts casks
- writes `~/.tmux.conf` (backs up existing file first)
- writes `~/.config/nvim/init.lua` (backs up existing file first)
- installs Neovim plugins via Lazy
- writes launcher script to `~/.local/bin/mikocode`
- symlinks `mikocode` into your Homebrew `bin` when possible

Backups are created with timestamp suffixes like:

- `~/.tmux.conf.bak.YYYYMMDD-HHMMSS`
- `~/.config/nvim/init.lua.bak.YYYYMMDD-HHMMSS`

## Usage

```bash
mikocode [path]
mikocode --new [path]
mikocode --kill [path]
mikocode --doctor
```

### Behavior

- opens/attaches a per-project tmux session
- left pane: Neovim with sidebar open and a file opened when starting from a directory
- bottom pane: shell
- right pane: AI command (`opencode` by default)
- tmux mouse is enabled

## Environment variables

- `MIKOCODE_AI` (default: `opencode`)
- `MIKOCODE_EDITOR` (default: `nvim`)
- `MIKOCODE_FOCUS` (default: `editor`, options: `editor|shell|ai`)
- `MIKOCODE_START_MODE` (default: `normal`, options: `normal|diff`)
- `MIKOCODE_SESSION` (optional explicit tmux session name)

Example:

```bash
MIKOCODE_AI="opencode --dangerously-skip-permissions" MIKOCODE_FOCUS=ai mikocode .
```

## Notes

- This installer is not a generic dotfiles manager.
- It is designed to fully control tmux + Neovim setup for this workflow.
- If your terminal icons look wrong, use a Nerd Font (MesloLGS NF or Hack Nerd Font).

## Troubleshooting

```bash
mikocode --doctor
```

If tmux config changes do not apply, restart tmux:

```bash
tmux kill-server
mikocode .
```
