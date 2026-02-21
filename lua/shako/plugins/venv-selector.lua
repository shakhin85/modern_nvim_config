return {
	"linux-cultist/venv-selector.nvim",
	branch = "regexp",
	dependencies = {
		"neovim/nvim-lspconfig",
		"mfussenegger/nvim-dap",
		"nvim-telescope/telescope.nvim",
	},
	ft = "python",
	---@module "venv-selector"
	---@type VenvSelectorConfig
	opts = {
		options = {
			-- Auto-activate cached venv when opening a Python project
			enable_cached_venvs = true,
			-- Apply selected venv to integrated terminal buffers
			activate_venv_in_terminal = true,
			-- Set VIRTUAL_ENV / CONDA_PREFIX so dap.lua + neotest pick it up
			set_environment_variables = true,
			-- Notify when a venv is activated
			notify_user_on_venv_activation = true,
			-- Use telescope (already installed)
			picker = "telescope",
			-- Restart LSP after switching so basedpyright picks up the new interpreter
			on_venv_activate_callback = function()
				vim.cmd("LspRestart")
			end,
		},
	},
	keys = {
		{ "<leader>pv", "<cmd>VenvSelect<CR>",       ft = "python", desc = "Python: select venv" },
		{ "<leader>pc", "<cmd>VenvSelectCached<CR>", ft = "python", desc = "Python: activate cached venv" },
	},
}
