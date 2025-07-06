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
      ensure_installed = {
        "vtsls", -- typescript lsp
        "tailwindcss",
        "rust_analyzer", -- rsut lsp
        "eslint",
        "graphql",
        "jsonls", -- json files lsp
      },
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
          },
          colorDecorators = false,
        },
      },
    },
  },
}
