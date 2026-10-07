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
      -- v2 сам зовёт vim.lsp.enable для всего установленного. rust_analyzer
      -- поднимает rustaceanvim — второй экземпляр дублирует диагностику и actions.
      automatic_enable = { exclude = { "rust_analyzer" } },
      -- list of servers for mason to install
      ensure_installed = {
        "ts_ls", -- replaced tsserver
        "html",
        "cssls",
        "tailwindcss",
        "svelte",
        "lua_ls",
        "emmet_ls",
        "basedpyright",
        "powershell_es",
        "marksman",
        "jsonls",
        "eslint",
        "yamlls",
        "dockerls",
        "docker_compose_language_service",
        "helm_ls",
        "rust_analyzer",
        "gopls",
        "taplo",
        "graphql",
      },
    })

    local mason_tool_installer = require("mason-tool-installer")

    mason_tool_installer.setup({
      -- mason-tool-installer по умолчанию требует mason-nvim-dap.mappings.source,
      -- а тот тянет dap.utils — из-за этого nvim-dap грузился на каждый старт
      -- мимо своих keys-триггеров. Интеграция нужна только для резолва имён
      -- dap-адаптеров в ensure_installed ниже; их там нет, адаптеры ставит
      -- сам mason-nvim-dap из dap.lua.
      integrations = { ["mason-nvim-dap"] = false },
      ensure_installed = {
        -- formatters
        "prettier",
        "stylua",
        "ruff",
        -- formatters
        "gofumpt",
        -- formatters
        "taplo",
        "sql-formatter",
        "sqlfluff",
        -- linters
        "eslint_d",
        "pylint",
        "hadolint",
      },
    })
  end,
}