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
