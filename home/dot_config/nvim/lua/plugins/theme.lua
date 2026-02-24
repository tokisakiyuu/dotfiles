vim.opt.pumblend = 0
vim.opt.winblend = 0

return {
  {
    "mason-org/mason.nvim",
    opts = {
      ui = {
        border = "rounded",
      },
    },
  },
  {
    "folke/noice.nvim",
    opts = {
      presets = {
        lsp_doc_border = true,
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      diagnostics = {
        float = {
          border = "rounded",
        },
      },
    },
  },
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
      on_colors = function(colors)
        colors.border = "#636da6"
      end,
    },
  },
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      bigfile = {
        enabled = true,
      },
      styles = {
        lazygit = {
          border = "rounded",
        },
      },
      notifier = {
        style = "fancy",
      },
    },
  },
}
