#!/usr/bin/env bash
set -euo pipefail

if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
  BOLD="$(tput bold)"
  DIM="$(tput dim)"
  RED="$(tput setaf 1)"
  GREEN="$(tput setaf 2)"
  BLUE="$(tput setaf 4)"
  RESET="$(tput sgr0)"
else
  BOLD=""
  DIM=""
  RED=""
  GREEN=""
  BLUE=""
  RESET=""
fi

TOTAL_STEPS=11
CURRENT_STEP=0
HAVE_GUM=0

if command -v gum >/dev/null 2>&1 && [[ -t 0 ]] && [[ -t 1 ]]; then
  HAVE_GUM=1
fi

title() {
  if [[ "$HAVE_GUM" == "1" ]]; then
    gum style --bold --foreground 212 "$1"
  else
    printf "${BOLD}%s${RESET}\n" "$1"
  fi
}

subtitle() {
  if [[ "$HAVE_GUM" == "1" ]]; then
    gum style --faint "$1"
  else
    printf "${DIM}%s${RESET}\n" "$1"
  fi
}

step() {
  CURRENT_STEP=$((CURRENT_STEP + 1))
  if [[ "$HAVE_GUM" == "1" ]]; then
    gum style --foreground 39 --bold "[$CURRENT_STEP/$TOTAL_STEPS] $1"
  else
    printf "\n${BLUE}${BOLD}[%d/%d]${RESET} %s\n" "$CURRENT_STEP" "$TOTAL_STEPS" "$1"
  fi
}

ok() {
  printf "${GREEN}  -> %s${RESET}\n" "$1"
}

warn() {
  printf "${RED}  -> %s${RESET}\n" "$1"
}

run_with_spinner() {
  local label="$1"
  shift

  if [[ "$HAVE_GUM" == "1" ]]; then
    gum spin --spinner dot --title "$label" -- "$@"
  else
    "$@"
  fi
}

confirm_continue() {
  local prompt="$1"

  if [[ "$HAVE_GUM" == "1" ]]; then
    gum confirm "$prompt"
    return
  fi

  if [[ -t 0 ]]; then
    printf "%s [Y/n] " "$prompt"
    read -r answer
    [[ -z "${answer:-}" || "$answer" =~ ^[Yy]$ ]]
    return
  fi

  return 0
}

trap 'warn "Installer failed at line $LINENO."' ERR

TOTAL_STEPS=13
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

if command -v gum >/dev/null 2>&1 && [[ -t 0 ]] && [[ -t 1 ]]; then
  HAVE_GUM=1
fi

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
for f in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [[ -f "$f" ]] || continue
  perl -i.bak -ne 'print unless /^alias cat=/' "$f"
done
unalias cat 2>/dev/null || true
ok "Removed conflicting cat alias entries"

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
command cat > "$HOME/.tmux.conf" <<'EOFTMUX'
# Keep mouse support always on
set -g mouse on
set -g focus-events on

set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:Tc"
set -g set-clipboard on

unbind C-b
set -g prefix C-a
bind C-a send-prefix

bind r source-file ~/.tmux.conf \; display-message "tmux reloaded"
bind c new-window -c "#{pane_current_path}"
bind x confirm-before -p "Close workspace #W? (y/n)" kill-window
bind-key -n C-t new-window -c "#{pane_current_path}"
set -g renumber-windows on
set -g automatic-rename off

setw -g mode-keys vi
bind-key -T copy-mode-vi v send -X begin-selection
bind-key -T copy-mode-vi y send -X copy-pipe-and-cancel "pbcopy"
bind-key -T copy-mode-vi Enter send -X copy-pipe-and-cancel "pbcopy"
bind-key -T copy-mode-vi MouseDragEnd1Pane send -X copy-pipe-and-cancel "pbcopy"
bind-key -T copy-mode MouseDragEnd1Pane send -X copy-pipe-and-cancel "pbcopy"

bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
unbind '"'
unbind %

bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

set -sg escape-time 10
set -g pane-border-style fg=colour240
set -g pane-active-border-style fg=colour99

set -g status on
set -g status-position bottom
set -g status-style bg=default
set -g window-status-format " #[fg=colour250]#W#{?window_end_flag, #[fg=colour99,bold]+,} "
set -g window-status-current-format " #[bg=colour99,fg=white,bold] #W #[default]#{?window_end_flag,#[fg=colour99,bold]+#[default],} "
set -g status-left "#[fg=colour99,bold] MikoCode #[fg=colour240]│ "
set -g status-right "#[fg=colour245]%H:%M "
EOFTMUX
ok "tmux config written (mouse enabled)"

step "Writing Neovim configuration"
command cat > "$HOME/.config/nvim/init.lua" <<'EOFNVIM'
vim.g.mapleader = " "
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.opt.termguicolors = true
vim.opt.mouse = "a"
vim.opt.mousescroll = "ver:3,hor:6"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.clipboard = "unnamedplus"
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.scrolloff = 6
vim.opt.wrap = false
vim.opt.swapfile = false
vim.opt.undofile = true
vim.opt.fillchars = { eob = " " }

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop

if not uv.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

local function is_git_repo()
  return vim.fn.system("git rev-parse --is-inside-work-tree 2>/dev/null"):match("true")
end

local function set_diff_winbars()
  local wins = vim.api.nvim_tabpage_list_wins(0)
  local diff_wins = {}

  for _, win in ipairs(wins) do
    if vim.api.nvim_win_is_valid(win) and vim.wo[win].diff then
      local pos = vim.api.nvim_win_get_position(win)
      table.insert(diff_wins, { win = win, row = pos[1], col = pos[2] })
    end
  end

  table.sort(diff_wins, function(a, b)
    if a.col == b.col then return a.row < b.row end
    return a.col < b.col
  end)

  for i, item in ipairs(diff_wins) do
    if i == 1 then
      vim.wo[item.win].winbar = "   Code "
    elseif i == 2 then
      vim.wo[item.win].winbar = "   Git "
    else
      vim.wo[item.win].winbar = "   Diff "
    end
  end
end

require("lazy").setup({
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd.colorscheme("tokyonight-night")
    end,
  },

  { "nvim-tree/nvim-web-devicons" },
  { "nvim-lua/plenary.nvim" },
  { "MunifTanjim/nui.nvim" },

  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        view = { side = "left", width = 36 },
        renderer = {
          group_empty = true,
          indent_markers = { enable = true },
          highlight_git = true,
          icons = {
            show = {
              file = true,
              folder = true,
              folder_arrow = true,
              git = true,
            },
          },
        },
        git = { enable = true, ignore = false },
        filters = { dotfiles = false, git_ignored = false },
        update_focused_file = { enable = true, update_root = false },
        actions = {
          open_file = {
            quit_on_open = false,
            window_picker = { enable = false },
          },
        },
      })

      vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<CR>", { desc = "Sidebar" })
      vim.keymap.set("n", "<leader>f", "<cmd>NvimTreeFindFile<CR>", { desc = "Find current file" })

      local function open_first_file_in_cwd()
        local loop = vim.uv or vim.loop
        if not loop then return end

        local cwd = loop.cwd()
        if not cwd or cwd == "" then return end

        local files = vim.fs.find(function(name, path)
          local full = path .. "/" .. name
          return vim.fn.isdirectory(full) == 0
        end, {
          path = cwd,
          type = "file",
          limit = 1,
        })

        if files and files[1] then
          vim.cmd.edit(vim.fn.fnameescape(files[1]))
        end
      end

      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function(data)
          if vim.env.MIKOCODE_START_MODE == "diff" then return end

          local api = require("nvim-tree.api")
          local is_dir = vim.fn.isdirectory(data.file) == 1

          if is_dir then vim.cmd.cd(data.file) end
          api.tree.open()

          if data.file ~= "" and not is_dir then
            api.tree.find_file({ open = true, focus = false })
          else
            vim.schedule(function()
              open_first_file_in_cwd()
              api.tree.find_file({ open = true, focus = false })
            end)
          end
        end,
      })
    end,
  },

  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "tokyonight",
          globalstatus = true,
          section_separators = "",
          component_separators = "",
        },
      })
    end,
  },

  {
    "akinsho/bufferline.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    version = "*",
    config = function()
      require("bufferline").setup({
        options = {
          numbers = function(opts)
            if opts.ordinal == 1 then return "" end
            if opts.ordinal == 2 then return "" end
            return tostring(opts.ordinal)
          end,
          diagnostics = false,
          separator_style = "thin",
          always_show_bufferline = true,
        },
      })
    end,
  },

  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup()
    end,
  },

  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    opts = {},
  },

  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter", "TabEnter", "VimResized" }, {
        callback = function()
          vim.schedule(set_diff_winbars)
        end,
      })

      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          if vim.env.MIKOCODE_START_MODE == "diff" and is_git_repo() then
            vim.schedule(function()
              pcall(vim.cmd, "NvimTreeClose")
              pcall(vim.cmd, "DiffviewOpen")
              vim.schedule(set_diff_winbars)
            end)
          end
        end,
      })
    end,
  },

  {
    "julienvincent/hunk.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    config = function()
      pcall(function()
        require("hunk").setup({})
      end)
    end,
  },

  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local builtin = require("telescope.builtin")
      vim.keymap.set("n", "<leader>p", builtin.find_files, { desc = "Find files" })
      vim.keymap.set("n", "<leader>g", builtin.live_grep, { desc = "Search text" })
    end,
  },
})

local function popup(lines, title, ft)
  if not lines or #lines == 0 then lines = { "No output." } end

  local width = math.floor(vim.o.columns * 0.92)
  local height = math.floor(vim.o.lines * 0.82)
  local row = math.floor((vim.o.lines - height) / 2) - 1
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = ft or "diff"
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(row, 0),
    col = math.max(col, 0),
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
  })

  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end, { buffer = buf, nowait = true })

  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end, { buffer = buf, nowait = true })
end

local function sys(cmd)
  local out = vim.fn.systemlist(cmd)
  return out, vim.v.shell_error
end

local function git_root()
  local out, code = sys("git rev-parse --show-toplevel 2>/dev/null")
  if code ~= 0 or not out[1] or out[1] == "" then return nil end
  return out[1]
end

local function show_diff(extra)
  local root = git_root()

  if not root then
    popup({ "Not inside a git repo.", "", "Run:", "  cd project", "  mikocode ." }, "Git diff", "text")
    return
  end

  extra = extra or ""
  local lines = { "Repo: " .. root, "", "=== STATUS ===" }

  local status = sys("git status --short")
  if #status == 0 then table.insert(lines, "Clean working tree") else vim.list_extend(lines, status) end

  table.insert(lines, "")
  table.insert(lines, "=== UNSTAGED DIFF ===")
  local unstaged = sys("git --no-pager diff --no-ext-diff " .. extra)
  if #unstaged == 0 then table.insert(lines, "No unstaged changes") else vim.list_extend(lines, unstaged) end

  table.insert(lines, "")
  table.insert(lines, "=== STAGED DIFF ===")
  local staged = sys("git --no-pager diff --cached --no-ext-diff " .. extra)
  if #staged == 0 then table.insert(lines, "No staged changes") else vim.list_extend(lines, staged) end

  table.insert(lines, "")
  table.insert(lines, "Press q or Esc to close.")
  popup(lines, "Git diff", "diff")
end

vim.api.nvim_create_user_command("Diff", function(opts)
  local extra = ""
  if opts.fargs and #opts.fargs > 0 then
    local escaped = {}
    for _, f in ipairs(opts.fargs) do table.insert(escaped, vim.fn.shellescape(f)) end
    extra = "-- " .. table.concat(escaped, " ")
  end
  show_diff(extra)
end, { nargs = "*", complete = "file" })

vim.api.nvim_create_user_command("DiffFile", function()
  local file = vim.fn.expand("%:p")
  if file == "" then
    popup({ "No current file." }, "Git diff current file", "text")
    return
  end
  show_diff("-- " .. vim.fn.shellescape(file))
end, {})

vim.api.nvim_create_user_command("Codeview", function()
  if is_git_repo() then
    pcall(vim.cmd, "NvimTreeClose")
    pcall(vim.cmd, "DiffviewOpen")
    vim.schedule(set_diff_winbars)
  else
    print("Not inside a git repo")
  end
end, {})

vim.cmd([[cabbrev <expr> diff getcmdtype() ==# ':' && getcmdline() ==# 'diff' ? 'Diff' : 'diff']])

local image_exts = {
  png = true,
  jpg = true,
  jpeg = true,
  gif = true,
  webp = true,
  bmp = true,
  tiff = true,
  tif = true,
  ico = true,
  avif = true,
  heic = true,
  heif = true,
  svg = true,
}

local function is_image_file(path)
  local ext = vim.fn.fnamemodify(path, ":e")
  if not ext or ext == "" then return false end
  return image_exts[string.lower(ext)] == true
end

local function preview_image(file)
  if file == "" then
    print("No image file")
    return
  end
  if vim.fn.executable("chafa") ~= 1 then
    print("Install chafa for image previews")
    return
  end

  local width = math.floor(vim.o.columns * 0.92)
  local height = math.floor(vim.o.lines * 0.82)
  local row = math.floor((vim.o.lines - height) / 2) - 1
  local col = math.floor((vim.o.columns - width) / 2)
  local buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(row, 0),
    col = math.max(col, 0),
    style = "minimal",
    border = "rounded",
    title = " Image preview ",
    title_pos = "center",
  })

  vim.fn.termopen({ "bash", "-lc", "chafa --symbols=block --colors=full --size=100x40 " .. vim.fn.shellescape(file) })
  vim.cmd.startinsert()
end

vim.api.nvim_create_user_command("Img", function(opts)
  local file = opts.args ~= "" and opts.args or vim.fn.expand("%:p")
  preview_image(file)
end, { nargs = "?", complete = "file" })

vim.api.nvim_create_autocmd("BufEnter", {
  callback = function(args)
    if vim.bo[args.buf].buftype ~= "" then return end

    local file = vim.api.nvim_buf_get_name(args.buf)
    if file == "" or not is_image_file(file) then return end

    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(args.buf) then
        pcall(vim.api.nvim_buf_delete, args.buf, { force = true })
      end
      preview_image(file)
    end)
  end,
})

vim.keymap.set("n", "<leader>d", "<cmd>Diff<CR>", { desc = "Diff popup" })
vim.keymap.set("n", "<leader>D", "<cmd>DiffFile<CR>", { desc = "File diff" })
vim.keymap.set("n", "<leader>v", "<cmd>DiffviewOpen<CR>", { desc = "Diffview" })
vim.keymap.set("n", "<leader>i", "<cmd>Img<CR>", { desc = "Image preview" })
vim.keymap.set("n", "<leader>cv", "<cmd>Codeview<CR>", { desc = "Code/git view" })
EOFNVIM
ok "Neovim config written"

step "Installing Neovim plugins"
if run_with_spinner "Syncing Neovim plugins" nvim --headless "+Lazy! sync" +qa; then
  ok "Plugin sync completed"
else
  warn "Plugin sync returned errors (continuing)"
fi

step "Writing mikocode launcher"
command cat > "$HOME/.local/bin/mikocode" <<'EOFCMD'
#!/usr/bin/env bash
set -euo pipefail

BASE_PATH="$HOME/.local/bin:$HOME/.bun/bin:$HOME/.npm-global/bin:$HOME/.pnpm/bin:${PNPM_HOME:-}:$HOME/.cargo/bin:$HOME/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export PATH="$BASE_PATH"

usage() {
  cat <<'HELP'
Usage:
  mikocode [path]
  mikocode --new [path]
  mikocode --kill [path]
  mikocode --doctor

Env:
  MIKOCODE_AI="opencode"
  MIKOCODE_EDITOR="nvim"
  MIKOCODE_FOCUS="editor"      # editor | shell | ai
  MIKOCODE_START_MODE="normal" # diff | normal
HELP
}

[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && usage && exit 0

if [[ "${1:-}" == "--doctor" ]]; then
  echo "PATH:"
  echo "$PATH"
  echo
  echo "tmux:          $(command -v tmux || true)"
  echo "nvim:          $(command -v nvim || true)"
  echo "opencode bash: $(command -v opencode || true)"
  echo "opencode zsh:  $(zsh -lic 'command -v opencode' 2>/dev/null || true)"
  echo "opencode type:"
  zsh -lic 'type opencode' 2>/dev/null || true
  echo
  echo "bun:           $(command -v bun || true)"
  echo "npm:           $(command -v npm || true)"
  echo "pnpm:          $(command -v pnpm || true)"
  echo "shell:         ${SHELL:-unknown}"
  exit 0
fi

KILL=0
NEW=0
IN_TMUX=0

[[ -n "${TMUX:-}" ]] && IN_TMUX=1

if [[ "${1:-}" == "--kill" ]]; then
  KILL=1
  shift || true
fi

if [[ "${1:-}" == "--new" ]]; then
  NEW=1
  shift || true
fi

TARGET="${1:-.}"

if [[ ! -e "$TARGET" ]]; then
  echo "Path does not exist: $TARGET"
  exit 1
fi

if [[ -d "$TARGET" ]]; then
  DIR="$(cd "$TARGET" && pwd)"
  OPEN_TARGET="."
else
  DIR="$(cd "$(dirname "$TARGET")" && pwd)"
  OPEN_TARGET="$(basename "$TARGET")"
fi

PROJECT="$(basename "$DIR" | tr '[:space:]' '-' | tr -cd '[:alnum:]_.-' | cut -c1-28)"
HASH="$(printf "%s" "$DIR" | cksum | awk '{print $1}')"
SESSION="${MIKOCODE_SESSION:-mikocode-${PROJECT}-${HASH}}"

WINDOW_MODE=0
if [[ "$IN_TMUX" == "1" && "$NEW" != "1" ]]; then
  WINDOW_MODE=1
fi

[[ "$NEW" == "1" ]] && SESSION="${SESSION}-$(date +%H%M%S)"

EDITOR_CMD="${MIKOCODE_EDITOR:-nvim}"
AI_CMD="${MIKOCODE_AI:-opencode}"
FOCUS="${MIKOCODE_FOCUS:-editor}"
START_MODE="${MIKOCODE_START_MODE:-normal}"

[[ "$KILL" == "1" ]] && tmux kill-session -t "$SESSION" 2>/dev/null || true

if [[ "$WINDOW_MODE" != "1" ]] && tmux has-session -t "$SESSION" 2>/dev/null; then
  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$SESSION"
  else
    tmux attach-session -t "$SESSION"
  fi
  exit 0
fi

RUNTIME_DIR="${TMPDIR:-/tmp}/mikocode-${SESSION}"
mkdir -p "$RUNTIME_DIR"

DIR_Q="$(printf '%q' "$DIR")"
OPEN_TARGET_Q="$(printf '%q' "$OPEN_TARGET")"
BASE_PATH_Q="$(printf '%q' "$BASE_PATH")"
START_MODE_Q="$(printf '%q' "$START_MODE")"
AI_CMD_Q="$(printf '%q' "$AI_CMD")"

EDITOR_LAUNCH="$RUNTIME_DIR/editor.sh"
SHELL_LAUNCH="$RUNTIME_DIR/shell.sh"
AI_LAUNCH="$RUNTIME_DIR/ai.sh"

cat > "$EDITOR_LAUNCH" <<LAUNCH_EDITOR
#!/usr/bin/env bash
set -euo pipefail
export PATH=$BASE_PATH_Q
cd $DIR_Q
exec env MIKOCODE_START_MODE=$START_MODE_Q $EDITOR_CMD $OPEN_TARGET_Q
LAUNCH_EDITOR

cat > "$SHELL_LAUNCH" <<LAUNCH_SHELL
#!/usr/bin/env bash
set -euo pipefail
export PATH=$BASE_PATH_Q
cd $DIR_Q
clear
echo 'MikoCode shell'
echo 'Project: $DIR'
echo
echo 'nvim: Space+e sidebar | Space+d diff | Space+cv code/git view'
echo 'tmux: Ctrl-a h/j/k/l panes | Ctrl-a r reload'
echo
exec zsh -l
LAUNCH_SHELL

cat > "$AI_LAUNCH" <<LAUNCH_AI
#!/usr/bin/env bash
set -euo pipefail
export PATH=$BASE_PATH_Q
export MIKOCODE_AI=$AI_CMD_Q
cd $DIR_Q
clear
exec zsh -lic '
export PATH="\$HOME/.local/bin:\$HOME/.bun/bin:\$HOME/.npm-global/bin:\$HOME/.pnpm/bin:\${PNPM_HOME:-}:\$HOME/.cargo/bin:\$HOME/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\$PATH"

cmd="\${MIKOCODE_AI:-opencode}"
bin="\${cmd%% *}"

echo "MikoCode AI pane"
echo "Project: \$PWD"
echo "Command: \$cmd"
echo "Resolved: \$(command -v "\$bin" 2>/dev/null || true)"
echo

if command -v "\$bin" >/dev/null 2>&1 || [[ -x "\$bin" ]]; then
  eval "\$cmd"
  code=\$?
  echo
  echo "AI command exited: \$code"
else
  echo "opencode was not found from login zsh."
  echo
  echo "Debug:"
  echo "  mikocode --doctor"
  echo "  zsh -lic '\''command -v opencode; type opencode'\''"
  echo
  echo "You can also run:"
  echo "  MIKOCODE_AI=\"/full/path/to/opencode\" mikocode ."
fi

echo
exec zsh -l
'
LAUNCH_AI

chmod +x "$EDITOR_LAUNCH" "$SHELL_LAUNCH" "$AI_LAUNCH"

if [[ "$WINDOW_MODE" == "1" ]]; then
  TARGET_WINDOW="$(tmux display-message -p '#{session_name}:#{window_index}')"
  LEFT="$(tmux display-message -p '#{pane_id}')"

  while IFS= read -r pane; do
    [[ "$pane" == "$LEFT" ]] && continue
    tmux kill-pane -t "$pane"
  done < <(tmux list-panes -t "$TARGET_WINDOW" -F '#{pane_id}')

  tmux rename-window -t "$TARGET_WINDOW" "$PROJECT"
  tmux send-keys -t "$LEFT" C-c
  tmux send-keys -t "$LEFT" "clear" C-m

  RIGHT="$(tmux split-window -h -p 30 -P -F "#{pane_id}" -t "$LEFT" -c "$DIR")"
  BOTTOM="$(tmux split-window -v -p 25 -P -F "#{pane_id}" -t "$LEFT" -c "$DIR")"
else
  tmux new-session -d -s "$SESSION" -n "$PROJECT" -c "$DIR"

  LEFT="$(tmux list-panes -t "$SESSION:$PROJECT" -F '#{pane_id}' | head -n1)"
  RIGHT="$(tmux split-window -h -p 30 -P -F "#{pane_id}" -t "$LEFT" -c "$DIR")"
  BOTTOM="$(tmux split-window -v -p 25 -P -F "#{pane_id}" -t "$LEFT" -c "$DIR")"
fi

tmux select-pane -t "$LEFT" -T "editor"
tmux select-pane -t "$BOTTOM" -T "shell"
tmux select-pane -t "$RIGHT" -T "ai"

tmux send-keys -t "$LEFT" "bash $(printf '%q' "$EDITOR_LAUNCH")" C-m
tmux send-keys -t "$BOTTOM" "bash $(printf '%q' "$SHELL_LAUNCH")" C-m
tmux send-keys -t "$RIGHT" "bash $(printf '%q' "$AI_LAUNCH")" C-m

case "$FOCUS" in
  shell) tmux select-pane -t "$BOTTOM" ;;
  ai) tmux select-pane -t "$RIGHT" ;;
  *) tmux select-pane -t "$LEFT" ;;
esac

if [[ "$WINDOW_MODE" != "1" ]]; then
  tmux select-window -t "$SESSION:$PROJECT"
fi

if [[ "$WINDOW_MODE" != "1" ]]; then
  if [[ -n "${TMUX:-}" ]]; then
    tmux switch-client -t "$SESSION"
  else
    tmux attach-session -t "$SESSION"
  fi
fi
EOFCMD

chmod +x "$HOME/.local/bin/mikocode"
ln -sf "$HOME/.local/bin/mikocode" "$BREW_PREFIX/bin/mikocode" 2>/dev/null || true
ok "Launcher installed at ~/.local/bin/mikocode"

step "Applying tmux changes"
tmux set-option -g mouse on 2>/dev/null || true
tmux set-option -g focus-events on 2>/dev/null || true
tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true
ok "tmux updated for current server"

printf "\n${GREEN}${BOLD}Install complete.${RESET}\n"
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
