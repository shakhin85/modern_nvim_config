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
      end,
    })
    vim.cmd.colorscheme("tokyonight-night")
  end,
}
