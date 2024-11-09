return {
  -- -- https://github.com/folke/noice.nvim
  -- {
  --   "folke/noice.nvim",
  --   opts = {
  --     lsp = {
  --       hover = {
  --         -- Set not show a message if hover is not available
  --         -- ex: shift+k on Typescript code
  --         silent = true,
  --       },
  --     },
  --   },
  -- },

  {
    "folke/tokyonight.nvim",
    opts = {
      transparent = true,
      styles = {
        -- sidebars = "transparent",
        -- floats = "transparent",
      },
      on_highlights = function(hl)
        hl.DiagnosticUnnecessary = {
          fg = "#636da6",
        }
      end,
    },
  },

  {
    "folke/trouble.nvim",
    opts = {
      focus = true,
    },
  },

  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      styles = {
        lazygit = {
          border = "rounded",
        },
      },
    },
  },
}
