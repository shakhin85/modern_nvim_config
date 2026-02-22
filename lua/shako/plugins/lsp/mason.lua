return {
  "williamboman/mason.nvim",
  dependencies = {
    "williamboman/mason-lspconfig.nvim",
    "WhoIsSethDaniel/mason-tool-installer.nvim",
  },
  config = function()
    -- import mason
    local mason = require("mason")

    -- import mason-lspconfig
    local mason_lspconfig = require("mason-lspconfig")

    -- enable mason and configure icons
    mason.setup({
      ui = {
        icons = {
          package_installed = "✓",
          package_pending = "➜",
          package_uninstalled = "✗",
        },
      },
    })

    mason_lspconfig.setup({
      -- list of servers for mason to install
      ensure_installed = {
        "ts_ls", -- replaced tsserver
        "html",
        "cssls",
        "tailwindcss",
        "svelte",
        "lua_ls",
        "emmet_ls",
        "prismals",
        "basedpyright",
        "powershell_es",
        "sqls",
        "marksman",
        "jsonls",
        "eslint",
        "yamlls",
        "dockerls",
        "docker_compose_language_service",
        "helm_ls",
        "rust_analyzer",
        "gopls",
      },
    })

    local mason_tool_installer = require("mason-tool-installer")

    mason_tool_installer.setup({
      ensure_installed = {
        -- formatters
        "prettier",
        "stylua",
        "ruff",
        -- formatters
        "gofumpt",
        -- linters
        "eslint_d",
        "pylint",
        "hadolint",
      },
    })
  end,
}