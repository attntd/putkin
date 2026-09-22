local parsers = {
  "bash",
  "css",
  "fish",
  "html",
  "javascript",
  "json",
  "lua",
  "markdown",
  "markdown_inline",
  "ruby",
  "scss",
  "toml",
  "typescript",
  "yaml",
}

local filetypes = {
  "bash",
  "css",
  "fish",
  "html",
  "javascript",
  "javascriptreact",
  "json",
  "jsonc",
  "lua",
  "markdown",
  "ruby",
  "scss",
  "sh",
  "toml",
  "typescript",
  "typescriptreact",
  "yaml",
}

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local treesitter = require("nvim-treesitter")

      treesitter.setup({})
      treesitter.install(parsers)

      local group = vim.api.nvim_create_augroup("attntd_treesitter", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = filetypes,
        callback = function(args)
          -- Parsers are installed asynchronously on a fresh system. If one is
          -- not ready yet, reopening the buffer after installation starts it.
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },
}
