-- refer to :help nvim-cmp
-- refer to https://www.reddit.com/r/neovim/comments/u3c3kw/comment/i4p8gck/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button
return {
  {
    "hrsh7th/nvim-cmp",
    opts = function(_, opts)
      local cmp = require("cmp")
      local compare = cmp.config.compare

      opts.sources = cmp.config.sources({
        -- { name = "nvim_lsp_signature_help" },
        -- { name = "cmp_tabnine", priority = 8 },
        { name = "nvim_lsp", priority = 8 },
        { name = "ultisnips", priority = 7 },
        { name = "buffer", priority = 7 }, -- first for locality sorting?
        { name = "spell", keyword_length = 3, priority = 5, keyword_pattern = [[\w\+]] },
        { name = "dictionary", keyword_length = 3, priority = 5, keyword_pattern = [[\w\+]] }, -- from uga-rosa/cmp-dictionary plug
        -- { name = 'rg'},
        { name = "nvim_lua", priority = 5 },
        { name = "path" },
        { name = "fuzzy_path", priority = 4 }, -- from tzacher
        { name = "calc", priority = 3 },
        -- { name = "vsnip" },
        -- { name = "luasnip" },
        -- { name = "snippy" },
        -- { name = "ultisnips" },
      })
      opts.sorting = {
        comparators = {
          -- compare.score_offset, -- not good at all
          -- compare.locality,
          -- compare.recently_used,
          compare.score, -- based on :  score = score + ((#sources - (source_index - 1)) * sorting.priority_weight)
          compare.kind,
          compare.offset,
          compare.order,
          -- compare.scopes, -- what?
          -- compare.sort_text,
          -- compare.exact,
          -- compare.length, -- useless
        },
      }
    end,
  },
}
