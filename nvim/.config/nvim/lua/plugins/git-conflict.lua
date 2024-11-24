vim.api.nvim_create_autocmd("User", {
  pattern = "GitConflictDetected",
  callback = function()
    -- vim.notify("Conflict detected")
    vim.cmd("GitConflictListQf")
  end,
})

vim.api.nvim_create_autocmd("User", {
  pattern = "GitConflictResolved",
  callback = function()
    vim.notify("Conflict resolved 🎉")
  end,
})

return {
  {
    "akinsho/git-conflict.nvim",
    version = "*",
    opts = function()
      local map = LazyVim.safe_keymap_set
      map("n", "[x", "<cmd>GitConflictPrevConflict<cr>", { desc = "Move to the previous conflict" })
      map("n", "]x", "<cmd>GitConflictNextConflict<cr>", { desc = "Move to the next conflict" })

      return {
        default_mappings = false,
        list_opener = "",
        disable_diagnostics = true,
        config = true,
      }
    end,
  },
}
