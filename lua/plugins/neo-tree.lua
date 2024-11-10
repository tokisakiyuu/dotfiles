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
        mappings = {
          ["P"] = { "toggle_preview", config = { use_float = true, use_image_nvim = true } },
        },
      },
      buffers = {
        show_unloaded = true,
      },
      default_component_configs = {
        container = {
          right_padding = 2,
        },
      },
    },
  },
}
