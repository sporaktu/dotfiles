return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
  },
  {
    "nvim-telescope/telescope-live-grep-args.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
  },
  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  -- {
  -- 	"nvim-treesitter/nvim-treesitter",
  -- 	opts = {
  -- 		ensure_installed = {
  -- 			"vim", "lua", "vimdoc",
  --      "html", "css"
  -- 		},
  -- 	},
  -- },
 -- LSP & completion framework
  { "neovim/nvim-lspconfig" },                -- LSP client config  [oai_citation:3‡github.com](https://github.com/neovim/nvim-lspconfig?utm_source=chatgpt.com)
  { "hrsh7th/nvim-cmp", dependencies = {      -- completion engine
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "L3MON4D3/LuaSnip",                     -- snippets engine
      "saadparwaiz1/cmp_luasnip",
    },
  },

  -- Snippets
  { "rafamadriz/friendly-snippets" },

  -- Treesitter (syntax & folding)
  { "nvim-treesitter/nvim-treesitter", opts = {
      ensure_installed = { "c_sharp", "typescript", "javascript", "tsx", "lua" },
      highlight = { enable = true },
      indent    = { enable = true },
    },
  },

  -- Formatting
  { "jose-elias-alvarez/null-ls.nvim", dependencies = { "nvim-lua/plenary.nvim" } },

  -- React / TSX tooling
  { "windwp/nvim-ts-autotag" },               -- auto-close/jump in JSX  [oai_citation:4‡reddit.com](https://www.reddit.com/r/neovim/comments/10zc3ky/what_is_a_good_setup_for_react_typescript_tailwind/?utm_source=chatgpt.com)
  { "JoosepAlviste/nvim-ts-context-commentstring" }, -- context-aware comments

  -- Debugging (optional)
  { "mfussenegger/nvim-dap" },
}
