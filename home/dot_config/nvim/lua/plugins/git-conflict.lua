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
    keys = {
      { "[x", "<cmd>GitConflictPrevConflict<cr>", desc = "Move to the previous conflict", mode = "n" },
      { "]x", "<cmd>GitConflictNextConflict<cr>", desc = "Move to the next conflict", mode = "n" },
    },
    opts = {
      default_mappings = false,
      list_opener = "",
      disable_diagnostics = true,
      config = true,
    },
  },
}
