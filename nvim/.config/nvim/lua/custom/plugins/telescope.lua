-- lua/custom/plugins/telescope.lua
return {
  "nvim-telescope/telescope.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope-live-grep-args.nvim" },
  config = function()
    require("telescope").setup({
      defaults = {
        vimgrep_arguments = {
          "rg", "--color=never", "--no-heading",
          "--with-filename", "--line-number", "--column",
          "--smart-case",
        },
      },
    })
    require("telescope").load_extension("live_grep_args")
  end,
}
