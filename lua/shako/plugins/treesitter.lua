return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  branch = "main",
  build = ":TSUpdate",
  config = function()
    -- configure treesitter
    local ts = require("nvim-treesitter")

    ts.setup({
      highlight = { enable = true },
      indent = { enable = true },
    })

    local parsers = {
      "json",
      "javascript",
      "typescript",
      "tsx",
      "yaml",
      "html",
      "css",
      "prisma",
      "markdown",
      "markdown_inline",
      "svelte",
      "graphql",
      "bash",
      "lua",
      "vim",
      "dockerfile",
      "query",
      "vimdoc",
      "c",
    }

    local to_install = {}
    for _, lang in ipairs(parsers) do
      -- Check if the parser .so file exists in the runtime path
      if #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".so", true) == 0 then
        table.insert(to_install, lang)
      end
    end

    -- install missing parsers
    if #to_install > 0 then
      print("Installing missing treesitter parsers: " .. table.concat(to_install, ", "))
      ts.install(to_install)
    end

    -- use bash parser for zsh files
    vim.treesitter.language.register("bash", "zsh")
  end,
}
