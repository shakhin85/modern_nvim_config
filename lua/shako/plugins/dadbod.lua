-- Экспорт запроса из буфера в CSV: PG → psql \copy, MSSQL → sqlcmd -s,
local function export_csv()
	local url = vim.b.db
	if not url then
		return vim.notify("b:db не задан (<leader>Ds)", vim.log.levels.WARN)
	end
	local lines
	if vim.fn.mode():match("[vV]") then
		vim.cmd([[normal! <Esc>]])
		lines = vim.api.nvim_buf_get_lines(0, vim.fn.line("'<") - 1, vim.fn.line("'>"), false)
	else
		lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	end
	local query = vim.trim(table.concat(lines, "\n")):gsub(";%s*$", "")
	if query == "" then
		return vim.notify("Пустой запрос", vim.log.levels.WARN)
	end
	local default = vim.fn.expand("~") .. "/query-" .. os.date("%Y%m%d-%H%M%S") .. ".csv"
	vim.ui.input({ prompt = "CSV path: ", default = default, completion = "file" }, function(path)
		if not path or path == "" then
			return
		end
		local cmd
		if url:match("^postgres") then
			cmd = { "psql", "-w", "--dbname", url, "-c", ("\\copy (%s) to '%s' csv header"):format(query, path) }
		elseif url:match("^sqlserver") then
			local user, pass, host, port, db = url:match("^sqlserver://([^:/@]*):?([^/@]*)@?([^:/?]+):?(%d*)/([^?]+)")
			if not host then
				return vim.notify("Не разобрал sqlserver URL", vim.log.levels.ERROR)
			end
			cmd = { "sqlcmd", "-S", host .. (port ~= "" and ("," .. port) or ""), "-d", db, "-C", "-s", ",", "-W", "-Q", query, "-o", path }
			if user ~= "" then
				vim.list_extend(cmd, { "-U", user, "-P", pass })
			else
				table.insert(cmd, "-E")
			end
		else
			return vim.notify("CSV-экспорт поддержан для postgres/sqlserver", vim.log.levels.WARN)
		end
		vim.system(cmd, { text = true }, function(o)
			vim.schedule(function()
				if o.code == 0 then
					vim.notify("CSV → " .. path)
				else
					vim.notify("Экспорт упал:\n" .. (o.stderr ~= "" and o.stderr or o.stdout), vim.log.levels.ERROR)
				end
			end)
		end)
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
			{
				"<leader>Ds",
				function()
					local keys = vim.tbl_keys(vim.g.dbs or {})
					table.sort(keys)
					vim.ui.select(keys, { prompt = "DB for this buffer:" }, function(k)
						if k then
							vim.b.db = vim.g.dbs[k]
							vim.notify("b:db = " .. k)
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
						vim.b[ev.buf].db = vim.g.dbs[vim.g.db_default]
					end
				end,
			})
		end,
	},
	{
		"kristijanhusak/vim-dadbod-completion",
		dependencies = { "tpope/vim-dadbod" },
		ft = { "sql", "mysql", "plsql", "sqlite" },
	},
}
