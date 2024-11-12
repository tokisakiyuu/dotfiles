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
        position = "right",
        mappings = {
          ["P"] = { "toggle_preview", config = { use_float = true, use_image_nvim = true } },
        },
      },
      buffers = {
        show_unloaded = true,
      },
      filesystem = {
        filtered_items = {
          hide_dotfiles = false,
          hide_by_name = {
            ".git",
            ".DS_Store",
          },
          always_show = {
            ".env",
          },
        },
      },
      default_component_configs = {
        container = {
          right_padding = 2,
        },
      },
    },
  },
}
