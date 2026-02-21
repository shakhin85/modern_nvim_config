return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    spec = {
      -- Navigation & search
      { "<leader>f",  group = "Find",               icon = "" },
      { "<leader>s",  group = "Splits/Navigation",  icon = "" },

      -- File & project
      { "<leader>e",  group = "Explorer",            icon = "" },
      { "<leader>b",  group = "Buffers",             icon = "󰓩" },
      { "<leader>t",  group = "Tabs",                icon = "" },
      { "<leader>q",  group = "Session",             icon = "" },

      -- Code & LSP
      { "<leader>c",  group = "Code",                icon = "" },
      { "<leader>m",  group = "Format/Lint",         icon = "󰉶" },

      -- Git
      { "<leader>g",  group = "Git",                 icon = "" },
      { "<leader>h",  group = "Git Hunks",           icon = "" },

      -- Debug
      { "<leader>d",  group = "Debug",               icon = "" },

      -- Test
      { "<leader>T",  group = "Test",                icon = "󰙨" },

      -- Python
      { "<leader>p",  group = "Python",              icon = "" },

      -- AI / Sidekick
      { "<leader>a",  group = "AI/Sidekick",         icon = "󱙺" },

      -- Toggles
      { "<leader>u",  group = "Toggles",             icon = "" },

      -- Notifications & messages
      { "<leader>n",  group = "Notifications",       icon = "󰵟" },

      -- Misc (single-key groups — shown for clarity)
      { "<leader>z",  desc  = "Zen mode",            icon = "󰒃" },
      { "<leader>lg", desc  = "LazyGit",             icon = "" },
    },
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer Local Keymaps (which-key)",
    },
  },
}
