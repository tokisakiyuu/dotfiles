-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

--- Path of the current buffer. Relative paths fall back to absolute when the
--- file lives outside cwd (that is `%:.` behaviour, and the sane result anyway).
local function buf_path(absolute)
  return vim.fn.expand(absolute and "%:p" or "%:.")
end

--- Upper-left corner of the visual selection, so a backwards selection still
--- reports where the text starts rather than where the cursor happens to be.
local function selection_start()
  local cursor_line, cursor_col = vim.fn.line("."), vim.fn.col(".")
  local anchor_line, anchor_col = vim.fn.line("v"), vim.fn.col("v")
  if anchor_line < cursor_line or (anchor_line == cursor_line and anchor_col < cursor_col) then
    return anchor_line, anchor_col
  end
  return cursor_line, cursor_col
end

--- Put text in the system clipboard AND the unnamed register.
--- Under SSH the OSC52 provider's paste reads back from the unnamed register
--- (see config/options.lua), so writing only `+` would leave `p` pasting stale
--- text inside Neovim.
local function yank(text)
  vim.fn.setreg("+", text)
  vim.fn.setreg("", text)
end

--- Copy the current file path. In visual mode the selection start is appended:
--- `file:line` for linewise, `file:line:col` for charwise and blockwise.
local function copy_path(absolute)
  local path = buf_path(absolute)
  if path == "" then
    vim.notify("Buffer has no file path", vim.log.levels.WARN)
    return
  end

  local mode = vim.fn.mode():sub(1, 1)
  if mode == "v" or mode == "V" or mode == "\22" then
    local line, col = selection_start()
    path = mode == "V" and ("%s:%d"):format(path, line) or ("%s:%d:%d"):format(path, line, col)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  end

  yank(path)
  vim.notify(path, vim.log.levels.INFO, { title = "Copied path" })
end

vim.keymap.set({ "n", "x" }, "<leader>yp", function()
  copy_path(false)
end, { desc = "Copy relative path" })

vim.keymap.set({ "n", "x" }, "<leader>yP", function()
  copy_path(true)
end, { desc = "Copy absolute path" })
