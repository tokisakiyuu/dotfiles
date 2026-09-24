-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
-- Add any additional autocmds here

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.js", "*.ts", "*.jsx", "*.tsx" },
  callback = function()
    vim.keymap.set(
      "n",
      "<leader>cp",
      "yiwoconsole.log('<Esc>pa', <Esc>pa)<Esc>",
      { desc = "Print javascript variable", buffer = true }
    )
  end,
})

-- LazyVim's `wrap_spell` autocmd turns on both wrap and spell for text
-- filetypes. Reclaim its augroup so the wrap half stays and spell is dropped.
-- https://www.lazyvim.org/configuration/general
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("lazyvim_wrap_spell", { clear = true }),
  pattern = { "text", "plaintex", "typst", "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
  end,
})
