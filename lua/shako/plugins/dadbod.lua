return {
	{
		"tpope/vim-dadbod",
		lazy = true,
	},
	{
		"kristijanhusak/vim-dadbod-ui",
		dependencies = {
			"tpope/vim-dadbod",
			"kristijanhusak/vim-dadbod-completion",
		},
		cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
		keys = {
			{ "<leader>Du", "<cmd>DBUIToggle<CR>", desc = "Toggle DB UI" },
			{ "<leader>Da", "<cmd>DBUIAddConnection<CR>", desc = "Add DB connection" },
			{ "<leader>Df", "<cmd>DBUIFindBuffer<CR>", desc = "Find DB buffer" },
		},
		init = function()
			vim.g.db_ui_use_nerd_fonts = 1
			vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/db_ui"
			vim.g.db_ui_execute_on_save = 0 -- :w не выполняет запрос; выполнять <leader>S / <leader>W
			vim.g.db_ui_show_database_icon = 1
			vim.g.db_ui_auto_execute_table_helpers = 1
			vim.g.db_ui_win_position = "left"
			vim.g.db_ui_winwidth = 35
			-- Подключения — в git-ignored lua/shako/dbs.local.lua (см. dbs.local.lua.example)
			local ok, dbs = pcall(dofile, vim.fn.stdpath("config") .. "/lua/shako/dbs.local.lua")
			if ok and type(dbs) == "table" then
				vim.g.dbs = dbs
			end
		end,
	},
	{
		"kristijanhusak/vim-dadbod-completion",
		ft = { "sql", "mysql", "plsql", "sqlite" },
		lazy = true,
	},
}
