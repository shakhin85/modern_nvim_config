return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local lint = require("lint")

    lint.linters_by_ft = {
      javascript = { "eslint_d" },
      typescript = { "eslint_d" },
      javascriptreact = { "eslint_d" },
      typescriptreact = { "eslint_d" },
      svelte = { "eslint_d" },
      python = { "pylint" },
      dockerfile = { "hadolint" },
      sql = { "sqlfluff" },
    }

    -- sqlfluff: диалект по схеме b:db — иначе валидный T-SQL летит как синтаксическая
    -- ошибка postgres. Правила и исключения — в ~/.sqlfluff (→ nvim/sqlfluff/user.cfg).
    local dialect_by_scheme = {
      postgres = "postgres",
      postgresql = "postgres",
      sqlserver = "tsql",
      sqlite = "sqlite",
    }

    lint.linters.sqlfluff.args = {
      "lint",
      "--format=json",
      "--dialect",
      function()
        local scheme = (vim.b.db or ""):match("^(%a[%w+.-]*):")
        return dialect_by_scheme[scheme] or "postgres"
      end,
      "-",
    }

    local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

    -- Все линтеры здесь — процессы по 0.5–2 с (sqlfluff ~670 мс). BufEnter гонял их на
    -- каждом переключении буфера, хотя диагностика буфера и так живёт; InsertLeave
    -- с eslint_d подвешивает ввод (nvim-lint, репорт пользователей). Ручной — <leader>ml.
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
      group = lint_augroup,
      callback = function()
        lint.try_lint()
      end,
    })

    vim.keymap.set("n", "<leader>ml", function()
      lint.try_lint()
    end, { desc = "Trigger linting for current file" })
  end,
}
