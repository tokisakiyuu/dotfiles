local common_sections = {
  lualine_a = {
    {
      "filename",
      path = 4,
    },
  },
  lualine_b = { "branch" },
  lualine_c = {},
  lualine_x = {
    "diagnostics",
    -- stylua: ignore
    {
      function() return require("noice").api.status.command.get() end,
      cond = function() return package.loaded["noice"] and require("noice").api.status.command.has() end,
      color = function() return { fg = Snacks.util.color("Statement") } end,
    },
    -- stylua: ignore
    {
      function() return require("noice").api.status.mode.get() end,
      cond = function() return package.loaded["noice"] and require("noice").api.status.mode.has() end,
      color = function() return { fg = Snacks.util.color("Constant") } end,
    },
    {
      "filetype",
      icon_only = true,
      padding = { right = 0 },
    },
    "encoding",
  },
  lualine_y = {},
  lualine_z = {
    { "progress", separator = " ", padding = { left = 0, right = 0 } },
    { "location", padding = { left = 0, right = 0 } },
    "mode",
  },
}

local insert_mode_sections = {
  lualine_a = {},
  lualine_b = {},
  lualine_c = {
    {
      "filename",
      path = 1,
    },
  },
  lualine_x = { "mode" },
  lualine_y = {},
  lualine_z = {},
}

local lualine = require("lualine")

vim.api.nvim_create_autocmd("ModeChanged", {
  pattern = "*",
  callback = function()
    local new_mode = vim.v.event.new_mode
    if new_mode == "i" then
      local current_config = lualine.get_config()
      current_config.sections = insert_mode_sections
      require("lualine").setup(current_config)
    else
      local current_config = lualine.get_config()
      current_config.sections = common_sections
      require("lualine").setup(current_config)
    end
  end,
})

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
      sections = common_sections,
    },
  },
}
