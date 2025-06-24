local lspconfig = require("lspconfig")

-- C# / .NET
lspconfig.omnisharp.setup({
  cmd = { "omnisharp" },
  on_attach = function(client, bufnr) require("lsp.handlers").on_attach(client, bufnr) end,
})

-- TypeScript / JavaScript
lspconfig.tsserver.setup({
  on_attach = function(client, bufnr)
    client.resolved_capabilities.document_formatting = false
    require("lsp.handlers").on_attach(client, bufnr)
  end,
})

-- React Native (uses tsserver for TS and a separate debug adapter)
