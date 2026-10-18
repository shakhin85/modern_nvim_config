-- Привязать буфер к базе. Одного b:db мало: vim-dadbod-completion наполняет кэш
-- схемы только по своему FileType-автокоманде, то есть до того, как b:db выставлен.
-- Без явного fetch() completion молчит — ни таблиц, ни колонок по алиасу.
local function attach_db(bufnr, url, refetch)
	vim.b[bufnr].db = url
	-- На FileType кэш наполнит автокоманда самого плагина (он грузится на старте
	-- через blink, его FileType идёт после нашего). Второй fetch — лишний
	-- синхронный db#connect. Явный fetch нужен только при смене базы в буфере.
	if not refetch then
		return
	end
	-- Через schedule: на FileType-событии lazy может ещё не успеть подгрузить
	-- vim-dadbod-completion (он ft-ленивый), и функции просто нет в этот тик.
	vim.schedule(function()
		if vim.api.nvim_buf_is_valid(bufnr) and vim.fn.exists("*vim_dadbod_completion#fetch") == 1 then
			vim.fn["vim_dadbod_completion#fetch"](bufnr)
		end
	end)
end

local dbee_notes = vim.fs.normalize(vim.fn.stdpath("state") .. "/dbee/notes")

local function is_dbee_note(bufnr)
	return vim.startswith(vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr)), dbee_notes)
end

-- URL текущего коннекта dbee — исходный, из vim.g.dbs по имени: dbee.lua отдаёт
-- драйверу URL без libpq-параметров (gssencmode и т.п.), а psql они нужны.
local function dbee_current_url()
	local ok, api = pcall(require, "dbee.api")
	if not ok then
		return nil
	end
	local ok_conn, conn = pcall(api.core.get_current_connection)
	return ok_conn and conn and (vim.g.dbs or {})[conn.name] or nil
end

-- Запрос из буфера и разбор URL — в shako.dburl: тем же кодом пользуются
-- живая psql-сессия и сверка схем.
local dburl = require("shako.dburl")
local buffer_query = dburl.buffer_query

-- CSV-выгрузка: PG → psql \copy, MSSQL → sqlcmd -s,
-- Пароль уходит третьим возвратом в env дочернего процесса, а не в argv:
-- /proc/<pid>/cmdline читает любой локальный пользователь (та же причина, по
-- которой <leader>Dg ниже обходит :GripConnect <url>).
local function csv_cmd(url, query, path)
	if dburl.is_pg(url) then
		local safe, env = dburl.pg_split(url)
		local cmd = { "psql", "-w", "--dbname", safe, "-c", ("\\copy (%s) to '%s' csv header"):format(query, path) }
		return cmd, nil, env
	elseif url:match("^sqlserver") then
		-- Креды необязательны (Kerberos): без '@' вся authority — это host[:port].
		local rest = url:match("^sqlserver://(.*)$")
		local creds, hostpart = rest:match("^([^@/]*)@(.*)$")
		local user, pass = (creds or ""):match("^([^:]*):?(.*)$")
		local host, port, db = (hostpart or rest):match("^([^:/?]+):?(%d*)/([^?]+)")
		if not host then
			return nil, "Не разобрал sqlserver URL"
		end
		local cmd = { "sqlcmd", "-S", host .. (port ~= "" and ("," .. port) or ""), "-d", db, "-C", "-s", ",", "-W", "-Q", query, "-o", path }
		local env = {}
		if user ~= "" then
			vim.list_extend(cmd, { "-U", user })
			env.SQLCMDPASSWORD = pass
		else
			table.insert(cmd, "-E")
		end
		return cmd, nil, env
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
	local cmd, err, env = csv_cmd(url, query, path)
	if not cmd then
		return vim.notify(err, vim.log.levels.WARN)
	end
	vim.system(cmd, { text = true, env = env }, function(o)
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
		-- Окно результата :DB из обычного .sql: ftplugin/dbout.vim лежит в DBUI,
		-- без загрузки нет <C-]> (прыжок по FK), vic, yh, <leader>R.
		ft = "dbout",
		keys = {
			{ "<leader>Du", "<cmd>DBUIToggle<CR>", desc = "Toggle DB UI" },
			{ "<leader>Da", "<cmd>DBUIAddConnection<CR>", desc = "Add DB connection" },
			{ "<leader>Df", "<cmd>DBUIFindBuffer<CR>", desc = "Find DB buffer" },
			{ "<leader>Dc", export_csv, mode = { "n", "x" }, desc = "Export query result to CSV" },
			{ "<leader>Do", function() require("shako.sql_ux").saved_queries() end, desc = "Saved queries (picker)" },
			{ "<leader>DO", function() require("shako.sql_ux").grep_saved_queries() end, desc = "Grep saved queries" },
			{ "<leader>Dv", inspect_result, mode = { "n", "x" }, desc = "Inspect result in visidata/csvlens" },
			{
				"<leader>Ds",
				function()
					local keys = vim.tbl_keys(vim.g.dbs or {})
					table.sort(keys)
					local bufnr = vim.api.nvim_get_current_buf()
					vim.ui.select(keys, { prompt = "DB for this buffer:" }, function(k)
						if k then
							attach_db(bufnr, vim.g.dbs[k], true)
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
			-- Сессии из nvim видны в pg_stat_activity как nvim, а не psql: их легко найти
			-- и прибить. libpq берёт PGAPPNAME, URL в dbs.local.lua не трогаем.
			vim.env.PGAPPNAME = "nvim"
			-- Встроенный ftplugin/sql.vim вешает в insert <Left>/<Right> на
			-- sqlcomplete#Drill* и пачку <C-C>…-маппингов: стрелки перестают двигать
			-- курсор, <C-C> ждёт timeoutlen. Дополнение у нас — blink + dadbod.
			-- filetype=dbout ставит autocmd из plugin/db_ui.vim, то есть только после
			-- загрузки DBUI; без этого ft-триггер выше никогда не сработает.
			vim.filetype.add({ extension = { dbout = "dbout" } })
			vim.g.omni_sql_no_default_maps = 1
			vim.g.loaded_sql_completion = 1
			vim.g.db_ui_use_nerd_fonts = 1
			vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/db_ui"
			vim.g.db_ui_execute_on_save = 0 -- :w не выполняет запрос; выполнять <leader>S / <leader>W
			vim.g.db_ui_show_database_icon = 1
			-- Хелперы (Sample = ORDER BY random(), Count) бьют по prod-таблицам:
			-- клик открывает запрос, выполнение — руками (<leader>S).
			vim.g.db_ui_auto_execute_table_helpers = 0
			vim.g.db_ui_win_position = "left"
			vim.g.db_ui_winwidth = 35
			vim.g.db_ui_use_nvim_notify = 1
			-- Служебные схемы PG и MSSQL в дереве — шум. DBUI сверяет через match(),
			-- то есть по подстроке: без ^…$ 'sys' спрятал бы и 'analysis'.
			vim.g.db_ui_hide_schemas = {
				"^pg_catalog$",
				"^pg_toast",
				"^pg_temp_",
				"^information_schema$",
				"^INFORMATION_SCHEMA$",
				"^sys$",
				"^guest$",
				"^db_\\(owner\\|accessadmin\\|securityadmin\\|ddladmin\\|backupoperator\\|datareader\\|datawriter\\|denydatareader\\|denydatawriter\\)$",
			}
			require("shako.sql_ux").setup_timing()
			vim.g.db_ui_table_helpers = {
				sqlserver = {
					List = "SELECT TOP 200 * FROM {optional_schema}{table}",
					Count = "SELECT COUNT(*) AS cnt FROM {optional_schema}{table}",
					Columns = "SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '{table}' ORDER BY ORDINAL_POSITION",
					Help = "EXEC sp_help '{optional_schema}{table}'",
					-- Размер на диске и строки из метаданных: без скана таблицы.
					-- sys.partitions, а не dm_db_partition_stats: тому нужен VIEW DATABASE STATE.
					Size = "SELECT (SELECT SUM(p.rows) FROM sys.partitions p WHERE p.object_id = o.id AND p.index_id IN (0, 1)) AS rows_est, SUM(a.total_pages) * 8 / 1024 AS reserved_mb, SUM(a.used_pages) * 8 / 1024 AS used_mb FROM (SELECT OBJECT_ID('[{schema}].[{table}]') AS id) o JOIN sys.partitions p ON p.object_id = o.id JOIN sys.allocation_units a ON a.container_id = p.partition_id GROUP BY o.id",
				},
				postgresql = {
					Count = "SELECT count(*) AS cnt FROM {optional_schema}{table}",
					Sample = "SELECT * FROM {optional_schema}{table} ORDER BY random() LIMIT 20",
					Explain = "EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM {optional_schema}{table} LIMIT 200",
					-- Размер и оценка строк из pg_class: без count(*) по prod-таблице.
					Size = "SELECT c.reltuples::bigint AS rows_est, pg_size_pretty(pg_total_relation_size(c.oid)) AS total, pg_size_pretty(pg_relation_size(c.oid)) AS heap, pg_size_pretty(pg_indexes_size(c.oid)) AS indexes FROM pg_class c WHERE c.oid = format('%I.%I', '{schema}', '{table}')::regclass",
				},
			}
			-- Подключения — в git-ignored lua/shako/dbs.local.lua (см. dbs.local.lua.example)
			local ok, dbs = pcall(dofile, vim.fn.stdpath("config") .. "/lua/shako/dbs.local.lua")
			if ok and type(dbs) == "table" then
				vim.g.dbs = dbs
			end
			-- sqlcmd от Microsoft (mssql-tools18) раньше go-sqlcmd из ~/go/bin: у go-sqlcmd
			-- нет Kerberos, -E на Linux даёт «Login failed for user ''».
			vim.env.PATH = "/opt/mssql-tools18/bin:" .. vim.env.PATH
			-- Схему postgres:// vim-dadbod сам не знает: алиас ставит только
			-- vim-dadbod-completion внутри fetch, то есть после первого sql-буфера.
			-- Без этого :DB по postgres://-коннекту до него — «no adapter for postgres».
			vim.g.db_adapter_postgres = "db#adapter#postgresql#"
			-- Пароли PG — из Vault в PGPASSFILE (tmpfs), в URL их нет.
			require("shako.vault_pgpass").sync()
			vim.api.nvim_create_user_command("DbVaultRefresh", function()
				require("shako.vault_pgpass").sync(true)
			end, { desc = "Перечитать пароли БД из Vault" })
			-- Коннект в dbee сменили, пока заметка была в фоне: completion и диалект
			-- sqlfluff должны идти за ним, а не за базой на момент открытия.
			vim.api.nvim_create_autocmd("BufEnter", {
				callback = function(ev)
					if not is_dbee_note(ev.buf) then
						return
					end
					local url = dbee_current_url()
					if url and url ~= vim.b[ev.buf].db then
						attach_db(ev.buf, url, true)
					end
				end,
			})
			-- Обычный .sql-файл: привязать к дефолтной базе, чтобы completion знал схему
			vim.api.nvim_create_autocmd("FileType", {
				pattern = { "sql", "mysql", "plsql" },
				callback = function(ev)
					-- Заметкам nvim-dbee плагин тоже ставит filetype=sql
					-- (dbee/ui/editor/init.lua), но b:dbui_db_key_name у них нет.
					-- Своего completion у dbee нет — он идёт через
					-- vim-dadbod-completion и требует b:db, поэтому базу ставим, но
					-- ТЕКУЩУЮ из dbee, а не дефолтную, и <leader>S не трогаем:
					-- выполнение запроса у dbee своё.
					if is_dbee_note(ev.buf) then
						local url = dbee_current_url()
						if url then
							attach_db(ev.buf, url)
						end
						return
					end
					-- Сохранённый запрос DBUI (<save_location>/<база>/файл) — к своей базе.
					local sql_ux = require("shako.sql_ux")
					local saved = sql_ux.saved_query_db(ev.buf)
					if not vim.b[ev.buf].db and vim.g.dbs and (saved or vim.g.db_default) then
						attach_db(ev.buf, vim.g.dbs[saved or vim.g.db_default])
					end
					-- <leader>S из dadbod-ui живёт только внутри его буферов; в обычном
					-- .sql-файле выполнять запрос нечем, заводим сами (shako.sql_ux):
					-- буфер, выделение, statement под курсором, bind-параметры.
					-- Через schedule: b:dbui_db_key_name у буферов DBUI появляется после
					-- FileType, а их <leader>S/<leader>E перебивать нельзя.
					vim.schedule(function()
						if vim.api.nvim_buf_is_valid(ev.buf) then
							sql_ux.setup_buffer(ev.buf)
						end
					end)
				end,
			})
		end,
	},
	{
		"kristijanhusak/vim-dadbod-completion",
		dependencies = { "tpope/vim-dadbod" },
		ft = { "sql", "mysql", "plsql", "sqlite" },
		-- Апстрим берёт схему из INFORMATION_SCHEMA.COLUMNS, где нет матвью
		-- PostgreSQL. Патч переносит запросы на pg_class; подробности —
		-- в shako.patches.dadbod_completion.
		init = function(plugin)
			require("shako.patches.dadbod_completion").setup(plugin.dir)
		end,
		build = function(plugin)
			print(require("shako.patches.dadbod_completion").apply(plugin.dir))
		end,
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
