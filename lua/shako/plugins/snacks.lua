return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@module "snacks"
	---@type snacks.Config
	opts = {
		-- Perf: disable heavy features on large files
		bigfile = { enabled = true },
		-- Render files fast before plugins load
		quickfile = { enabled = true },
		-- Better vim.ui.input
		input = { enabled = true },
		-- LSP-aware file rename
		rename = { enabled = true },
		-- Smart buffer delete (no window close side-effects)
		bufdelete = { enabled = true },
		-- Smooth scrolling
		scroll = { enabled = true },
		-- Highlight all LSP references for word under cursor
		words = { enabled = true },
		-- Enhanced status column (line numbers, folds, signs)
		statuscolumn = { enabled = true },
		-- Indent guides + animated scope (replaces indent-blankline)
		indent = {
			indent = { char = "│" },
			scope = { enabled = true, char = "│" },
		},
		-- LazyGit integration (replaces kdheepak/lazygit.nvim)
		lazygit = { enabled = true },
		-- Open current file/line in GitHub/GitLab
		gitbrowse = { enabled = true },
		-- Distraction-free mode
		zen = {
			enabled = true,
			toggles = { dim = true },
		},
		-- Toggle helpers (used in init autocmd below)
		toggle = { enabled = true },
		-- notifier intentionally disabled — noice.nvim + nvim-notify handle this
		notifier = { enabled = false },
		-- Floating terminal (shell auto-detected: pwsh on Windows, $SHELL on Linux)
		terminal = {
			enabled = true,
			win = {
				style = "terminal",
				position = "float",
				border = "rounded",
				height = 0.8,
				width = 0.8,
			},
		},
		-- Startup dashboard
		dashboard = {
			enabled = true,
			preset = {
				keys = {
					{ icon = " ", key = "f", desc = "Find File", action = ":Telescope find_files" },
					{ icon = " ", key = "r", desc = "Recent Files", action = ":Telescope oldfiles" },
					{ icon = " ", key = "g", desc = "Find Text", action = ":Telescope live_grep" },
					{ icon = " ", key = "s", desc = "Restore Session", action = ":lua require('persistence').load()" },
					{ icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
					{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
				},
			},
			sections = {
				{ section = "header" },
				{ section = "keys", gap = 1, padding = 1 },
				{ section = "recent_files", indent = 2, padding = 1 },
				{ section = "startup" },
			},
		},
	},
	init = function()
		vim.api.nvim_create_autocmd("User", {
			pattern = "VeryLazy",
			callback = function()
				-- Toggle keymaps (all under <leader>u*)
				Snacks.toggle.diagnostics():map("<leader>ud")
				Snacks.toggle.inlay_hints():map("<leader>uh")
				Snacks.toggle.indent():map("<leader>ug")
				Snacks.toggle.option("wrap", { name = "Wrap" }):map("<leader>uw")
				Snacks.toggle.option("relativenumber", { name = "Relative Numbers" }):map("<leader>ur")
				Snacks.toggle.option("spell", { name = "Spelling" }):map("<leader>us")
				Snacks.toggle.dim():map("<leader>uD")
			end,
		})
	end,
	keys = {
		{
			"<leader>lg",
			function()
				Snacks.lazygit()
			end,
			desc = "Open LazyGit",
		},
		{
			"<leader>gb",
			function()
				Snacks.gitbrowse()
			end,
			desc = "Git browse in browser",
		},
		{
			"<leader>z",
			function()
				Snacks.zen()
			end,
			desc = "Toggle zen mode",
		},
		{
			"<leader>bd",
			function()
				Snacks.bufdelete()
			end,
			desc = "Delete buffer",
		},
		{
			"<leader>tt",
			function()
				Snacks.terminal()
			end,
			desc = "Toggle terminal",
			mode = { "n", "t" },
		},
	},
}
