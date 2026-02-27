return {
	"renerocksai/telekasten.nvim",
	dependencies = {
		"nvim-telescope/telescope.nvim",
		"nvim-lua/plenary.nvim",
	},
	config = function()
		-- CRITICAL: Normalize path to forward slashes for Windows compatibility
		-- This ensures path matching works correctly when Telescope returns forward-slash paths
		local home = vim.fn.expand("~/zettelkasten"):gsub("\\", "/")

		require("telekasten").setup({
			home = home,

			-- Основные папки
			dailies = home .. "/daily",
			weeklies = home .. "/weekly",
			templates = home .. "/templates",

			-- Формат имени файлов
			extension = ".md",

			-- Формат даты для daily notes
			dailies_create_nonexisting = true,
			weeklies_create_nonexisting = true,

			-- Шаблон для новых заметок
			template_new_note = home .. "/templates/new_note.md",
			template_new_daily = home .. "/templates/daily.md",
			template_new_weekly = home .. "/templates/weekly.md",

			-- Автоматическое создание заголовка
			new_note_filename = "title",
			uuid_type = "%Y%m%d%H%M",
			uuid_sep = "-",

			-- Настройки вставки ссылок
			follow_creates_nonexisting = true,

			-- Автокоррекция при вставке ссылок
			subdirs_in_links = true,

			-- Настройки календаря
			calendar_opts = {
				weeknm = 4,
				calendar_monday = 1,
				calendar_mark = "left-fit",
			},

			-- Интеграция с Telescope
			plug_into_calendar = true,
			calendar_monday = 1,

			-- Настройки изображений
			image_subdir = "img",

			-- Команда для вставки изображений из буфера обмена (PowerShell для Windows)
			image_paste_command = "pwsh -command \"Get-Clipboard -Format Image | ForEach-Object { $_.Save('%s') }\"",

			-- Синтаксис ссылок
			media_previewer = "telescope-media-files",

			-- Windows-specific: use 'start' command to open URLs/files
			follow_url_fallback = vim.fn.has("win32") == 1 and function(url)
				vim.fn.jobstart({ "cmd.exe", "/c", "start", '""', url }, { detach = true })
			end or nil,
		})

		-- Keymaps
		local keymap = vim.keymap

		-- Основные команды
		keymap.set("n", "<leader>zf", "<cmd>Telekasten find_notes<cr>", { desc = "Find notes" })
		keymap.set("n", "<leader>zg", "<cmd>Telekasten search_notes<cr>", { desc = "Search in notes" })
		keymap.set("n", "<leader>zd", "<cmd>Telekasten goto_today<cr>", { desc = "Go to today's note" })
		keymap.set("n", "<leader>zz", "<cmd>Telekasten follow_link<cr>", { desc = "Follow link" })
		keymap.set("n", "<leader>zn", "<cmd>Telekasten new_note<cr>", { desc = "New note" })
		keymap.set("n", "<leader>zc", "<cmd>Telekasten show_calendar<cr>", { desc = "Show calendar" })
		keymap.set("n", "<leader>zb", "<cmd>Telekasten show_backlinks<cr>", { desc = "Show backlinks" })
		keymap.set("n", "<leader>zI", "<cmd>Telekasten insert_img_link<cr>", { desc = "Insert image link" })

		-- Работа с тегами и ссылками
		keymap.set("n", "<leader>zt", "<cmd>Telekasten show_tags<cr>", { desc = "Show tags" })
		-- Removed duplicate <leader>z# (same as <leader>zt)
		keymap.set("n", "<leader>zT", "<cmd>Telekasten goto_thisweek<cr>", { desc = "Go to this week" })
		-- Removed duplicate <leader>zw (same as <leader>zT)
		keymap.set("n", "<leader>zW", "<cmd>Telekasten find_weekly_notes<cr>", { desc = "Find weekly notes" })

		-- Вставка ссылок
		keymap.set("n", "<leader>zl", "<cmd>Telekasten insert_link<cr>", { desc = "Insert link" })
		keymap.set("i", "[[", "<cmd>Telekasten insert_link<cr>", { desc = "Insert link" })

		-- Панель управления
		keymap.set("n", "<leader>zp", "<cmd>Telekasten panel<cr>", { desc = "Command panel" })

		-- Переименование
		keymap.set("n", "<leader>zr", "<cmd>Telekasten rename_note<cr>", { desc = "Rename note" })

		-- Просмотр медиа
		keymap.set("n", "<leader>zm", "<cmd>Telekasten preview_img<cr>", { desc = "Preview image" })
		keymap.set("n", "<leader>zi", "<cmd>Telekasten paste_img_and_link<cr>", { desc = "Paste image and link" })

		-- Навигация
		keymap.set("n", "<leader>z[", "<cmd>Telekasten toggle_todo<cr>", { desc = "Toggle todo" })

		-- Открытие заметок в splits
		keymap.set("n", "<leader>zs", function()
			vim.cmd("vsplit")
			vim.cmd("Telekasten find_notes")
		end, { desc = "Find notes in vertical split" })

		keymap.set("n", "<leader>zh", function()
			vim.cmd("split")
			vim.cmd("Telekasten find_notes")
		end, { desc = "Find notes in horizontal split" })

		-- Setup keybindings for telekasten files (including after filetype change)
		vim.api.nvim_create_autocmd("FileType", {
			pattern = { "telekasten", "markdown", "markdown.telekasten" },
			callback = function()
				local bufnr = vim.api.nvim_get_current_buf()
				local filepath = vim.api.nvim_buf_get_name(bufnr)

				-- Check if file is in zettelkasten directory
				if filepath:match(vim.fn.expand("~/zettelkasten"):gsub("\\", "/")) then
					-- Telekasten wiki-style navigation [[link]]
					vim.keymap.set(
						"n",
						"gf",
						"<cmd>Telekasten follow_link<cr>",
						{ buffer = bufnr, desc = "Follow link" }
					)
					vim.keymap.set(
						"n",
						"<CR>",
						"<cmd>Telekasten follow_link<cr>",
						{ buffer = bufnr, desc = "Follow link (Enter)" }
					)

					-- Enhanced gx for markdown links [text](#anchor) or [text](url)
					vim.keymap.set("n", "gx", function()
						local line = vim.api.nvim_get_current_line()
						local col = vim.api.nvim_win_get_cursor(0)[2] + 1

						-- Check for markdown link: [text](link)
						local link_pattern = "%[.-%]%((.-)%)"
						for link in line:gmatch(link_pattern) do
							if link:match("^#") then
								-- Internal anchor link - jump to heading
								local anchor = link:sub(2) -- remove #
								-- Convert anchor format: "резервы-под-ожидаемые-убытки-ecl" -> search pattern
								local search_pattern = anchor:gsub("%-", "[ -]")

								-- Try to find the heading (case insensitive)
								local found =
									vim.fn.search("^#\\+\\s\\+.*" .. vim.fn.escape(search_pattern, "\\"), "wi")
								if found == 0 then
									print("Heading not found: " .. anchor)
								end
								return
							elseif link:match("^https?://") then
								-- External URL - open in browser (Windows)
								vim.fn.jobstart({ "cmd.exe", "/c", "start", '""', link }, { detach = true })
								return
							end
						end

						-- Check for wiki-style link [[...]]
						if line:match("%[%[.-%]%]") then
							vim.cmd("Telekasten follow_link")
							return
						end

						-- Default: try telekasten follow_link
						vim.cmd("Telekasten follow_link")
					end, { buffer = bufnr, desc = "Follow markdown/wiki link" })
				end
			end,
		})

		-- Change filetype from 'telekasten' to 'markdown.telekasten' after telekasten sets it
		-- This allows markdown plugins to work while preserving telekasten functionality
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "telekasten",
			callback = function()
				vim.bo.filetype = "markdown.telekasten"
			end,
		})
	end,
}
