-- rust dev only happens on the Mac, so rust_analyzer is the one server gated
-- behind Darwin. Everything else installs via Mason on every platform — the
-- Arch Linux ARM host is glibc, so Mason's prebuilt arm64 binaries work.
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
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, mason_servers)
    end,
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
