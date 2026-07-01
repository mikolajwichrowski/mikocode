#!/usr/bin/env bash
set -euo pipefail

# Resolve repo directory so this works from any cwd, following symlinks.
SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

# Section files, relative to the repo root.
UI_LIB="$SCRIPT_DIR/lib/ui.sh"
TMUX_CONF="$SCRIPT_DIR/config/tmux.conf"
NVIM_INIT="$SCRIPT_DIR/config/nvim/init.lua"
MIKOCODE_BIN="$SCRIPT_DIR/bin/mikocode"

for f in "$UI_LIB" "$TMUX_CONF" "$NVIM_INIT" "$MIKOCODE_BIN"; do
  if [[ ! -f "$f" ]]; then
    echo "Missing section file: $f" >&2
    exit 1
  fi
done

ASSUME_YES=0
UNINSTALL=0
for arg in "$@"; do
  case "$arg" in
    -y|--yes) ASSUME_YES=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help)
      echo "Usage: ./install.sh [--yes] [--uninstall]"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (try --help)" >&2
      exit 1
      ;;
  esac
done

TOTAL_STEPS=14
# shellcheck source=lib/ui.sh
source "$UI_LIB"

trap 'warn "Installer failed at line $LINENO."' ERR

if [[ "$UNINSTALL" == "1" ]]; then
  title "MikoCode uninstall"
  subtitle "Removes the launcher and restores config backups. Homebrew packages are left installed."

  rm -f "$HOME/.local/bin/mikocode"
  ok "Removed ~/.local/bin/mikocode"

  for b in /opt/homebrew/bin/mikocode /usr/local/bin/mikocode; do
    if [[ -L "$b" && "$(readlink "$b")" == "$HOME/.local/bin/mikocode" ]]; then
      rm -f "$b"
      ok "Removed symlink $b"
    fi
  done

  restore_latest_backup() {
    local dest="$1"
    local latest
    # shellcheck disable=SC2012
    latest="$(ls -t "$dest".bak.* 2>/dev/null | head -n1 || true)"
    if [[ -n "$latest" ]]; then
      cp "$latest" "$dest"
      ok "Restored $dest from $(basename "$latest")"
    else
      warn "No backup found for $dest (left in place)"
    fi
  }
  restore_latest_backup "$HOME/.tmux.conf"
  restore_latest_backup "$HOME/.config/nvim/init.lua"

  rm -rf "$HOME/.config/mikocode"
  ok "Removed state dir ~/.config/mikocode"

  printf "\n%sUninstall complete.%s\n" "${GREEN}${BOLD}" "${RESET}"
  exit 0
fi

title "MikoCode installer"
subtitle "Guided setup for tmux + nvim + mikocode launcher"

step "Checking platform"

if [[ "$(uname -s)" != "Darwin" ]]; then
  warn "This installer is Mac-only for now."
  exit 1
fi
ok "macOS detected"

step "Checking Homebrew"
if ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew missing. Install it first: https://brew.sh"
  exit 1
fi
ok "Homebrew detected"

BREW_PREFIX="$(brew --prefix)"
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.npm-global/bin:$HOME/.pnpm/bin:${PNPM_HOME:-}:$HOME/.cargo/bin:$HOME/.local/share/mise/shims:$BREW_PREFIX/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

step "Installing Charm gum"
if command -v gum >/dev/null 2>&1; then
  ok "gum already installed"
else
  if brew install gum; then
    ok "gum installed"
  else
    warn "Could not install gum (continuing with standard output)"
  fi
fi

ui_detect_gum

step "Preparing directories"
mkdir -p "$HOME/.local/bin" "$HOME/.config/nvim"
ok "Workspace directories are ready"

step "Installing packages"
if run_with_spinner "Installing core packages" brew install tmux neovim git ripgrep fd fzf eza bat zoxide chafa git-delta lazygit; then
  ok "Core packages installed"
else
  warn "Core package install returned errors (continuing)"
fi

if run_with_spinner "Installing Nerd Fonts" brew install --cask font-meslo-lg-nerd-font font-hack-nerd-font; then
  ok "Nerd fonts installed"
else
  warn "Font install returned errors (continuing)"
fi

step "Cleaning shell aliases"
ALIAS_FOUND=0
for f in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [[ -f "$f" ]] || continue
  if grep -q '^alias cat=' "$f"; then
    ALIAS_FOUND=1
    perl -i.bak -ne 'print unless /^alias cat=/' "$f"
    ok "Removed 'alias cat=' from $f (backup: $f.bak) — it breaks scripts that pipe through cat"
  fi
done
unalias cat 2>/dev/null || true
[[ "$ALIAS_FOUND" == "0" ]] && ok "No conflicting cat aliases found"

step "Ensuring PATH setup"
if ! grep -q 'MikoCode PATH' "$HOME/.zshrc" 2>/dev/null; then
  command cat >> "$HOME/.zshrc" <<'EOFZSH'

# MikoCode PATH
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.npm-global/bin:$HOME/.pnpm/bin:${PNPM_HOME:-}:$HOME/.cargo/bin:$HOME/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:$PATH"
EOFZSH
fi
ok "PATH block verified in ~/.zshrc"

step "Confirming config overwrite"
if [[ -f "$HOME/.tmux.conf" || -f "$HOME/.config/nvim/init.lua" ]]; then
  if ! confirm_continue "Existing tmux/nvim configs found. Continue and create backups?"; then
    warn "Install cancelled by user"
    exit 1
  fi
  ok "User confirmed config updates"
else
  ok "No existing tmux/nvim config files detected"
fi

step "Backing up existing configs"
TS="$(date +%Y%m%d-%H%M%S)"
[[ -f "$HOME/.tmux.conf" ]] && cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak.$TS"
[[ -f "$HOME/.config/nvim/init.lua" ]] && cp "$HOME/.config/nvim/init.lua" "$HOME/.config/nvim/init.lua.bak.$TS"
ok "Backups created where needed"

step "Writing tmux configuration"
command cp "$TMUX_CONF" "$HOME/.tmux.conf"
ok "tmux config written (mouse enabled)"

step "Writing Neovim configuration"
command cp "$NVIM_INIT" "$HOME/.config/nvim/init.lua"
ok "Neovim config written"

step "Installing Neovim plugins"
if run_with_spinner "Syncing Neovim plugins" nvim --headless "+Lazy! sync" +qa; then
  ok "Plugin sync completed"
else
  warn "Plugin sync returned errors (continuing)"
fi

step "Writing mikocode launcher"
command cp "$MIKOCODE_BIN" "$HOME/.local/bin/mikocode"
chmod +x "$HOME/.local/bin/mikocode"
ln -sf "$HOME/.local/bin/mikocode" "$BREW_PREFIX/bin/mikocode" 2>/dev/null || true
mkdir -p "$HOME/.config/mikocode"
printf '%s\n' "$SCRIPT_DIR" > "$HOME/.config/mikocode/repo"
ok "Launcher installed at ~/.local/bin/mikocode (repo recorded for 'mikocode --update')"

step "Applying tmux changes"
tmux set-option -g mouse on 2>/dev/null || true
tmux set-option -g focus-events on 2>/dev/null || true
tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true
ok "tmux updated for current server"

printf "\n%sInstall complete.%s\n" "${GREEN}${BOLD}" "${RESET}"
printf "\nNext steps:\n"
printf "  1) source ~/.zshrc\n"
printf "  2) tmux kill-server\n"
printf "  3) mikocode .\n"
printf "\nDiagnostics:\n"
printf "  mikocode --doctor\n"
printf "\nFont tip: set terminal font to MesloLGS NF or Hack Nerd Font.\n"

if [[ "$HAVE_GUM" == "1" ]]; then
  gum style --bold --foreground 42 "Install complete."
  gum style --faint "Run: source ~/.zshrc && tmux kill-server && mikocode ."
fi