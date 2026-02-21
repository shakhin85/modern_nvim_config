return {
	"igorlfs/nvim-dap-view",
	dependencies = { "mfussenegger/nvim-dap" },
	lazy = false,
	---@module 'dap-view'
	---@type dapview.Config
	opts = {
		winbar = {
			sections = { "watches", "scopes", "exceptions", "breakpoints", "threads", "repl" },
			default_section = "scopes",
			show_keymap_hints = true,
			controls = {
				enabled = true,
				position = "right",
			},
		},
		windows = {
			size = 0.3,
			position = "below",
			terminal = {
				size = 0.5,
				position = "left",
				-- hide the terminal for adapters that use the integrated console
				hide = { "python" },
			},
		},
		auto_toggle = true,
	},
	config = function(_, opts)
		require("dap-view").setup(opts)

		local keymap = vim.keymap
		local dv = require("dap-view")

		keymap.set("n", "<leader>dv", dv.toggle, { desc = "Toggle dap-view" })
		keymap.set("n", "<leader>dw", "<cmd>DapViewWatch<CR>", { desc = "Watch expression under cursor" })
		keymap.set("v", "<leader>dw", "<cmd>DapViewWatch<CR>", { desc = "Watch selected expression" })
		keymap.set("n", "<leader>dj", "<cmd>DapViewJump repl<CR>", { desc = "Jump to REPL" })
	end,
}
