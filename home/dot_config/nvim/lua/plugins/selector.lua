return {
  "ibhagwan/fzf-lua",
  opts = {
    actions = {
      files = {
        ["ctrl-o"] = function(selected)
          local entry = require("fzf-lua").path.entry_to_file(selected[1])
          if entry and entry.path then
            require("oil").open(vim.fn.fnamemodify(entry.path, ":p:h"), {}, function()
              vim.fn.search(vim.fn.escape(vim.fn.fnamemodify(entry.path, ":t"), "\\/.*[]^~$"), "w")
            end)
          end
        end,
      },
    },
  },
}
