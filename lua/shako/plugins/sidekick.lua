-- Sidekick.nvim - AI Assistant Integration
--
-- WORKFLOW:
--   1. Open AI tool: <leader>ac (Claude), <leader>am (Gemini), <leader>ag (Grok), <leader>ao (Copilot)
--   2. Chat preserves history — hide/show window keeps same session
--   3. Start fresh: <leader>ad (close session), then reopen
--   4. Prompts: <leader>ap opens Telescope picker with custom prompts
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

-- When called from visual mode ctx.range is set → use {selection} (inline text).
-- When called from normal mode ctx.range is nil  → use {this} (positional file ref).
local function adaptive(prefix)
	return function(ctx)
		if ctx.range then
			return prefix .. "\n{selection}"
		end
		return prefix .. "\n{this}"
	end
end

-- Single source of truth for all prompts
local prompts = {
	changes     = "Can you review my changes?",
	review      = "Can you review {file} for any issues or improvements?",
	explain     = adaptive("Explain the following code in detail:"),
	diagnostics = "Can you help me fix the diagnostics in {file}?\n{diagnostics}",
	fix         = "Fix this issue:\n{diagnostics}\n\nCode context:\n{this}",
	debug       = adaptive("Help debug this code:"),
	optimize    = adaptive("Suggest optimizations for:"),
	simplify    = adaptive("Simplify this code:"),
	refactor    = adaptive("Refactor the following code:"),
	errors      = adaptive("Add comprehensive error handling with proper logging to:"),
	types       = adaptive("Add proper type annotations/hints to:"),
	document    = adaptive("Generate comprehensive documentation for:"),
	tests       = adaptive("Generate comprehensive unit tests for:"),
	edge_cases  = adaptive("What edge cases and failure modes should be tested for:"),
	mocks       = adaptive("Generate mocks and fixtures for testing:"),
	commit      = adaptive("Write a concise conventional commit message for these changes:"),
	pr          = adaptive("Write a pull request description with summary and test plan for:"),
	security    = adaptive("Review this code for security vulnerabilities (OWASP, injections, secrets):"),
	dockerfile  = "Review this Dockerfile for best practices, security, and layer optimization:\n{file}",
	ci          = "Review this CI/CD config and suggest improvements:\n{file}",
	logging     = adaptive("Add structured logging with appropriate log levels to:"),
}

-- from_visual=true: restore gv so sidekick captures {selection}/{this}/{diagnostics} itself
local function prompt_telescope(from_visual)
	local pickers    = require("telescope.pickers")
	local finders    = require("telescope.finders")
	local conf       = require("telescope.config").values
	local actions    = require("telescope.actions")
	local state      = require("telescope.actions.state")
	local previewers = require("telescope.previewers")

	local results = {}
	for key, text in pairs(prompts) do
		table.insert(results, { key = key, text = text })
	end
	table.sort(results, function(a, b) return a.key < b.key end)

	pickers.new({
		layout_strategy = "horizontal",
		layout_config   = { width = 0.85, height = 0.6, preview_width = 0.6 },
	}, {
		prompt_title = "Sidekick Prompts",
		finder = finders.new_table({
			results = results,
			entry_maker = function(entry)
				return {
					value   = entry,
					display = entry.key,
					ordinal = entry.key,
				}
			end,
		}),
		sorter = conf.generic_sorter({}),
		previewer = previewers.new_buffer_previewer({
			title = "Prompt",
			define_preview = function(self, entry)
				local text = type(entry.value.text) == "function"
					and "(adaptive) visual → {selection} / normal → {this}"
					or entry.value.text
				vim.api.nvim_buf_set_lines(
					self.state.bufnr, 0, -1, false,
					vim.split(text, "\n")
				)
			end,
		}),
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				actions.close(prompt_bufnr)
				local sel = state.get_selected_entry()
				-- Defer until Telescope has fully closed and original window has focus,
				-- otherwise gv runs in the wrong buffer and {selection} is empty.
				vim.schedule(function()
					if from_visual then
						vim.cmd("normal! gv")
					end
					require("sidekick.cli").send({ prompt = sel.value.key, focus = true })
				end)
			end)
			return true
		end,
	}):find()
end

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
				prompts = prompts,
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
			function() prompt_telescope(false) end,
			desc = "Sidekick: prompt picker",
			mode = "n",
		},
		{
			"<leader>ap",
			function() prompt_telescope(true) end,
			desc = "Sidekick: prompt picker (visual)",
			mode = "v",
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
