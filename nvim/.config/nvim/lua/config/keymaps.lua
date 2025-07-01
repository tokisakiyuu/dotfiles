-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

map("v", "<leader>cp", "yoconsole.log('<Esc>pa', <Esc>pa)<Esc>", { desc = "Print javascript variable" })
