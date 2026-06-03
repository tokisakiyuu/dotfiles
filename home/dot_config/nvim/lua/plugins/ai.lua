return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    keys = {
      { "<leader>a", nil, desc = "AI/Claude Code" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
    },
    config = true,
    opts = {
      auto_start = true,
      terminal = {
        provider = "none",
      },
    },
  },
}
