local sections = {
  lualine_a = {},
  lualine_b = { "mode" },
  lualine_c = {
    {
      "filename",
      path = 1,
    },
  },
  lualine_x = {
    -- stylua: ignore
    {
      function() return require("noice").api.status.mode.get() end,
      cond = function() return package.loaded["noice"] and require("noice").api.status.mode.has() end,
      color = function() return { fg = Snacks.util.color("Constant") } end,
    },
    {
      "branch",
      fmt = function(str)
        local b = vim.fn.system({ "sed", "-E", "s/^(DEV-[0-9]+(-[0-9]+)?)-.*/\\1/I" }, str)
        return string.upper(b)
      end,
    },
  },
  lualine_y = {},
  lualine_z = {},
}

-- default opts -> https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/plugins/ui.lua#L119
return {
  {
    "nvim-lualine/lualine.nvim",
    opts = {
      options = {
        section_separators = { left = "", right = "" },
        component_separators = { left = "", right = "" },
      },
      -- available components -> https://github.com/nvim-lualine/lualine.nvim?tab=readme-ov-file#available-components
      sections = sections,
    },
  },
}
