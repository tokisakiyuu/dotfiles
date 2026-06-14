-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

local opt = vim.opt

-- Dsiable snacks.nvim scrolling animation
vim.g.snacks_animate = false

-- Always take cwd as working directory
vim.g.root_spec = { "cwd" }

-- Ctrl+i/o behavior
opt.jumpoptions = "stack"

-- Set terminal window title
vim.o.title = true
vim.o.titlestring = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")

-- Over SSH, route the system clipboard through OSC52 so yanks reach the local
-- terminal's clipboard (tmux must have set-clipboard=on to pass it through).
-- LazyVim deliberately blanks `clipboard` under SSH (assumes no provider) -
-- we force it back to `unnamedplus` because the OSC52 provider below fills
-- that gap.
if os.getenv("SSH_TTY") then
  local osc52 = require("vim.ui.clipboard.osc52")
  vim.g.clipboard = {
    name = "OSC 52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
  }
  opt.clipboard = "unnamedplus"
end
