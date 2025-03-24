vim.api.nvim_create_autocmd("User", {
  pattern = "LazyLoad",
  callback = function(event)
    if event.data == "blink.cmp" then
      vim.api.nvim_set_hl(0, "BlinkCmpMenu", {
        bg = "#1B0C53",
      })
      vim.api.nvim_set_hl(0, "BlinkCmpMenuSelection", {
        bg = "#3619AA",
      })
    end
  end,
})

-- https://cmp.saghen.dev/configuration/general.html
return {
  {
    "saghen/blink.cmp",
    ---@module 'blink.cmp'
    ---@type blink.cmp.Config
    opts = {
      completion = {
        list = {
          selection = {
            auto_insert = false,
          },
        },
      },
      keymap = {
        preset = "default", -- no be accepted if press enter
      },
    },
  },
}

-- Default keymaps:
--
--   ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
--   ['<C-e>'] = { 'hide' },
--   ['<C-y>'] = { 'select_and_accept' },
--
--   ['<C-p>'] = { 'select_prev', 'fallback' },
--   ['<C-n>'] = { 'select_next', 'fallback' },
--
--   ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
--   ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },
--
--   ['<Tab>'] = { 'snippet_forward', 'fallback' },
--   ['<S-Tab>'] = { 'snippet_backward', 'fallback' },
