local toggle_key = [[<C-\>]]

local function goto_file_under_cursor(self)
  local cword = vim.fn.expand("<cWORD>")
  local file, line, col = cword:match("([^:%s]+):(%d+):?(%d*)")
  if not file or file == "" then
    file = vim.fn.expand("<cfile>")
    line, col = nil, nil
  end
  if not file or file == "" then
    vim.notify("No file under cursor", vim.log.levels.WARN)
    return
  end

  local found = vim.fn.findfile(file, ".;")
  if found == "" then
    if vim.fn.filereadable(file) == 1 then
      found = file
    else
      vim.notify("File not found: " .. file, vim.log.levels.WARN)
      return
    end
  end

  self:hide()
  vim.schedule(function()
    vim.cmd("edit " .. vim.fn.fnameescape(found))
    if line and line ~= "" then
      local row = tonumber(line) or 1
      local col_n = math.max(0, (tonumber(col) or 1) - 1)
      pcall(vim.api.nvim_win_set_cursor, 0, { row, col_n })
    end
  end)
end

return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    config = true,
    keys = {
      { "<leader>a", nil, desc = "AI/Claude Code" },
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
      { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
      { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
      { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
      {
        "<leader>as",
        "<cmd>ClaudeCodeTreeAdd<cr>",
        desc = "Add file",
        ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw" },
      },
      -- Diff management
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
      { toggle_key, "<cmd>ClaudeCode<cr>", desc = "Toggle Claude", mode = { "n", "x" } },
    },
    opts = {
      auto_start = true,
      focus_after_send = true,
      terminal = {
        -- split_width_percentage = 0.50,
        ---@module "snacks"
        ---@type snacks.win.Config|{}
        snacks_win_opts = {
          position = "float",
          width = 0,
          height = 0,
          border = "none",
          keys = {
            claude_hide = {
              toggle_key,
              function(self)
                self:hide()
              end,
              mode = "t",
              desc = "Hide",
            },
            claude_goto_file = {
              "gF",
              goto_file_under_cursor,
              desc = "Goto file under cursor and hide Claude",
            },
          },
        },
      },
      diff_opts = {
        layout = "vertical", -- "vertical" or "horizontal"
        open_in_new_tab = true,
        keep_terminal_focus = false, -- If true, moves focus back to terminal after diff opens
        hide_terminal_in_new_tab = true,
      },
    },
  },
}
