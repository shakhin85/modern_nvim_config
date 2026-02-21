return {
	"nvim-neotest/neotest",
	dependencies = {
		"nvim-neotest/nvim-nio",
		"nvim-lua/plenary.nvim",
		"antoinemadec/FixCursorHold.nvim",
		"nvim-treesitter/nvim-treesitter",
		"nvim-neotest/neotest-python",
	},
	config = function()
		local neotest = require("neotest")

		neotest.setup({
			adapters = {
				require("neotest-python")({
					runner = "pytest",
					args = { "--tb=short", "-v" },
					-- Auto-detects virtualenv/conda; override if needed
					python = function()
						local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
						if venv then
							return venv .. "/bin/python"
						end
						return vim.fn.exepath("python3") or "python"
					end,
					-- DAP integration: step into library code too
					dap = { justMyCode = false },
					-- Discover parametrized test instances
					pytest_discover_instances = true,
				}),
			},
			output = {
				open_on_run = true,
			},
			output_panel = {
				enabled = true,
			},
			summary = {
				animated = true,
			},
			diagnostic = {
				enabled = true,
				severity = vim.diagnostic.severity.ERROR,
			},
		})

		local keymap = vim.keymap

		-- Run
		keymap.set("n", "<leader>Tr", function() neotest.run.run() end,                           { desc = "Test: run nearest" })
		keymap.set("n", "<leader>Tf", function() neotest.run.run(vim.fn.expand("%")) end,          { desc = "Test: run file" })
		keymap.set("n", "<leader>Ta", function() neotest.run.run(vim.fn.getcwd()) end,             { desc = "Test: run all (suite)" })
		keymap.set("n", "<leader>Tl", function() neotest.run.run_last() end,                       { desc = "Test: run last" })
		keymap.set("n", "<leader>Ts", function() neotest.run.stop() end,                           { desc = "Test: stop" })

		-- Debug nearest test via DAP
		keymap.set("n", "<leader>Td", function() neotest.run.run({ strategy = "dap" }) end,       { desc = "Test: debug nearest" })

		-- UI
		keymap.set("n", "<leader>TT", function() neotest.summary.toggle() end,                    { desc = "Test: toggle summary" })
		keymap.set("n", "<leader>To", function() neotest.output.open({ enter = true }) end,        { desc = "Test: open output" })
		keymap.set("n", "<leader>Tp", function() neotest.output_panel.toggle() end,               { desc = "Test: toggle output panel" })

		-- Watch
		keymap.set("n", "<leader>Tw", function() neotest.watch.toggle(vim.fn.expand("%")) end,    { desc = "Test: watch file" })
	end,
}
