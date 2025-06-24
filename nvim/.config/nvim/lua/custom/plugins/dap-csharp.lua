-- lua/custom/plugins/dap-csharp.lua
local dap = require("dap")

dap.adapters.coreclr = {
  type = "executable",
  command = "netcoredbg",
  args = { "--interpreter=vscode" },
}

dap.configurations.cs = {
  {
    type = "coreclr",
    request = "launch",
    program = function()
      return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
    end,
  },
}

return {
  "mfussenegger/nvim-dap",
  config = function() end,
}
