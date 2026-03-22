# Sidekick.nvim Config Redesign — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers-extended-cc:subagent-driven-development (if subagents available) or superpowers-extended-cc:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite sidekick.lua to match official sidekick.nvim API, fixing broken prompts, NES, picker, and keymaps.

**Architecture:** Single file rewrite — replace `lua/shako/plugins/sidekick.lua` with a clean config using only official API. No custom functions, no reimplemented pickers.

**Tech Stack:** Lua, lazy.nvim, sidekick.nvim, copilot.lua, Telescope (via built-in picker)

**Spec:** `docs/superpowers/specs/2026-03-22-sidekick-config-redesign.md`

---

## Chunk 1: Full Rewrite

### Task 1: Rewrite sidekick.lua

**Files:**
- Modify: `lua/shako/plugins/sidekick.lua` (full rewrite)

- [ ] **Step 1: Replace entire file with new config**

Replace the full content of `lua/shako/plugins/sidekick.lua` with:

```lua
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
	changes     = "Can you review my changes?",
	review      = "Can you review {file} for any issues or improvements?",
	explain     = "Explain {this}",
	diagnostics = "Can you help me fix the diagnostics in {file}?\n{diagnostics}",
	fix         = "Can you fix {this}?\n{diagnostics}",
	debug       = "Help debug {this}",
	optimize    = "How can {this} be optimized?",
	simplify    = "Simplify {this}",
	refactor    = "Refactor {this}",
	errors      = "Add comprehensive error handling with proper logging to {this}",
	types       = "Add proper type annotations/hints to {this}",
	document    = "Add documentation to {function|line}",
	tests       = "Can you write tests for {this}?",
	edge_cases  = "What edge cases and failure modes should be tested for {this}?",
	mocks       = "Generate mocks and fixtures for testing {this}",
	commit      = "Write a concise conventional commit message for these changes",
	pr          = "Write a pull request description with summary and test plan",
	security    = "Review {this} for security vulnerabilities (OWASP, injections, secrets)",
	dockerfile  = "Review this Dockerfile for best practices, security, and layer optimization:\n{file}",
	ci          = "Review this CI/CD config and suggest improvements:\n{file}",
	logging     = "Add structured logging with appropriate log levels to {this}",
}

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
			nes = {
				enabled = true,
				debounce = 100,
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
					},
					split = {
						width = 80,
						height = 20,
					},
					keys = {
						hide_n         = { "q", "hide", mode = "n" },
						stopinsert_esc = { "<Esc><Esc>", "stopinsert", mode = "t" },
					},
				},
				mux = {
					backend = "zellij",
					enabled = vim.env.ZELLIJ ~= nil,
					create = "terminal",
				},
				picker = "telescope",
				prompts = prompts,
			},

			copilot = {
				status = { enabled = true },
			},
		})
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
			function() require("sidekick").nes_jump_or_apply() end,
			desc = "NES: goto/apply next suggestion",
		},
		{
			"<leader>an",
			function() require("sidekick.nes").toggle() end,
			desc = "NES: toggle",
		},
		{
			"<leader>au",
			function() require("sidekick.nes").update() end,
			desc = "NES: fetch suggestions",
		},
		{
			"<leader>ax",
			function() require("sidekick.nes").clear() end,
			desc = "NES: clear suggestions",
		},

		-- CLI focus/toggle
		{
			"<c-.>",
			function() require("sidekick.cli").focus() end,
			desc = "Sidekick: switch focus",
			mode = { "n", "t", "i", "x" },
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

		-- Prompts and context
		{
			"<leader>ap",
			function() require("sidekick.cli").prompt() end,
			desc = "Sidekick: prompt picker",
			mode = { "n", "x" },
		},
		{
			"<leader>at",
			function() require("sidekick.cli").send({ msg = "{this}" }) end,
			desc = "Sidekick: send this",
			mode = { "n", "x" },
		},
		{
			"<leader>af",
			function() require("sidekick.cli").send({ msg = "{file}" }) end,
			desc = "Sidekick: send file",
		},
		{
			"<leader>av",
			function() require("sidekick.cli").send({ msg = "{selection}" }) end,
			desc = "Sidekick: send selection",
			mode = { "x" },
		},

		-- Session
		{
			"<leader>as",
			function() require("sidekick.cli").select() end,
			desc = "Sidekick: select AI tool",
			mode = { "n", "v" },
		},
		{
			"<leader>ad",
			function() require("sidekick.cli").close() end,
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
```

- [ ] **Step 2: Verify syntax**

Run: `nvim --headless -c "luafile lua/shako/plugins/sidekick.lua" -c "q" 2>&1`
Expected: No syntax errors

- [ ] **Step 3: Commit**

```bash
git add lua/shako/plugins/sidekick.lua
git commit -m "refactor(sidekick): rewrite config to match official API

- Remove adaptive() function — {this} already handles normal/visual modes
- Remove custom Telescope picker — use built-in cli.prompt() with picker=telescope
- Fix NES: trigger events, clear events, signs, jumplist, diff options
- Fix keymaps: correct module paths, remove non-existent API calls
- Add missing keymaps: <tab>, <leader>at, <leader>af, <leader>av, <leader>au
- Remove <A-[> (nes_prev doesn't exist)"
```

- [ ] **Step 4: Update sidekick.nvim plugin to latest**

Run: `nvim --headless -c "Lazy update sidekick.nvim" -c "q"`
This ensures the installed version matches the GitHub source we designed against.

- [ ] **Step 5: Verify health**

Open Neovim and run `:checkhealth sidekick`
Expected: All checks pass, no errors about missing functions or config options.
