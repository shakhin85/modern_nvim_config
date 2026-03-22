-- Shared pythonPath: venv-selector → CONDA → .venv → system
local function pythonPath()
	local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
	if venv then
		return venv .. "/bin/python"
	end
	local cwd_venv = vim.fn.getcwd() .. "/.venv/bin/python"
	if vim.fn.executable(cwd_venv) == 1 then
		return cwd_venv
	end
	return vim.fn.exepath("python3") or "python3"
end

-- Exception breakpoints cycle state
local exception_state = 1
local exception_filters = {
	{ "uncaught" },
	{ "uncaught", "raised" },
	{},
}
local exception_labels = { "uncaught", "uncaught + raised", "none" }

return {
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"jay-babu/mason-nvim-dap.nvim",
			"theHamsta/nvim-dap-virtual-text",
		},
		config = function()
			local dap = require("dap")
			local widgets = require("dap.ui.widgets")
			local keymap = vim.keymap

			-- Signs
			vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticSignError" })
			vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticSignWarn" })
			vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticSignInfo", linehl = "Visual" })
			vim.fn.sign_define("DapBreakpointRejected", { text = "○", texthl = "DiagnosticSignHint" })

			-- Exception breakpoints: auto-enable uncaught for all adapters
			dap.defaults.fallback.exception_breakpoints = { "uncaught" }

			-- === Adapters ===

			-- Python (debugpy via mason)
			dap.adapters.python = {
				type = "executable",
				command = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python",
				args = { "-m", "debugpy.adapter" },
			}

			dap.configurations.python = {
				{
					type = "python",
					request = "launch",
					name = "Launch file",
					program = "${file}",
					pythonPath = pythonPath,
					justMyCode = false,
					console = "integratedTerminal",
				},
				{
					type = "python",
					request = "launch",
					name = "Debug pytest (file)",
					module = "pytest",
					args = { "${file}", "-v", "--no-header", "-rN" },
					pythonPath = pythonPath,
					justMyCode = false,
					console = "integratedTerminal",
				},
				{
					type = "python",
					request = "launch",
					name = "Debug pytest (all)",
					module = "pytest",
					args = { "-v", "--no-header", "-rN" },
					pythonPath = pythonPath,
					justMyCode = false,
					console = "integratedTerminal",
				},
				{
					type = "python",
					request = "launch",
					name = "Debug module (-m)",
					module = function()
						return vim.fn.input("Module name: ")
					end,
					pythonPath = pythonPath,
					justMyCode = false,
					console = "integratedTerminal",
				},
			}

			-- JavaScript / TypeScript (js-debug-adapter)
			local js_debug_path = vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter"

			dap.adapters["pwa-node"] = {
				type = "server",
				host = "localhost",
				port = "${port}",
				executable = {
					command = "node",
					args = { js_debug_path .. "/js-debug/src/dapDebugServer.js", "${port}" },
				},
			}

			for _, lang in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
				dap.configurations[lang] = {
					{
						type = "pwa-node",
						request = "launch",
						name = "Launch file",
						program = "${file}",
						cwd = "${workspaceFolder}",
					},
					{
						type = "pwa-node",
						request = "attach",
						name = "Attach to process",
						processId = require("dap.utils").pick_process,
						cwd = "${workspaceFolder}",
					},
				}
			end

			-- Go (delve adapter auto-configured by mason-nvim-dap)
			dap.configurations.go = {
				{
					type = "delve",
					name = "Debug",
					request = "launch",
					program = "${file}",
				},
				{
					type = "delve",
					name = "Debug test (go.mod)",
					request = "launch",
					mode = "test",
					program = "./${relativeFileDirname}",
				},
			}

			-- === Keymaps ===

			-- Execution flow — F-keys
			keymap.set("n", "<F5>", dap.continue, { desc = "DAP: Continue / Launch" })
			keymap.set("n", "<F10>", dap.step_over, { desc = "DAP: Step over" })
			keymap.set("n", "<F11>", dap.step_into, { desc = "DAP: Step into" })
			keymap.set("n", "<F12>", dap.step_out, { desc = "DAP: Step out" })

			-- Breakpoints
			keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "DAP: toggle breakpoint" })
			keymap.set("n", "<leader>dB", function()
				dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
			end, { desc = "DAP: conditional breakpoint" })
			keymap.set("n", "<leader>dp", function()
				dap.set_breakpoint(nil, nil, vim.fn.input("Log message: "))
			end, { desc = "DAP: logpoint" })

			-- Inspect
			keymap.set({ "n", "v" }, "<leader>dh", widgets.hover, { desc = "DAP: hover value" })
			keymap.set("n", "<leader>de", function()
				local expr = vim.fn.input("Expression: ")
				if expr ~= "" then
					widgets.hover(expr)
				end
			end, { desc = "DAP: evaluate expression" })

			-- Session control
			keymap.set("n", "<leader>dr", dap.restart, { desc = "DAP: restart" })
			keymap.set("n", "<leader>dt", dap.terminate, { desc = "DAP: terminate" })
			keymap.set("n", "<leader>dl", dap.run_last, { desc = "DAP: run last" })
			keymap.set("n", "<leader>dc", dap.run_to_cursor, { desc = "DAP: run to cursor" })

			-- Exception breakpoints cycle
			keymap.set("n", "<leader>dx", function()
				exception_state = exception_state % #exception_filters + 1
				dap.set_exception_breakpoints(exception_filters[exception_state])
				vim.notify("Exception breakpoints: " .. exception_labels[exception_state])
			end, { desc = "DAP: cycle exception breakpoints" })
		end,
	},
	{
		"jay-babu/mason-nvim-dap.nvim",
		dependencies = "williamboman/mason.nvim",
		opts = {
			ensure_installed = { "python", "js", "codelldb", "delve" },
			handlers = {},
		},
	},
	{
		"theHamsta/nvim-dap-virtual-text",
		opts = {
			commented = true,
		},
	},
}
