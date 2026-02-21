return {
	"sindrets/diffview.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	cmd = {
		"DiffviewOpen",
		"DiffviewClose",
		"DiffviewToggleFiles",
		"DiffviewFocusFiles",
		"DiffviewRefresh",
		"DiffviewFileHistory",
	},
	---@module "diffview"
	---@type DiffviewConfig
	opts = {
		enhanced_diff_hl = true,
		watch_index = true,
		view = {
			default = {
				layout = "diff2_horizontal",
			},
			merge_tool = {
				-- 3-way layout: LOCAL | BASE | REMOTE + result at bottom
				layout = "diff3_horizontal",
				disable_diagnostics = true,
			},
			file_history = {
				layout = "diff2_horizontal",
			},
		},
		file_panel = {
			listing_style = "tree",
			position = "left",
			width = 35,
		},
		file_history_panel = {
			position = "bottom",
			height = 16,
		},
	},
	keys = {
		{ "<leader>gd", "<cmd>DiffviewOpen<CR>",              desc = "Diffview: open (index diff)" },
		{ "<leader>gh", "<cmd>DiffviewFileHistory<CR>",       desc = "Diffview: repo history" },
		{ "<leader>gf", "<cmd>DiffviewFileHistory %<CR>",     desc = "Diffview: current file history" },
		{ "<leader>gx", "<cmd>DiffviewClose<CR>",             desc = "Diffview: close" },
	},
}
