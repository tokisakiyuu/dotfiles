-- 👆 This bar

return {
  {
    "akinsho/bufferline.nvim",
    lazy = true,
    keys = {
      { "<leader>b[", "<cmd>BufferLineMovePrev<CR>", desc = "Exchange with Prev Buffer" },
      { "<leader>b]", "<cmd>BufferLineMoveNext<CR>", desc = "Exchange with Next Buffer" },
      { "gb", "<cmd>BufferLinePick<CR>", desc = "Pick Buffer" },
    },
    opts = {
      options = {
        show_buffer_close_icons = false,
        separator_style = { "", "" },
        indicator = { style = "none" },
        persist_buffer_sort = false,
        sort_by = "insert_after_current",
      },
    },
  },
}
