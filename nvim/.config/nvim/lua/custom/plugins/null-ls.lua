-- lua/custom/plugins/null-ls.lua
local null_ls = require("null-ls")

return {
  "jose-elias-alvarez/null-ls.nvim",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = { "nvim-lua/plenary.nvim" },
  config = function()
    null_ls.setup({
      sources = {
        null_ls.builtins.formatting.prettier.with({
          filetypes = { "typescript", "javascript", "tsx", "jsx" },
        }),
        null_ls.builtins.formatting.stylua,
        null_ls.builtins.formatting.gofmt,
      },
    })
  end,
}
