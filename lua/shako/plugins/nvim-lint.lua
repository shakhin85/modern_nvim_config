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
    lint.linters.sqlfluff.args = {
      "lint",
      "--format=json",
      "--dialect",
      function()
        return require("shako.dburl").sqlfluff_dialect(0)
      end,
      "-",
    }

    -- squawk: опасные для прода миграции PostgreSQL (блокирующий DDL, NOT NULL без
    -- default, индекс без CONCURRENTLY). Строки в gcc-выводе 0-based. Только PG-буферы:
    -- T-SQL squawk не разберёт. Ставится `uv tool install squawk-cli`.
    lint.linters.squawk = {
      cmd = "squawk",
      stdin = true,
      args = { "--reporter", "gcc", "--stdin-filepath", "stdin.sql" },
      ignore_exitcode = true,
      -- Свой парсер: from_pattern ждёт 1-based строки и обрезает 0 до 0 раньше offset.
      parser = function(output)
        local diags = {}
        for line in output:gmatch("[^\n]+") do
          local lnum, col, sev, code, msg = line:match("^[^:]+:(%d+):(%d+): (%w+): ([%w-]+) (.*)$")
          if lnum then
            table.insert(diags, {
              lnum = tonumber(lnum),
              col = tonumber(col),
              severity = sev == "error" and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN,
              code = code,
              message = msg,
              source = "squawk",
            })
          end
        end
        return diags
      end,
    }

    local function lint_buffer()
      lint.try_lint()
      if vim.bo.filetype == "sql" and (vim.b.db or ""):match("^postgres") and vim.fn.executable("squawk") == 1 then
        lint.try_lint("squawk")
      end
    end

    local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

    -- Все линтеры здесь — процессы по 0.5–2 с (sqlfluff ~670 мс). BufEnter гонял их на
    -- каждом переключении буфера, хотя диагностика буфера и так живёт; InsertLeave
    -- с eslint_d подвешивает ввод (nvim-lint, репорт пользователей). Ручной — <leader>ml.
    vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
      group = lint_augroup,
      callback = lint_buffer,
    })

    vim.keymap.set("n", "<leader>ml", lint_buffer, { desc = "Trigger linting for current file" })
  end,
}
