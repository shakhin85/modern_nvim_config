return {
	"iamcco/markdown-preview.nvim",
	cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
	build = ":call mkdp#util#install()",
	ft = { "markdown" },
	keys = {
		{ "<leader>mb", "<cmd>MarkdownPreviewToggle<CR>", desc = "Toggle markdown browser preview" },
	},
	init = function()
		vim.g.mkdp_auto_close = 1
		vim.g.mkdp_combine_preview = 1
	end,
}
