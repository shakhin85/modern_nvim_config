return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		local harpoon = require("harpoon")

		harpoon:setup({
			settings = {
				save_on_toggle = true,
				sync_on_ui_close = true,
			},
		})

		local keymap = vim.keymap

		-- Add current file to list
		keymap.set("n", "<leader>a", function() harpoon:list():add() end, { desc = "Harpoon: add file" })

		-- Toggle quick menu
		keymap.set("n", "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = "Harpoon: menu" })

		-- Jump to file slots 1–4
		keymap.set("n", "<leader>1", function() harpoon:list():select(1) end, { desc = "Harpoon: file 1" })
		keymap.set("n", "<leader>2", function() harpoon:list():select(2) end, { desc = "Harpoon: file 2" })
		keymap.set("n", "<leader>3", function() harpoon:list():select(3) end, { desc = "Harpoon: file 3" })
		keymap.set("n", "<leader>4", function() harpoon:list():select(4) end, { desc = "Harpoon: file 4" })

		-- Cycle through harpoon list (avoiding [h/]h — owned by gitsigns for hunks)
		keymap.set("n", "<M-p>", function() harpoon:list():prev() end, { desc = "Harpoon: prev file" })
		keymap.set("n", "<M-n>", function() harpoon:list():next() end, { desc = "Harpoon: next file" })
	end,
}
