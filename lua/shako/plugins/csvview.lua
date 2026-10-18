-- CSV из экспорта <leader>Dc читается как таблица: колонки выровнены,
-- шапка остаётся видна при прокрутке вниз.
return {
  "hat0uma/csvview.nvim",
  ft = { "csv", "tsv" },
  opts = {
    view = {
      display_mode = "border",
      header_lnum = 1,
      sticky_header = { enabled = true },
    },
    keymaps = {
      -- Перемещение по полям, как по ячейкам таблицы.
      jump_next_field_end = { "<Tab>", mode = { "n", "v" } },
      jump_prev_field_end = { "<S-Tab>", mode = { "n", "v" } },
    },
  },
  config = function(_, opts)
    require("csvview").setup(opts)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "csv", "tsv" },
      callback = function(ev)
        require("csvview").enable(ev.buf)
      end,
    })
    -- Первый буфер уже открыт до регистрации автокоманды.
    require("csvview").enable(0)
  end,
}
