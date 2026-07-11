# MikoCode

MikoCode is a macOS setup script plus launcher command for a focused coding workspace:

- `tmux` session with 3 panes: editor, shell, AI
- `neovim` preconfigured with file tree, diff tools, telescope, statusline, etc.
- one command to open any project in the same layout every time

The installer creates a `mikocode` command in your PATH.

## What this repo contains

- `install.sh` - guided installer (dependencies, configs, launcher)
- `bin/mikocode` - the launcher script installed to `~/.local/bin/mikocode`
- `bin/mikocode-settings` - interactive settings menu installed to `~/.local/bin/mikocode-settings`
- `config/tmux.conf` - tmux config installed to `~/.tmux.conf`
- `config/nvim/init.lua` - Neovim config installed to `~/.config/nvim/init.lua`
- `lib/ui.sh` - shared UI helpers for the installer

This is intentionally opinionated. It manages your local tmux/nvim setup to match the MikoCode workflow.

## Requirements

- macOS (Darwin)
- [Homebrew](https://brew.sh)

## Install

```bash
git clone https://github.com/mikolajwichrowski/mikocode.git
cd mikocode
./install.sh
source ~/.zshrc
tmux kill-server
mikocode .
```

Flags:

- `./install.sh --yes` - non-interactive (skips confirmation prompts)
- `./install.sh --uninstall` - removes the launcher and restores the newest config backups

## What install.sh does

- installs tools with Homebrew (`tmux`, `neovim`, `git`, `ripgrep`, `fzf`, etc.)
- installs Nerd Fonts casks
- removes `alias cat=` lines from `~/.zshrc`/`~/.bashrc` if present (they break tools that pipe through `cat`; a `.bak` copy is kept)
- writes `~/.tmux.conf` (backs up existing file first)
- writes `~/.config/nvim/init.lua` (backs up existing file first)
- installs Neovim plugins via Lazy
- writes launcher script to `~/.local/bin/mikocode`
- symlinks `mikocode` into your Homebrew `bin` when possible
- records the repo location in `~/.config/mikocode/repo` so `mikocode --update` works

Backups are created with timestamp suffixes like:

- `~/.tmux.conf.bak.YYYYMMDD-HHMMSS`
- `~/.config/nvim/init.lua.bak.YYYYMMDD-HHMMSS`

## Usage

```bash
mikocode [path]          # open project (opens/reuses a tab when inside tmux)
mikocode --new [path]    # force a fresh per-project tmux session
mikocode --here [path]   # rebuild the layout in the current tmux window
mikocode --claude [path]   # open with Claude Code in the AI pane
mikocode --opencode [path] # open with opencode in the AI pane
mikocode --codex [path]    # open with Codex in the AI pane
mikocode --ai CMD [path]   # open with any command in the AI pane ("none" = shell)
mikocode --kill [path]   # kill the project's tmux session
mikocode --list          # list mikocode sessions and their workspaces
mikocode --settings      # interactive settings menu (Ctrl-a S inside tmux)
mikocode --update        # git pull the repo and re-run the installer
mikocode --doctor        # environment diagnostics
mikocode --version
```

### Behavior

- outside tmux, `mikocode <path>` opens (or re-attaches to) a per-project tmux session
- **inside tmux, `mikocode <path>` opens a new workspace tab** with the 3-pane layout - your current workspace is left untouched
- if a tab for that project already exists in the session, mikocode just switches to it
- `mikocode --here` rebuilds the layout in the current window (this replaces the old default; it closes the window's other panes)
- `mikocode --new` always creates a fresh per-project tmux session
- workspace/window name is the project folder name (for example `harvester`)
- left pane: editor with sidebar open and a file opened when starting from a directory
- bottom pane: shell
- right pane: AI command (`opencode` by default)
- tmux mouse is enabled

## Keybindings cheatsheet

tmux prefix is `Ctrl-a`.

| Keys | Action |
| --- | --- |
| `Ctrl-t` | new empty workspace (tab) |
| `Ctrl-a c` | new workspace |
| `Ctrl-a x` | close current workspace (with confirmation) |
| `Alt-1` … `Alt-9` | jump to workspace 1-9 |
| `Ctrl-a h/j/k/l` | move between panes |
| `Ctrl-a \|` / `Ctrl-a -` | split horizontally / vertically |
| `Ctrl-a S` | settings popup (centered) |
| `Ctrl-a r` | reload tmux config |
| `Ctrl-a [` then `v`/`y` | copy mode (vi keys, copies to clipboard) |

Neovim (leader is `Space`):

| Keys | Action |
| --- | --- |
| `Space e` | toggle file sidebar |
| `Space d` | diff view |
| `Space cv` | switch code/git view |

The bottom bar shows workspace names (no numeric index), and a purple `+` appears after the last workspace.

Note: `Alt-1`…`Alt-9` requires your terminal to send Option/Alt as Meta (iTerm2: Profiles → Keys → Left Option Key → Esc+).

## Settings

Press `Ctrl-a S` inside tmux (or run `mikocode --settings` anywhere) to open a centered
settings popup. Every change saves and applies immediately. Configurable:

| Setting | Default | Options |
| --- | --- | --- |
| Accent theme | `purple` | purple, blue, green, red, orange, pink, teal, custom tmux color |
| Editor | `nvim` | nvim, vim, hx, micro, emacs, any custom command |
| AI assistant | `opencode` | opencode, claude, codex, gemini, aider, none, any custom command |
| Neovim colorscheme | `tokyonight-night` | tokyonight variants, catppuccin variants, gruvbox, kanagawa, custom |
| Status bar position | `bottom` | bottom, top |
| Mouse support | `on` | on, off |
| Focus pane on open | `editor` | editor, shell, ai |
| Editor start mode | `normal` | normal, diff |
| AI pane width | `30` | 10-80 (%) |
| Shell pane height | `25` | 10-80 (%) |
| Shell pane tips | `on` | on, off |

Settings are stored in `~/.config/mikocode/config` (plain `KEY="value"` lines) and the
tmux theme is generated into `~/.config/mikocode/theme.tmux.conf`. Accent color and
status bar changes apply to running sessions right away; layout, editor, and AI changes
apply to new workspaces.

The menu uses [gum](https://github.com/charmbracelet/gum) when installed (the installer
installs it) and falls back to plain numbered menus otherwise.

## Environment variables

Env vars override the settings file per invocation:

- `MIKOCODE_AI` (default: `opencode`, use `none` for a plain shell in the right pane)
- `MIKOCODE_EDITOR` (default: `nvim`)
- `MIKOCODE_NVIM_THEME` (default: `tokyonight-night`)
- `MIKOCODE_FOCUS` (default: `editor`, options: `editor|shell|ai`)
- `MIKOCODE_START_MODE` (default: `normal`, options: `normal|diff`)
- `MIKOCODE_AI_WIDTH` (default: `30`, right pane width in %)
- `MIKOCODE_SHELL_HEIGHT` (default: `25`, bottom pane height in %)
- `MIKOCODE_TIPS` (default: `on`, keybinding hints in the shell pane)
- `MIKOCODE_SESSION` (optional explicit tmux session name)

Example:

```bash
MIKOCODE_AI="opencode --dangerously-skip-permissions" MIKOCODE_FOCUS=ai mikocode .
```

## Updating

The installer copies files, so a plain `git pull` does not change your installed setup. To update:

```bash
mikocode --update   # git pull + re-run installer non-interactively
```

`mikocode --doctor` tells you when the installed launcher is out of date vs the repo.

## Uninstall

```bash
./install.sh --uninstall
```

Removes the launcher and state dir, and restores your most recent `.tmux.conf` / `init.lua` backups. Homebrew packages are left installed.

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
