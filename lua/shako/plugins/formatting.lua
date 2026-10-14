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
        sql = { "sqlfluff" },
        mysql = { "sqlfluff" },
        plsql = { "sqlfluff" },
      },
      format_on_save = function(bufnr)
        -- Буферы dadbod-ui — это черновики запросов, а не исходники: переписывать их
        -- раскладку на каждом :w значит терять то, как запрос был набран.
        -- Заметки nvim-dbee — те же черновики, только без b:dbui_db_key_name.
        local notes = vim.fs.normalize(vim.fn.stdpath("state") .. "/dbee/notes")
        if vim.b[bufnr].dbui_db_key_name or vim.startswith(vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr)), notes) then
          return nil
        end
        -- sqlfluff разбирает запрос ~1.2 с: с лимитом 1 с conform обрывал бы его.
        local sql = vim.tbl_contains({ "sql", "mysql", "plsql" }, vim.bo[bufnr].filetype)
        return { lsp_format = "fallback", async = false, timeout_ms = sql and 5000 or 1000 }
      end,
    })

    vim.keymap.set({ "n", "v" }, "<leader>mp", function()
      conform.format({
        lsp_format = "fallback",
        async = false,
        timeout_ms = 5000, -- ручной вызов: sqlfluff ~1.2 с
      })
    end, { desc = "Format file or range (in visual mode)" })
  end,
}
