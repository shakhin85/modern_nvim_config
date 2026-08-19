-- Привязать буфер к базе. Одного b:db мало: vim-dadbod-completion наполняет кэш
-- схемы только по своему FileType-автокоманде, то есть до того, как b:db выставлен.
-- Без явного fetch() completion молчит — ни таблиц, ни колонок по алиасу.
local function attach_db(bufnr, url)
	vim.b[bufnr].db = url
	-- Через schedule: на FileType-событии lazy может ещё не успеть подгрузить
	-- vim-dadbod-completion (он ft-ленивый), и функции просто нет в этот тик.
	vim.schedule(function()
		if vim.api.nvim_buf_is_valid(bufnr) and vim.fn.exists("*vim_dadbod_completion#fetch") == 1 then
			vim.fn["vim_dadbod_completion#fetch"](bufnr)
		end
	end)
end

-- Запрос из буфера: выделение в visual-режиме, иначе весь буфер.
local function buffer_query()
	local lines
	if vim.fn.mode():match("[vV]") then
		vim.cmd([[normal! <Esc>]])
		lines = vim.api.nvim_buf_get_lines(0, vim.fn.line("'<") - 1, vim.fn.line("'>"), false)
	else
		lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	end
	local query = vim.trim(table.concat(lines, "\n")):gsub(";%s*$", "")
	return query ~= "" and query or nil
end

-- CSV-выгрузка: PG → psql \copy, MSSQL → sqlcmd -s,
local function csv_cmd(url, query, path)
	if url:match("^postgres") then
		return { "psql", "-w", "--dbname", url, "-c", ("\\copy (%s) to '%s' csv header"):format(query, path) }
	elseif url:match("^sqlserver") then
		local user, pass, host, port, db = url:match("^sqlserver://([^:/@]*):?([^/@]*)@?([^:/?]+):?(%d*)/([^?]+)")
		if not host then
			return nil, "Не разобрал sqlserver URL"
		end
		local cmd = { "sqlcmd", "-S", host .. (port ~= "" and ("," .. port) or ""), "-d", db, "-C", "-s", ",", "-W", "-Q", query, "-o", path }
		if user ~= "" then
			vim.list_extend(cmd, { "-U", user, "-P", pass })
		else
			table.insert(cmd, "-E")
		end
		return cmd
	end
	return nil, "CSV-экспорт поддержан для postgres/sqlserver"
end

-- Выгрузить запрос в CSV по пути path, дальше отдать управление on_done(path).
local function to_csv(path, on_done)
	local url = vim.b.db
	if not url then
		return vim.notify("b:db не задан (<leader>Ds)", vim.log.levels.WARN)
	end
	local query = buffer_query()
	if not query then
		return vim.notify("Пустой запрос", vim.log.levels.WARN)
	end
	local cmd, err = csv_cmd(url, query, path)
	if not cmd then
		return vim.notify(err, vim.log.levels.WARN)
	end
	vim.system(cmd, { text = true }, function(o)
		vim.schedule(function()
			if o.code == 0 then
				on_done(path)
			else
				vim.notify("Экспорт упал:\n" .. (o.stderr ~= "" and o.stderr or o.stdout), vim.log.levels.ERROR)
			end
		end)
	end)
end

local function export_csv()
	local default = vim.fn.expand("~") .. "/query-" .. os.date("%Y%m%d-%H%M%S") .. ".csv"
	vim.ui.input({ prompt = "CSV path: ", default = default, completion = "file" }, function(path)
		if path and path ~= "" then
			to_csv(path, function(p)
				vim.notify("CSV → " .. p)
			end)
		end
	end)
end

-- Результат в TUI-грид (сортировка/фильтр/сводка): visidata, иначе csvlens.
local function inspect_result()
	local viewer = vim.fn.executable("vd") == 1 and "vd" or (vim.fn.executable("csvlens") == 1 and "csvlens" or nil)
	if not viewer then
		return vim.notify("Нет ни vd (visidata), ни csvlens", vim.log.levels.WARN)
	end
	local path = vim.fn.tempname() .. ".csv"
	to_csv(path, function(p)
		vim.cmd("tabnew")
		vim.fn.jobstart({ viewer, p }, { term = true, on_exit = function()
			vim.schedule(function()
				vim.fn.delete(p)
			end)
		end })
		vim.cmd("startinsert")
	end)
end

return {
	{
		"tpope/vim-dadbod",
		lazy = true,
	},
	{
		"kristijanhusak/vim-dadbod-ui",
		dependencies = {
			"tpope/vim-dadbod",
			"kristijanhusak/vim-dadbod-completion",
		},
		cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
		keys = {
			{ "<leader>Du", "<cmd>DBUIToggle<CR>", desc = "Toggle DB UI" },
			{ "<leader>Da", "<cmd>DBUIAddConnection<CR>", desc = "Add DB connection" },
			{ "<leader>Df", "<cmd>DBUIFindBuffer<CR>", desc = "Find DB buffer" },
			{ "<leader>Dc", export_csv, mode = { "n", "x" }, desc = "Export query result to CSV" },
			{ "<leader>Dv", inspect_result, mode = { "n", "x" }, desc = "Inspect result in visidata/csvlens" },
			{
				"<leader>Ds",
				function()
					local keys = vim.tbl_keys(vim.g.dbs or {})
					table.sort(keys)
					local bufnr = vim.api.nvim_get_current_buf()
					vim.ui.select(keys, { prompt = "DB for this buffer:" }, function(k)
						if k then
							attach_db(bufnr, vim.g.dbs[k])
							vim.notify("b:db = " .. k .. " (схема подгружается)")
						end
					end)
				end,
				desc = "Select DB for current buffer",
			},
		},
		init = function()
			-- ~/.psqlrc (\timing, unicode borders) исполняется ПОСЛЕ флагов psql -A и ломает
			-- парсер dadbod-completion (схемы/колонки). Для psql, запущенных из nvim, rc не читаем.
			vim.env.PSQLRC = "/dev/null"
			vim.g.db_ui_use_nerd_fonts = 1
			vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/db_ui"
			vim.g.db_ui_execute_on_save = 0 -- :w не выполняет запрос; выполнять <leader>S / <leader>W
			vim.g.db_ui_show_database_icon = 1
			vim.g.db_ui_auto_execute_table_helpers = 1
			vim.g.db_ui_win_position = "left"
			vim.g.db_ui_winwidth = 35
			vim.g.db_ui_use_nvim_notify = 1
			vim.g.db_ui_table_helpers = {
				sqlserver = {
					List = "SELECT TOP 200 * FROM {optional_schema}{table}",
					Count = "SELECT COUNT(*) AS cnt FROM {optional_schema}{table}",
					Columns = "SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '{table}' ORDER BY ORDINAL_POSITION",
					Help = "EXEC sp_help '{optional_schema}{table}'",
				},
				postgresql = {
					Count = "SELECT count(*) AS cnt FROM {optional_schema}{table}",
					Sample = "SELECT * FROM {optional_schema}{table} ORDER BY random() LIMIT 20",
				},
			}
			-- Подключения — в git-ignored lua/shako/dbs.local.lua (см. dbs.local.lua.example)
			local ok, dbs = pcall(dofile, vim.fn.stdpath("config") .. "/lua/shako/dbs.local.lua")
			if ok and type(dbs) == "table" then
				vim.g.dbs = dbs
			end
			-- Обычный .sql-файл: привязать к дефолтной базе, чтобы completion знал схему
			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "sql", "mysql", "plsql" },
				callback = function(ev)
					if not vim.b[ev.buf].db and vim.g.dbs and vim.g.db_default then
						attach_db(ev.buf, vim.g.dbs[vim.g.db_default])
					end
					-- <leader>S из dadbod-ui живёт только внутри его буферов; в обычном
					-- .sql-файле выполнять запрос нечем, заводим сами: весь буфер в
					-- normal, выделение — в visual (та же логика, что у <leader>Dc/Dv).
					vim.keymap.set("n", "<leader>S", "<Cmd>%DB<CR>", { buffer = ev.buf, desc = "Execute buffer against b:db" })
					vim.keymap.set("x", "<leader>S", "db#op_exec()", { buffer = ev.buf, expr = true, desc = "Execute selection against b:db" })
				end,
			})
		end,
	},
	{
		"kristijanhusak/vim-dadbod-completion",
		dependencies = { "tpope/vim-dadbod" },
		ft = { "sql", "mysql", "plsql", "sqlite" },
	},
	-- Yank результата в JSON/CSV/XML прямо из dbout-буфера
	{
		"davesavic/dadbod-ui-yank",
		dependencies = { "kristijanhusak/vim-dadbod-ui" },
		cmd = { "DBUIYankAsCSV", "DBUIYankAsJSON", "DBUIYankAsXML" },
		keys = {
			{ "<leader>Dyc", "<cmd>DBUIYankAsCSV<CR>", desc = "Yank result as CSV" },
			{ "<leader>Dyj", "<cmd>DBUIYankAsJSON<CR>", desc = "Yank result as JSON" },
			{ "<leader>Dyx", "<cmd>DBUIYankAsXML<CR>", desc = "Yank result as XML" },
		},
		opts = {},
	},
	-- XLSX-выгрузка (только PostgreSQL: гоняет COPY через psql)
	{
		"tuliopaim/dadbod-export-xlsx.nvim",
		dependencies = { "tpope/vim-dadbod" },
		cmd = { "ExportXlsx", "WrapToCsv", "ExportXlsxBuild" },
		keys = { { "<leader>Dx", "<cmd>ExportXlsx<CR>", mode = { "n", "x" }, desc = "Export result to XLSX (PG)" } },
		config = function()
			require("dadbod_export_xlsx").setup({ keymap = false })
		end,
	},
	-- Редактируемый грид «как в DataGrip»: staged-мутации, фильтры, FK-навигация,
	-- ER-диаграмма, EXPLAIN человеческим языком, профилирование колонок.
	-- Коннекты не дублируем: :GripConnect принимает URL, берём его из vim.g.dbs.
	{
		"joryeugene/dadbod-grip.nvim",
		version = "*",
		cmd = { "Grip", "GripStart", "GripConnect", "GripSchema", "GripTables", "GripQuery", "GripHistory", "GripExplain", "GripProfile", "GripToggle" },
		keys = {
			{
				"<leader>Dg",
				function()
					local keys = vim.tbl_keys(vim.g.dbs or {})
					table.sort(keys)
					vim.ui.select(keys, { prompt = "Grip: подключиться к:" }, function(k)
						if k then
							-- Через Lua API, а не :GripConnect <url>: URL с паролем не должен
							-- попадать в историю команд, а оттуда в shada на диске.
							require("dadbod-grip.connections").switch(vim.g.dbs[k], k)
						end
					end)
				end,
				desc = "Grip: connect (grid UI)",
			},
			{ "<leader>DG", "<cmd>GripToggle<CR>", desc = "Grip: toggle windows" },
			{ "<leader>Dt", "<cmd>GripTables<CR>", desc = "Grip: table picker" },
			{ "<leader>Dh", "<cmd>GripHistory<CR>", desc = "Grip: query history" },
			{ "<leader>De", "<cmd>GripExplain<CR>", mode = { "n", "x" }, desc = "Grip: explain (Query Doctor)" },
			{ "<leader>Dp", "<cmd>GripProfile<CR>", desc = "Grip: profile table columns" },
		},
		opts = {
			picker = "snacks",
			limit = 200,
			timeout = 30000,
			completion = false, -- дополняем через blink + vim-dadbod-completion
			-- AI выключен намеренно: он прогревает схему на каждом коннекте
			-- и тратит токены провайдера молча. Включать осознанно: ai = { provider = "anthropic" }.
			ai = false,
			discovery = false, -- нет локальных docker-стеков с postgres-лейблами
		},
	},
}
