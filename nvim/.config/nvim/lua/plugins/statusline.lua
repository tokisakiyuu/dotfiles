local function get_short_branch_name()
  local branch_name = vim.fn.systemlist("git rev-parse --abbrev-ref HEAD")[1]
  if branch_name then
    branch_name = string.sub(branch_name, 1, 16) -- 截取前 16 个字符
    return branch_name
  else
    return nil
  end
end

local branch = get_short_branch_name()
local branch_icon = "" -- e0a0

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
    function()
      return branch_icon .. " " .. branch
    end,
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
