return {
  {
    "snacks.nvim",
    opts = {
      dashboard = {
        -- https://github.com/folke/snacks.nvim/blob/main/docs/dashboard.md#advanced
        sections = {
          { section = "header" },
          {
            icon = " ",
            title = "Git Status",
            section = "terminal",
            enabled = function()
              return Snacks.git.get_root() ~= nil
            end,
            cmd = "git status --short --branch --renames",
            height = 5,
            padding = 1,
            ttl = 5 * 60,
            indent = 3,
          },
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
        },

        preset = {
          -- https://github.com/folke/snacks.nvim/blob/main/docs/dashboard.md#%EF%B8%8F-config
          keys = {
            { icon = " ", key = "s", desc = "Restore Session", section = "session" },
            { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
            {
              icon = "󰒲 ",
              key = "e",
              desc = "Lazy Extras",
              action = ":LazyExtras",
              enabled = package.loaded.lazy ~= nil,
            },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },

          -- https://github.com/MaximilianLloyd/ascii.nvim
          header = table.concat({
            [[                                                                       ]],
            [[                                                                     ]],
            [[       ████ ██████           █████      ██                     ]],
            [[      ███████████             █████                             ]],
            [[      █████████ ███████████████████ ███   ███████████   ]],
            [[     █████████  ███    █████████████ █████ ██████████████   ]],
            [[    █████████ ██████████ █████████ █████ █████ ████ █████   ]],
            [[  ███████████ ███    ███ █████████ █████ █████ ████ █████  ]],
            [[ ██████  █████████████████████ ████ █████ █████ ████ ██████ ]],
            [[                                                                       ]],
          }, "\n"),
        },
      },
    },
  },
}
