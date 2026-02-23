return {
	"akinsho/toggleterm.nvim",
	version = "*",
	opts = {
		size = function(term)
			if term.direction == "horizontal" then
				return 15
			elseif term.direction == "vertical" then
				return vim.o.columns * 0.4
			end
		end,
		open_mapping = [[<C-\>]],
		hide_numbers = true,
		shade_terminals = true,
		shading_factor = 2,
		start_in_insert = true,
		insert_mappings = true,
		terminal_mappings = true,
		persist_size = true,
		direction = "horizontal",
		close_on_exit = true,
		shell = vim.o.shell,
		auto_scroll = true,
		float_opts = {
			border = "curved",
			winblend = 3,
		},
	},
	keys = {
		{ [[<C-\>]],    desc = "Toggle terminal" },
		{ "<leader>tt", "<cmd>ToggleTerm<CR>",                        desc = "Toggle terminal" },
		{ "<leader>tf", "<cmd>ToggleTerm direction=float<CR>",        desc = "Float terminal" },
		{ "<leader>th", "<cmd>ToggleTerm direction=horizontal<CR>",   desc = "Horizontal terminal" },
		{ "<leader>tv", "<cmd>ToggleTerm direction=vertical<CR>",     desc = "Vertical terminal" },
	},
}
