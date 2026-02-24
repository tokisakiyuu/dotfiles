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
}
