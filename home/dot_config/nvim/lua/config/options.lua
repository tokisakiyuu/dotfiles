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
--
-- Paste uses the local register instead of the builtin osc52.paste: most
-- terminals (iTerm2 default) refuse the OSC52 GET query for security, the
-- query then times out and Neovim disables the whole provider mid-session -
-- which silently breaks copy too. See LazyVim OSC52 recipe.
--
-- We force-reload the provider script because Neovim's autoload caches its
-- "no provider found" decision the first time clipboard is accessed - and
-- something in startup occasionally trips that BEFORE g:clipboard is set,
-- which permanently breaks yanks for the session. unlet + runtime makes
-- the script re-evaluate with our g:clipboard in place.
if os.getenv("SSH_TTY") then
  local function setup_osc52_clipboard()
    local osc52 = require("vim.ui.clipboard.osc52")
    local function paste()
      return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
    end
    vim.g.clipboard = {
      name = "OSC 52",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = paste, ["*"] = paste },
    }
    vim.opt.clipboard = "unnamedplus"
    vim.g.loaded_clipboard_provider = nil
    vim.cmd("runtime autoload/provider/clipboard.vim")
  end
  setup_osc52_clipboard()
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = setup_osc52_clipboard,
  })
end
