-- Sidekick.nvim - AI Assistant Integration
--
-- WORKFLOW:
--   1. Open AI tool: <leader>ac (Claude), <leader>am (Gemini), <leader>ag (Grok), <leader>ao (Copilot)
--   2. Chat preserves history — hide/show window keeps same session
--   3. Start fresh: <leader>ad (close session), then reopen
--   4. Prompts: <leader>ap opens built-in picker with prompts
--   5. Send context: <leader>at (this), <leader>af (file), <leader>av (selection)
--
-- TEMPLATE VARIABLES (usable in prompts):
--   {this}           — adaptive: {position} in normal mode, appends {selection} in visual
--   {file}           — current file path
--   {selection}      — visually selected text
--   {position}       — cursor position in current file
--   {diagnostics}    — LSP errors/warnings in current file
--   {diagnostics_all}— diagnostics across all open files
--   {function}       — current function (requires treesitter-textobjects)
--   {class}          — current class (requires treesitter-textobjects)
--   {line}           — current line content
--   {buffers}        — content from open buffers
--   {quickfix}       — quickfix list entries

-- Custom prompts (merged with sidekick defaults)
local prompts = {
	changes = "Can you review my changes?",
	review = "Can you review {file} for any issues or improvements?",
	explain = "Explain {this}",
	diagnostics = "Can you help me fix the diagnostics in {file}?\n{diagnostics}",
	fix = "Can you fix {this}?\n{diagnostics}",
	debug = "Help debug {this}",
	optimize = "How can {this} be optimized?",
	simplify = "Simplify {this}",
	refactor = "Refactor {this}",
	errors = "Add comprehensive error handling with proper logging to {this}",
	types = "Add proper type annotations/hints to {this}",
	document = "Add documentation to {function|line}",
	tests = "Can you write tests for {this}?",
	edge_cases = "What edge cases and failure modes should be tested for {this}?",
	mocks = "Generate mocks and fixtures for testing {this}",
	commit = "Write a concise conventional commit message for these changes",
	pr = "Write a pull request description with summary and test plan",
	security = "Review {this} for security vulnerabilities (OWASP, injections, secrets)",
	dockerfile = "Review this Dockerfile for best practices, security, and layer optimization:\n{file}",
	ci = "Review this CI/CD config and suggest improvements:\n{file}",
	logging = "Add structured logging with appropriate log levels to {this}",
}

return {
	"folke/sidekick.nvim",
	event = "VeryLazy",
	dependencies = {
		{
			"zbirenbaum/copilot.lua",
			enabled = false, -- Copilot не доступен в регионе; NES всё равно не работает
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
			nes = {
				enabled = false, -- зависит от Copilot, недоступного в регионе
				debounce = 50,
				trigger = {
					events = { "ModeChanged i:n", "TextChanged", "User SidekickNesDone" },
				},
				clear = {
					events = { "TextChangedI", "InsertEnter" },
					esc = true,
				},
				diff = {
					inline = "words",
					show = "always",
				},
				signs = true,
				jumplist = true,
			},

			cli = {
				watch = true,
				win = {
					layout = "float",
					float = {
						width = 0.9,
						height = 0.85,
						border = "rounded", -- без него float берёт пустой 'winborder' и рамки нет
					},
					split = {
						width = 80,
						height = 20,
					},
					keys = {
						hide_n = { "q", "hide", mode = "n" },
						stopinsert_esc = { "<Esc><Esc>", "stopinsert", mode = "t" },
					},
				},
				mux = {
					backend = "zellij",
					enabled = vim.env.ZELLIJ ~= nil,
					create = "terminal",
				},
				picker = "snacks",
				prompts = prompts,
				tools = {
					-- claude поднимается через dgc: лаунчер dual-graph сканирует проект
					-- и пробрасывает флаги (--resume/--continue) дальше в claude
					claude = {
						cmd = { "dgc" },
						is_proc = "\\<dgc\\>\\|dual_graph_launch\\|\\<claude\\>",
					},
				},
			},

			copilot = {
				status = { enabled = false },
			},
		})

		-- opencode не используем, а его session-бэкенд на каждый список сессий
		-- зовёт `lsof -iTCP` (~2 с на этом хосте) — <leader>ap открывался с задержкой.
		-- Убрать до первого Config.tools(): sk/cli/opencode.lua регистрирует бэкенд при загрузке.
		require("sidekick.config").cli.tools.opencode = nil

		-- WORKAROUND: sidekick считает терминал готовым, когда вывод >5 строк и
		-- замер на 500 мс (или через 5 с). dgc печатает баннер и ~5 с поднимает
		-- MCP до старта claude — текст из <leader>ap/<leader>av уходил в dgc.
		-- Для claude ждём заголовок терминала «Claude Code»: его ставит сам claude.
		local Terminal = require("sidekick.cli.terminal")
		local on_ready = Terminal.on_ready
		function Terminal:on_ready()
			if self.tool.name ~= "claude" then
				return on_ready(self)
			end
			local deadline = vim.uv.now() + 30000
			local timer = assert(vim.uv.new_timer())
			timer:start(0, 100, vim.schedule_wrap(function()
				local title = self:buf_valid() and vim.b[self.buf].term_title or ""
				if title:find("Claude Code", 1, true) or vim.uv.now() > deadline or not self:buf_valid() then
					timer:stop()
					timer:close()
					-- после заголовка claude ещё ~300 мс включает raw-режим ввода
					vim.defer_fn(function() on_ready(self) end, 500)
				end
			end))
		end
	end,

	keys = {
		-- NES: navigate/apply suggestions
		{
			"<tab>",
			function()
				if not require("sidekick").nes_jump_or_apply() then
					return "<Tab>"
				end
			end,
			expr = true,
			desc = "NES: goto/apply next suggestion",
		},
		{
			"<A-]>",
			function()
				require("sidekick").nes_jump_or_apply()
			end,
			desc = "NES: goto/apply next suggestion",
		},
		{
			"<leader>an",
			function()
				require("sidekick.nes").toggle()
			end,
			desc = "NES: toggle",
		},
		{
			"<leader>au",
			function()
				require("sidekick.nes").update()
			end,
			desc = "NES: fetch suggestions",
		},
		{
			"<leader>ax",
			function()
				require("sidekick.nes").clear()
			end,
			desc = "NES: clear suggestions",
		},

		-- CLI focus/toggle
		{
			"<c-.>",
			function()
				require("sidekick.cli").focus()
			end,
			desc = "Sidekick: switch focus",
			mode = { "n", "t", "i", "x" },
		},
		{
			"<leader>aa",
			function()
				require("sidekick.cli").toggle({ focus = true })
			end,
			desc = "Sidekick: toggle CLI",
			mode = { "n", "v" },
		},

		-- AI providers
		{
			"<leader>ac",
			function()
				require("sidekick.cli").toggle({ name = "claude", focus = true })
			end,
			desc = "Sidekick: Claude",
			mode = { "n", "v" },
		},
		{
			"<leader>am",
			function()
				require("sidekick.cli").toggle({ name = "gemini", focus = true })
			end,
			desc = "Sidekick: Gemini",
			mode = { "n", "v" },
		},
		{
			"<leader>ag",
			function()
				require("sidekick.cli").toggle({ name = "grok", focus = true })
			end,
			desc = "Sidekick: Grok",
			mode = { "n", "v" },
		},
		{
			"<leader>ao",
			function()
				require("sidekick.cli").toggle({ name = "copilot", focus = true })
			end,
			desc = "Sidekick: Copilot",
			mode = { "n", "v" },
		},

		-- Prompts and context
		{
			"<leader>ap",
			function()
				require("sidekick.cli").prompt()
			end,
			desc = "Sidekick: prompt picker",
			mode = { "n", "x" },
		},
		{
			"<leader>at",
			function()
				require("sidekick.cli").send({ msg = "{this}" })
			end,
			desc = "Sidekick: send this",
			mode = { "n", "x" },
		},
		{
			"<leader>af",
			function()
				require("sidekick.cli").send({ msg = "{file}" })
			end,
			desc = "Sidekick: send file",
		},
		{
			"<leader>av",
			function()
				require("sidekick.cli").send({ msg = "{selection}" })
			end,
			desc = "Sidekick: send selection",
			mode = { "x" },
		},

		-- Session
		{
			"<leader>as",
			function()
				require("sidekick.cli").select()
			end,
			desc = "Sidekick: select AI tool",
			mode = { "n", "v" },
		},
		{
			"<leader>ad",
			function()
				require("sidekick.cli").close()
			end,
			desc = "Sidekick: close session",
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
