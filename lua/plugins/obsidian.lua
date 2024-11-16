local HOME = vim.fn.expand("~")

return {
  {
    "epwalsh/obsidian.nvim",
    version = false,
    lazy = true,
    ft = "markdown",
    keys = {
      { "<leader>oo", "<cmd>ObsidianOpen<cr>", desc = "Open Obsidian" },
      { "<leader>on", "<cmd>ObsidianNew<cr>", desc = "Create a new Obsidian Document" },
      { "<leader>os", "<cmd>ObsidianSearch<cr>", desc = "Search Obsidian" },
      { "<leader>of", "<cmd>ObsidianQuickSwitch<cr>", desc = "Obsidian Find Files" },
      -- Required to brew install pngpaste
      { "<leader>op", "<cmd>ObsidianPasteImg<cr>", desc = "Obsidian Paste Image" },
      { "<leader>or", "<cmd>ObsidianRename<cr>", desc = "Obsidian Rename current note" },
      { "<leader>ot", "<cmd>ObsidianTemplate<cr>", desc = "Insert Obsidian Template into file" },
    },
    event = {
      "BufReadPre " .. HOME .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/tokisakiyuu/*.md",
      "BufNewFile " .. HOME .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/tokisakiyuu/*.md",
    },
    dependencies = {
      -- Required.
      "nvim-lua/plenary.nvim",
    },
    opts = {
      workspaces = {
        {
          name = "tokisakiyuu",
          path = HOME .. "/Library/Mobile Documents/iCloud~md~obsidian/Documents/tokisakiyuu",
        },
      },

      follow_img_func = function(img)
        vim.fn.jobstart({ "qlmanage", "-p", img }) -- Mac OS quick look preview
        -- vim.fn.jobstart({"xdg-open", url})  -- linux
        -- vim.cmd(':silent exec "!start ' .. url .. '"') -- Windows
      end,

      ---@param url string
      follow_url_func = function(url)
        -- Open the URL in the default web browser.
        vim.fn.jobstart({ "open", url }) -- Mac OS
        -- vim.fn.jobstart({"xdg-open", url})  -- linux
        -- vim.cmd(':silent exec "!start ' .. url .. '"') -- Windows
        -- vim.ui.open(url) -- need Neovim 0.10.0+
      end,

      attachments = {
        img_folder = "assets",
        ---@return string
        img_name_func = function()
          -- Prefix image names with timestamp.
          return string.format("%s-", os.time())
        end,

        ---@return string
        img_text_func = function(client, path)
          path = client:vault_relative_path(path) or path
          return string.format("![%s](%s)", path.name, path)
        end,
      },
    },
  },

  {
    "3rd/image.nvim",
    opts = {
      backend = "kitty",
      -- Required to brew install imagemagick
      processor = "magick_cli",
    },
  },
}
