-- Sidekick.nvim - AI Assistant Integration
--
-- WORKFLOW:
--   1. Open AI tool: <leader>ac (Claude), <leader>am (Gemini), <leader>ag (Grok), <leader>ao (Copilot)
--   2. Chat preserves history — hide/show window keeps same session
--   3. Start fresh: <leader>ad (close session), then reopen
--   4. Prompts: <leader>ap opens picker with custom prompts (see cli.prompts below)
--
-- TEMPLATE VARIABLES (usable in prompts):
--   {this}           — code at cursor (function, class, or nearby code)
--   {file}           — entire current file content
--   {selection}      — visually selected text
--   {diagnostics}    — LSP errors/warnings in current file
--   {diagnostics_all}— diagnostics across all open files
--   {function}       — current function (requires treesitter-textobjects)
--   {class}          — current class (requires treesitter-textobjects)
--   {line}           — current line content
--   {buffers}        — content from open buffers
--   {quickfix}       — quickfix list entries
--
return {
	"folke/sidekick.nvim",
	event = "VeryLazy",
	dependencies = {
		{
			"zbirenbaum/copilot.lua",
			event = "VeryLazy",
			config = function()
				require("copilot").setup({
					-- Disable built-in panel and suggestions — sidekick handles all UI
					panel = { enabled = false },
					suggestion = { enabled = false },
					filetypes = {
						["*"] = true,
						gitcommit = false,
						gitrebase = false,
					},
					copilot_node_command = "node",
				})
			end,
		},
	},
	config = function()
		require("sidekick").setup({
			-- Next Edit Suggestions
			nes = {
				enabled = true,
				debounce = 100,
				trigger = {
					events = { "InsertLeave", "TextChanged", "User SidekickNesDone" },
				},
				clear = {
					events = { "TextChangedI", "TextChanged", "BufWritePre", "InsertEnter" },
					esc = true,
				},
				diff = {
					inline = "words",
				},
			},

			-- CLI window
			cli = {
				watch = true,
				win = {
					layout = "float",
					float = {
						width = 0.9,
						height = 0.85,
					},
					split = {
						width = 80,
						height = 20,
					},
					keys = {
						hide_n        = { "q", "hide", mode = "n" },
						-- <c-q> in terminal mode = enter normal mode (stopinsert, default).
						-- <c-q> in normal mode  = hide window (hide_ctrl_q, default).
						-- <Esc><Esc> = enter normal mode (single <Esc> still goes to the AI tool).
						stopinsert_esc = { "<Esc><Esc>", "stopinsert", mode = "t" },
						win_p         = { "<c-w>p", "blur" },
						prompt        = { "<c-p>", "prompt" },
					},
				},
				-- Zellij mux: only enable if inside a zellij session
				mux = {
					backend = "zellij",
					enabled = vim.fn.has("win32") == 0
						and vim.fn.executable("zellij") == 1
						and vim.fn.getenv("ZELLIJ") ~= vim.NIL,
					create = "terminal",
				},
				-- Custom prompt library — selected via <leader>ap
				-- Variables like {this}, {file}, {selection} are expanded before sending
				prompts = {
					-- Review & understand
					changes      = "Can you review my changes?",
					review       = "Can you review {file} for any issues or improvements?",
					explain      = "Explain the following code in detail:\n{this}",

					-- Fix & diagnose
					diagnostics  = "Can you help me fix the diagnostics in {file}?\n{diagnostics}",
					fix          = "Fix this issue:\n{diagnostics}\n\nCode context:\n{this}",
					debug        = "Help debug this code:\n{this}",

					-- Improve
					optimize     = "Suggest optimizations for:\n{this}",
					simplify     = "Simplify this code:\n{this}",
					refactor     = "Refactor the following code:\n{this}",
					errors       = "Add comprehensive error handling with proper logging to:\n{this}",

					-- Type safety
					types        = "Add proper type annotations/hints to:\n{this}",

					-- Docs
					document     = "Generate comprehensive documentation for:\n{this}",

					-- Testing
					tests        = "Generate comprehensive unit tests for:\n{this}",
					edge_cases   = "What edge cases and failure modes should be tested for:\n{this}",
					mocks        = "Generate mocks and fixtures for testing:\n{this}",

					-- Git workflow
					commit       = "Write a concise conventional commit message for these changes:\n{this}",
					pr           = "Write a pull request description with summary and test plan for:\n{this}",

					-- Security
					security     = "Review this code for security vulnerabilities (OWASP, injections, secrets):\n{this}",

					-- DevOps
					dockerfile   = "Review this Dockerfile for best practices, security, and layer optimization:\n{file}",
					ci           = "Review this CI/CD config and suggest improvements:\n{file}",
					logging      = "Add structured logging with appropriate log levels to:\n{this}",
				},
			},

			copilot = {
				status = { enabled = true },
			},

			signs = {
				enabled = true,
				icon = " ",
			},

			jump = {
				jumplist = true,
			},
		})
	end,

	keys = {
		-- NES: navigate/apply suggestions (Tab is taken by bufferline)
		{
			"<A-]>",
			function() require("sidekick").nes_jump_or_apply() end,
			desc = "NES: goto/apply next suggestion",
		},
		{
			"<A-[>",
			function() require("sidekick").nes_prev() end,
			desc = "NES: previous suggestion",
		},
		{
			"<leader>an",
			function() require("sidekick").nes_toggle() end,
			desc = "NES: toggle",
		},
		{
			"<leader>af",
			function() require("sidekick").nes_fetch() end,
			desc = "NES: fetch suggestions",
		},
		{
			"<leader>ax",
			function() require("sidekick").nes_clear() end,
			desc = "NES: clear suggestions",
		},

		-- CLI focus/toggle
		{
			"<c-.>",
			function() require("sidekick.cli").focus() end,
			desc = "Sidekick: switch focus",
			mode = { "n", "v" },
		},
		{
			"<leader>aa",
			function() require("sidekick.cli").toggle({ focus = true }) end,
			desc = "Sidekick: toggle CLI",
			mode = { "n", "v" },
		},

		-- AI providers
		{
			"<leader>ac",
			function() require("sidekick.cli").toggle({ name = "claude", focus = true }) end,
			desc = "Sidekick: Claude",
			mode = { "n", "v" },
		},
		{
			"<leader>am",
			function() require("sidekick.cli").toggle({ name = "gemini", focus = true }) end,
			desc = "Sidekick: Gemini",
			mode = { "n", "v" },
		},
		{
			"<leader>ag",
			function() require("sidekick.cli").toggle({ name = "grok", focus = true }) end,
			desc = "Sidekick: Grok",
			mode = { "n", "v" },
		},
		{
			"<leader>ao",
			function() require("sidekick.cli").toggle({ name = "copilot", focus = true }) end,
			desc = "Sidekick: Copilot",
			mode = { "n", "v" },
		},

		-- Prompts and session
		{
			"<leader>ap",
			function() require("sidekick.cli").prompt() end,
			desc = "Sidekick: prompt picker",
			mode = { "n", "v" },
		},
		{
			"<leader>as",
			function() require("sidekick.cli").select() end,
			desc = "Sidekick: select AI tool",
			mode = { "n", "v" },
		},
		{
			"<leader>ad",
			function() require("sidekick.cli").close() end,
			desc = "Sidekick: close session (clears history)",
			mode = { "n", "v" },
		},

		-- Health
		{
			"<leader>ah",
			"<cmd>checkhealth sidekick<CR>",
			desc = "Sidekick: health check",
		},
	},
}
