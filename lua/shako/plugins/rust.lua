return {
	"mrcjkb/rustaceanvim",
	version = "^6",
	ft = { "rust" },
	config = function()
		vim.g.rustaceanvim = {
			server = {
				capabilities = require("blink.cmp").get_lsp_capabilities(),
			},
		}
	end,
}
