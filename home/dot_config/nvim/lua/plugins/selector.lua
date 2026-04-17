return {
  "ibhagwan/fzf-lua",
  config = function(_, opts)
    opts = opts or {}
    opts.actions = opts.actions or {}

    -- Read defaults before setup, merge in our custom action
    local default_files = vim.deepcopy(
      require("fzf-lua.config").globals.actions.files or {}
    )
    default_files["ctrl-o"] = function(selected)
      local entry = require("fzf-lua").path.entry_to_file(selected[1])
      if entry and entry.path then
        require("oil").open(vim.fn.fnamemodify(entry.path, ":p:h"), {}, function()
          vim.fn.search(vim.fn.escape(vim.fn.fnamemodify(entry.path, ":t"), "\\/.*[]^~$"), "w")
        end)
      end
    end

    opts.actions.files = vim.tbl_extend("force", default_files, opts.actions.files or {})
    require("fzf-lua").setup(opts)
  end,
}
