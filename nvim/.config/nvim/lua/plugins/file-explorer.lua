local function contains(arr, str)
  for _, v in ipairs(arr) do
    if v == str then
      return true
    end
  end
  return false
end

local function toggle_view(dir)
  local oil = require("oil")
  local util = require("oil.util")
  local buf = vim.api.nvim_get_current_buf()
  if util.is_oil_bufnr(buf) then
    oil.close()
  else
    oil.open(dir)
  end
end

local function open_in_current_dir()
  return toggle_view()
end

return {
  {
    "echasnovski/mini.files",
    version = "*",
    keys = {
      {
        "<leader>e",
        function()
          local fs = require("mini.files")
          fs.open(vim.api.nvim_buf_get_name(0), false)
          fs.reveal_cwd()
        end,
        desc = "Open mini explorer",
      },
    },
    config = function()
      require("mini.files").setup({
        mappings = {
          go_in_plus = "<Enter>",
          go_out_plus = "",
          synchronize = "<C-s>",
        },
      })
    end,
  },

  {
    "stevearc/oil.nvim",
    keys = {
      {
        "<leader>E",
        open_in_current_dir,
        desc = "Open oil explorer",
      },
    },
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {
      view_options = {
        show_hidden = true,
        is_always_hidden = function(name)
          return contains({ ".DS_Store", ".git", ".." }, name)
        end,
      },
      use_default_keymaps = false,
      keymaps = {
        ["g?"] = { "actions.show_help", mode = "n" },
        ["<CR>"] = "actions.select",
        ["<C-p>"] = "actions.preview",
        ["q"] = { "actions.close", mode = "n" },
        ["_"] = { "actions.open_cwd", mode = "n" },
        ["gs"] = { "actions.change_sort", mode = "n" },
        ["gx"] = "actions.open_external",
        ["g."] = { "actions.toggle_hidden", mode = "n" },
        ["-"] = {
          desc = "Goto parent dir",
          mode = "n",
          callback = function()
            local oil = require("oil")
            local path = require("oil.pathutil")
            local buf = vim.api.nvim_get_current_buf()
            local dir = oil.get_current_dir(buf)
            local cwd = vim.fn.getcwd() .. "/"
            if dir ~= nil and cwd ~= dir then
              oil.open(path.parent(dir))
            end
          end,
        },
      },
    },
    -- Optional dependencies
    dependencies = { { "echasnovski/mini.icons", opts = {} } },
    -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
  },

  {
    "nvim-neo-tree/neo-tree.nvim",
    enabled = false,
  },
}
