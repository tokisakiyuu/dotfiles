-- Mason ships rust_analyzer as a glibc-linked release binary that won't run
-- on musl-based pmOS. Gate it on Darwin so Mason only tries to install it
-- where it actually works. To use rust_analyzer on Linux instead, install
-- the distro package (e.g. `apk add rust-analyzer`) and remove it here.
local is_darwin = vim.uv.os_uname().sysname == "Darwin"

local mason_servers = {
  "vtsls",
  "tailwindcss",
  "eslint",
  "graphql",
  "jsonls",
  "prismals",
}
if is_darwin then
  table.insert(mason_servers, "rust_analyzer")
end

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
      servers = {
        -- Custom Server Options
        -- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
        eslint = {
          filetypes = {
            "graphql",
            "javascript",
            "javascriptreact",
            "javascript.jsx",
            "typescript",
            "typescriptreact",
            "typescript.tsx",
            "vue",
            "svelte",
            "astro",
            "htmlangular",
          },
        },
      },
    },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "typescript",
        "javascript",
        "json",
        "rust",
        "tsx",
        "graphql",
        "prisma",
        "toml",
        "html",
        "jsdoc",
        "lua",
      },
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    opts = {
      ensure_installed = mason_servers,
    },
  },

  -- Tailwind CSS Tools (Hover Documentaion, LSP Configuration)
  {
    "luckasRanarison/tailwind-tools.nvim",
    name = "tailwind-tools",
    build = ":UpdateRemotePlugins",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "neovim/nvim-lspconfig", -- optional
    },
    opts = {
      server = {
        -- https://github.com/tailwindlabs/tailwindcss-intellisense?tab=readme-ov-file#extension-settings
        settings = {
          classFunctions = {
            "tw",
            "clsx",
            "cn",
          },
          colorDecorators = false,
        },
      },
    },
  },

  {
    "hedyhli/outline.nvim",
    cmd = { "Outline", "OutlineOpen" },
    keys = {
      { "<leader>cs", "<cmd>Outline<CR>", desc = "Toggle outline" },
    },
    opts = {
      outline_window = {
        position = "left",
      },
    },
  },

  {
    "folke/trouble.nvim",
    keys = {
      { "<leader>cs", false },
    },
  },
}
