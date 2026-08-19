return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local conform = require("conform")

    -- sql-formatter по умолчанию говорит на «basic sql» и ломает диалектный синтаксис
    -- (TOP/[скобки] в T-SQL, ::cast в PG). Диалект берём из подключения буфера.
    local sql_language_by_scheme = {
      postgres = "postgresql",
      postgresql = "postgresql",
      sqlserver = "tsql",
      sqlite = "sqlite",
    }

    -- Без b:db (файл ещё не подключён) диалект берём хотя бы из filetype.
    local sql_language_by_ft = { mysql = "mysql", plsql = "plsql" }

    conform.setup({
      formatters = {
        sql_formatter = {
          prepend_args = function(_, ctx)
            local scheme = (vim.b[ctx.buf].db or ""):match("^(%a[%w+.-]*):")
            local ft = vim.bo[ctx.buf].filetype
            return { "-l", sql_language_by_scheme[scheme] or sql_language_by_ft[ft] or "postgresql" }
          end,
        },
      },
      formatters_by_ft = {
        javascript = { "prettier" },
        typescript = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },
        svelte = { "prettier" },
        css = { "prettier" },
        html = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        graphql = { "prettier" },
        lua = { "stylua" },
        python = { "ruff_format" },
        go = { "gofumpt" },
        toml = { "taplo" },
        sql = { "sql_formatter" },
        mysql = { "sql_formatter" },
        plsql = { "sql_formatter" },
      },
      format_on_save = function(bufnr)
        -- Буферы dadbod-ui — это черновики запросов, а не исходники: переписывать их
        -- раскладку на каждом :w значит терять то, как запрос был набран.
        if vim.b[bufnr].dbui_db_key_name then
          return nil
        end
        return { lsp_format = "fallback", async = false, timeout_ms = 1000 }
      end,
    })

    vim.keymap.set({ "n", "v" }, "<leader>mp", function()
      conform.format({
        lsp_format = "fallback",
        async = false,
        timeout_ms = 1000,
      })
    end, { desc = "Format file or range (in visual mode)" })
  end,
}
