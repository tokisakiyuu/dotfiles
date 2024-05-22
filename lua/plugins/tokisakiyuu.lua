return {
  -- *.lalrpop syntax highlight
  { "qnighy/lalrpop.vim" },

  -- https://github.com/folke/noice.nvim
  {
    "folke/noice.nvim",
    opts = {
      lsp = {
        hover = {
          -- Set not show a message if hover is not available
          -- ex: shift+k on Typescript code
          silent = true,
        },
      },
    },
  },

  {
    "nvim-lspconfig",
    opts = {
      inlay_hints = { enabled = false },
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
    },
  },

  {
    "folke/zen-mode.nvim",
    opts = {
      window = {
        options = {
          number = false,
          relativenumber = false,
        },
      },
    },
  },

  {
    "akinsho/bufferline.nvim",
    keys = {
      { "<leader>b[", "<cmd>BufferLineMovePrev<CR>", desc = "Exchange with Prev Buffer" },
      { "<leader>b]", "<cmd>BufferLineMoveNext<CR>", desc = "Exchange with Next Buffer" },
      { "gb", "<cmd>BufferLinePick<CR>", desc = "Pick Buffer" },
    },
    opts = {
      options = {
        show_buffer_close_icons = false,
        -- always_show_bufferline = true,
        separator_style = { "", "" },
        indicator = { style = "none" },
      },
      highlights = {
        tab_selected = {
          bg = "#001595",
        },
        tab_separator_selected = {
          bg = "#001595",
        },
        close_button_selected = {
          bg = "#001595",
        },
        buffer_selected = {
          bg = "#001595",
          bold = true,
          italic = false,
        },
        numbers_selected = {
          bg = "#001595",
          bold = true,
          italic = false,
        },
        diagnostic_selected = {
          bg = "#001595",
          bold = true,
          italic = false,
        },
        hint_selected = {
          bg = "#001595",
          bold = true,
          italic = false,
        },
        hint_diagnostic_selected = {
          bg = "#001595",
        },
        info_selected = {
          bg = "#001595",
          bold = true,
          italic = false,
        },
        info_diagnostic_selected = {
          bg = "#001595",
        },
        warning_selected = {
          bg = "#001595",
          bold = true,
          italic = false,
        },
        warning_diagnostic_selected = {
          bg = "#001595",
        },
        error_selected = {
          bg = "#001595",
          bold = true,
          italic = false,
        },
        error_diagnostic_selected = {
          bg = "#001595",
        },
        modified_selected = {
          bg = "#001595",
          bold = true,
          italic = false,
        },
        duplicate_selected = {
          bg = "#001595",
          bold = true,
          italic = false,
        },
        separator_selected = {
          bg = "#001595",
          bold = true,
          italic = false,
        },
        indicator_selected = {
          bg = "#001595",
          bold = true,
          italic = false,
        },
        pick_selected = {
          bg = "#001595",
          bold = true,
          italic = false,
        },
      },
    },
  },
}
