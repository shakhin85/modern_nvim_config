return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local conform = require("conform")

    conform.setup({
      formatters = {
        -- sqlfluff правит только раскладку и регистр ключевых слов: смысловые правила
        -- (convention/structure) переписывали бы запрос на каждом :w.
        -- Ширина, выравнивание алиасов, позиции join/where — в ~/.sqlfluff.
        sqlfluff = {
          args = function(_, ctx)
            return { "fix", "--rules", "layout,capitalisation", "--dialect", require("shako.dburl").sqlfluff_dialect(ctx.buf), "-" }
          end,
          require_cwd = false,
        },
        -- Зазор 20 символов между полем и алиасом: lua/shako/sql_align.lua.
        sql_alias_pad = {
          format = function(_, _, lines, callback)
            callback(nil, require("shako.sql_align").pad_aliases(lines))
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
        sql = { "sqlfluff", "sql_alias_pad" },
        mysql = { "sqlfluff", "sql_alias_pad" },
        plsql = { "sqlfluff", "sql_alias_pad" },
      },
      format_on_save = function(bufnr)
        -- Буферы dadbod-ui — это черновики запросов, а не исходники: переписывать их
        -- раскладку на каждом :w значит терять то, как запрос был набран.
        -- Заметки nvim-dbee — те же черновики, только без b:dbui_db_key_name.
        local notes = vim.fs.normalize(vim.fn.stdpath("state") .. "/dbee/notes")
        if vim.b[bufnr].dbui_db_key_name or vim.startswith(vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr)), notes) then
          return nil
        end
        -- SQL не форматируется на :w: синхронный sqlfluff (~0.8 с) замораживал ввод.
        -- SQL форматирует <leader>mp асинхронно.
        if vim.tbl_contains({ "sql", "mysql", "plsql" }, vim.bo[bufnr].filetype) then
          return nil
        end
        return { lsp_format = "fallback", timeout_ms = 1000 }
      end,
    })

    vim.keymap.set({ "n", "v" }, "<leader>mp", function()
      conform.format({
        lsp_format = "fallback",
        async = true, -- sqlfluff ~0.8 с не держит main thread
        timeout_ms = 5000
      })
    end, { desc = "Format file or range (in visual mode)" })
  end,
}
