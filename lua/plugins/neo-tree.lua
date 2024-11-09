return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    keys = {
      {
        "<leader>bb",
        "<cmd>Neotree source=buffers reveal=true position=bottom<CR> ",
        desc = "NeoTree Buffers",
      },
    },
    opts = {
      window = {
        position = "current",
        mappings = {
          ["P"] = { "toggle_preview", config = { use_float = true, use_image_nvim = true } },
        },
      },
      buffers = {
        show_unloaded = true,
      },
    },
  },
}
