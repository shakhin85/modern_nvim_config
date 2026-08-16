-- Единая навигация по сплитам nvim и панелям zellij (resize панелей zellij — Alt +/-/= самого zellij).
-- На краю окна nvim фокус уходит в соседнюю zellij-панель (`zellij action move-focus`).
-- Обратно zellij шлёт Ctrl+hjkl в nvim, поэтому zellij их не биндит (см. ~/.config/zellij/config.kdl).
return {
	"mrjones2014/smart-splits.nvim",
	lazy = false,
	opts = {
		at_edge = "stop",
		multiplexer_integration = "zellij",
		disable_multiplexer_nav_when_zoomed = true,
	},
	keys = {
		{ "<C-h>", function() require("smart-splits").move_cursor_left() end, desc = "Move to left window/pane" },
		{ "<C-j>", function() require("smart-splits").move_cursor_down() end, desc = "Move to window/pane below" },
		{ "<C-k>", function() require("smart-splits").move_cursor_up() end, desc = "Move to window/pane above" },
		{ "<C-l>", function() require("smart-splits").move_cursor_right() end, desc = "Move to right window/pane" },
	},
}
