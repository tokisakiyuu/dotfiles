local function contains(arr, str)
  for i, v in ipairs(arr) do
    if v == str then
      return true
    end
  end
  return false
end

return {
  {
    "stevearc/oil.nvim",
    keys = {
      {
        "<leader>e",
        function()
          require("oil").open()
        end,
        desc = "Open oil browser (current dir)",
      },
      {
        "<leader>E",
        function()
          require("oil").open(vim.fn.getcwd())
        end,
        desc = "Open oil browser (workdir)",
      },
    },
    ---@module 'oil'
    ---@type oil.SetupOpts
    opts = {
      view_options = {
        show_hidden = true,
        is_always_hidden = function(name)
          return contains({ ".DS_Store", ".git" }, name)
        end,
      },
      use_default_keymaps = false,
      keymaps = {
        ["g?"] = { "actions.show_help", mode = "n" },
        ["<CR>"] = "actions.select",
        ["<C-p>"] = "actions.preview",
        ["q"] = { "actions.close", mode = "n" },
        ["-"] = { "actions.parent", mode = "n" },
        ["_"] = { "actions.open_cwd", mode = "n" },
        ["<S-s>"] = { "actions.change_sort", mode = "n" },
        ["gx"] = "actions.open_external",
        ["g."] = { "actions.toggle_hidden", mode = "n" },
      },
    },
    -- Optional dependencies
    dependencies = { { "echasnovski/mini.icons", opts = {} } },
    -- dependencies = { "nvim-tree/nvim-web-devicons" }, -- use if prefer nvim-web-devicons
  },

  {
    "nvim-neo-tree/neo-tree.nvim",
    enabled = false,
    --   opts = {
    --     window = {
    --       position = "left",
    --       mappings = {
    --         ["P"] = { "toggle_preview", config = { use_float = true, use_image_nvim = true } },
    --       },
    --     },
    --     buffers = {
    --       show_unloaded = true,
    --     },
    --     filesystem = {
    --       filtered_items = {
    --         hide_dotfiles = false,
    --         hide_by_name = {
    --           ".git",
    --           ".DS_Store",
    --         },
    --         always_show = {
    --           ".env",
    --         },
    --       },
    --     },
    --     default_component_configs = {
    --       container = {
    --         right_padding = 2,
    --       },
    --     },
    --   },
  },
}
