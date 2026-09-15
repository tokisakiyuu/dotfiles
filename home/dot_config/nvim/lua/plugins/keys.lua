return {
  {
    "folke/snacks.nvim",
    keys = {
      {
        "<leader>fh",
        function()
          Snacks.picker.help()
        end,
        desc = "Find in help",
        mode = "n",
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>y", group = "yank/copy", mode = { "n", "x" } },
      },
    },
  },
}
