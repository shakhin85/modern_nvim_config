return {
	"uga-rosa/ccc.nvim",
	event = { "BufReadPre", "BufNewFile" },
	keys = {
		{ "<leader>cp", "<cmd>CccPick<CR>", desc = "Color picker" },
		{ "<leader>ch", "<cmd>CccHighlighterToggle<CR>", desc = "Toggle color highlight" },
		{ "<leader>cc", "<cmd>CccConvert<CR>", desc = "Convert color format" },
	},
	opts = {
		highlighter = {
			auto_enable = true,
			lsp = true,
		},
	},
}
