return {
  -- https://github.com/LazyVim/LazyVim/discussions/830#discussioncomment-7757328
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
      codelens = { enabled = false },
    },
  },
}
