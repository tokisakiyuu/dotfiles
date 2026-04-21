return {
  {
    "stevearc/oil.nvim",
    keys = {
      {
        "<leader>e",
        "<CMD>Oil<CR>",
        desc = "Open oil explorer",
      },
    },
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {
      view_options = {
        show_hidden = true,
        is_always_hidden = function(name)
          return name:match("^%.%.") ~= nil
        end,
      },
      use_default_keymaps = false,
      keymaps = {
        ["g?"] = { "actions.show_help", mode = "n" },
        ["<C-p>"] = "actions.preview",
        ["<C-l"] = "actions.refresh",
        ["q"] = { "actions.close", mode = "n" },
        ["@"] = { "actions.open_cwd", mode = "n" },
        ["gs"] = { "actions.change_sort", mode = "n" },
        ["gx"] = "actions.open_external",
        ["g."] = { "actions.toggle_hidden", mode = "n" },
        ["gy"] = {
          desc = "Copy absolute path",
          callback = function()
            local oil = require("oil")
            local entry = oil.get_cursor_entry()
            if entry then
              local dir = oil.get_current_dir()
              local path = dir .. entry.name
              vim.fn.setreg("+", path)
              vim.notify("Copied: " .. path)
            end
          end,
        },
        ["<S-h>"] = { "actions.parent", mode = "n" },
        ["<S-l>"] = {
          desc = "Navigate into directory",
          mode = "n",
          callback = function()
            local oil = require("oil")
            local entry = oil.get_cursor_entry()
            if entry == nil then
              return
            end
            if entry.type == "directory" then
              oil.select()
            end
          end,
        },
        ["<CR>"] = {
          desc = "Open file",
          mode = "n",
          callback = function()
            local oil = require("oil")
            local entry = oil.get_cursor_entry()
            if entry == nil then
              return
            end
            if entry.type == "file" then
              oil.select()
            end
          end,
        },
      },
    },
    -- Optional dependencies
    dependencies = { { "nvim-mini/mini.icons", opts = {} } },
    -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
  },

  {
    "nvim-neo-tree/neo-tree.nvim",
    enabled = false,
  },
}
