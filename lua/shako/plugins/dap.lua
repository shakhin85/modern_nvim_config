return {
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"jay-babu/mason-nvim-dap.nvim",
			"theHamsta/nvim-dap-virtual-text",
		},
		config = function()
			local dap = require("dap")
			local keymap = vim.keymap

			-- signs
			vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticSignError" })
			vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticSignWarn" })
			vim.fn.sign_define("DapStopped", { text = "▶", texthl = "DiagnosticSignInfo", linehl = "Visual" })
			vim.fn.sign_define("DapBreakpointRejected", { text = "○", texthl = "DiagnosticSignHint" })

			-- Python
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
					pythonPath = function()
						local venv = os.getenv("VIRTUAL_ENV") or os.getenv("CONDA_PREFIX")
						if venv then
							return venv .. "/bin/python"
						end
						return vim.fn.exepath("python3") or vim.fn.exepath("python") or "python"
					end,
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

			-- Keymaps
			-- Execution flow — F-keys
			keymap.set("n", "<F5>", dap.continue, { desc = "DAP: Continue / Launch" })
			keymap.set("n", "<F10>", dap.step_over, { desc = "DAP: Step over" })
			keymap.set("n", "<F11>", dap.step_into, { desc = "DAP: Step into" })
			keymap.set("n", "<F12>", dap.step_out, { desc = "DAP: Step out" })

			-- Breakpoints and session control — leader keys
			keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Toggle breakpoint" })
			keymap.set("n", "<leader>dB", function()
				dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
			end, { desc = "Set conditional breakpoint" })
			keymap.set("n", "<leader>dr", dap.restart, { desc = "DAP: Restart" })
			keymap.set("n", "<leader>dt", dap.terminate, { desc = "DAP: Terminate" })
			keymap.set("n", "<leader>dl", dap.run_last, { desc = "DAP: Run last" })
		end,
	},
	{
		"jay-babu/mason-nvim-dap.nvim",
		dependencies = "williamboman/mason.nvim",
		opts = {
			ensure_installed = { "python", "js" },
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
