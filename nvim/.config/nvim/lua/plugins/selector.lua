local fullscreen_win_opts = {
  fullscreen = true,
  preview = {
    layout = "vertical",
    vertical = "down:60%",
  },
}

-- http://www.lazyvim.org/extras/editor/fzf#fzf-lua
-- https://github.com/ibhagwan/fzf-lua/tree/main?tab=readme-ov-file#customization
return {
  {
    "ibhagwan/fzf-lua",
    opts = {
      files = {
        winopts = fullscreen_win_opts,
      },
      grep = {
        winopts = fullscreen_win_opts,
      },
    },
  },
}
