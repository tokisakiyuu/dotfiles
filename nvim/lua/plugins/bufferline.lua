-- keep it 👆 in main theme

return {
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
        always_show_bufferline = true,
        separator_style = { "", "" },
        indicator = { style = "none" },
        persist_buffer_sort = false,
        sort_by = "insert_after_current",
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
