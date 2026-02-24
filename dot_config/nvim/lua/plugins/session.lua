return {
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {
      branch = false,
      need = 2,
    },
  },
}
