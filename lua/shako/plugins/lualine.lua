return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    require("lualine").setup({
      options = {
        theme = "tokyonight",
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        globalstatus = true,
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        lualine_c = { { "filename", path = 1 } },
        lualine_x = {
          {
            -- База SQL-буфера: куда уйдёт <leader>S. Prod — красным.
            function()
              return "󰆼 " .. require("shako.sql_ux").db_label()
            end,
            cond = function()
              return require("shako.sql_ux").db_label() ~= nil
            end,
            color = function()
              local _, prod = require("shako.sql_ux").db_label()
              return prod and { fg = "#f7768e", gui = "bold" } or nil
            end,
          },
          "encoding",
          "fileformat",
          "filetype",
        },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
    })
  end,
}
