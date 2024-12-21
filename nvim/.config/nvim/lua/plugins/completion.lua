-- https://color.adobe.com/create/color-wheel
vim.api.nvim_set_hl(0, "MyCmpMeum", {
  bg = "#1B0C53",
})

vim.api.nvim_set_hl(0, "MyCmpMenuSelection", {
  bg = "#3619AA",
})

-- https://cmp.saghen.dev/configuration/general.html
return {
  {
    "Saghen/blink.cmp",
    opts = {
      completion = {
        menu = {
          winhighlight = "Normal:MyCmpMeum,CursorLine:MyCmpMenuSelection,FloatBorder:BlinkCmpMenuBorder,Search:None",
        },
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
