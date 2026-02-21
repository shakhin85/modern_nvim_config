return {
	"stevearc/oil.nvim",
	lazy = false,
	dependencies = { "nvim-tree/nvim-web-devicons" },
	---@module "oil"
	---@type oil.SetupOpts
	opts = {
		-- Use oil for directory buffers (nvim .)
		default_file_explorer = true,
		-- Send deletes to trash instead of permanent removal
		delete_to_trash = true,
		-- Watch filesystem for external changes
		watch_for_changes = true,
		-- Show icon + file size
		columns = { "icon", "size" },
		view_options = {
			-- Toggle with g.
			show_hidden = false,
			natural_order = "fast",
		},
		-- Remap <C-h> (conflicts with window navigation) → <C-x>
		keymaps = {
			["<C-h>"] = false,
			["<C-x>"] = { "actions.select", opts = { horizontal = true } },
		},
		-- Notify LSP when files are renamed/moved
		lsp_file_methods = {
			enabled = true,
			timeout_ms = 1000,
		},
	},
	keys = {
		{ "-",          "<cmd>Oil<CR>",                                  desc = "Open oil (parent dir)" },
		{ "<leader>eo", function() require("oil").open_float() end,      desc = "Oil floating window" },
	},
}
