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
