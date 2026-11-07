return {
  "folke/tokyonight.nvim",
  priority = 1000,
  config = function()
    require("tokyonight").setup({
      style = "night",
      transparent = false,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
      },
      -- В SQL ключевые слова несут структуру запроса: жирный оранжевый без
      -- курсива отделяет SELECT/FROM/WHERE от имён колонок и таблиц.
      on_highlights = function(hl, c)
        hl["@keyword.sql"] = { fg = c.orange, bold = true }
        -- Операторы SQL: after/queries/sql/highlights.scm.
        hl["@keyword.operator.logical"] = { fg = c.red, bold = true }
        hl["@keyword.operator.predicate"] = { fg = c.yellow }
        hl["@operator.comparison"] = { fg = c.cyan }
        hl["@operator.arithmetic"] = { fg = c.green1 }
      end,
    })
    vim.cmd.colorscheme("tokyonight-night")
  end,
}
