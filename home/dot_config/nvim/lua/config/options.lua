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
