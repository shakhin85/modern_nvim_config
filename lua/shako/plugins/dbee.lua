-- nvim-dbee — второй DB-стек, поставлен рядом с dadbod для сравнения на больших
-- выборках (у него настоящая пагинация из Go-бэкенда, у grip — limit + страницы
-- поверх него). Живёт отдельным файлом: проигравший удаляется одним rm.
-- Коннекты не дублируем — те же vim.g.dbs из dbs.local.lua.

-- Параметры только для libpq (psql). Go-драйвер lib/pq шлёт незнакомые ключи
-- серверу как GUC, и коннект падает с FATAL unrecognized configuration parameter.
local libpq_only = { gssencmode = true, keepalives = true, keepalives_idle = true, keepalives_interval = true, keepalives_count = true }

local function strip_libpq_only(url)
	local base, query = url:match("^([^?]*)%?(.*)$")
	if not base then
		return url
	end
	local kept = vim.tbl_filter(function(kv)
		return not libpq_only[kv:match("^([^=]*)")]
	end, vim.split(query, "&", { plain = true }))
	return #kept > 0 and (base .. "?" .. table.concat(kept, "&")) or base
end

-- sqlserver: URL в форме dadbod/sqlcmd -> форма go-mssqldb. Без логина — Kerberos. Go-драйвер (gokrb5) не читает KEYRING-кэш по
-- умолчанию, только FILE: берём KRB5CCNAME=FILE:… или кэш, который кладёт kinit
-- для шары (/tmp/krb5cc_shal).
local function sqlserver_url(url)
	-- sqlcmd/ODBC понимают yes/no, go-mssqldb — только strconv.ParseBool.
	url = url:gsub("([?&][Tt]rust[Ss]erver[Cc]ertificate=)[Yy][Ee][Ss]", "%1true")
	-- У go-mssqldb путь URL — имя инстанса, а не база (иначе SPN MSSQLSvc/host:<db>).
	local head, db, query = url:match("^(sqlserver://[^/?]+)/([^?]+)%??(.*)$")
	if head then
		url = head .. "?database=" .. db .. (query ~= "" and ("&" .. query) or "")
	end
	if url:match("^sqlserver://[^/]*@") then
		return url
	end
	local ccache = (vim.env.KRB5CCNAME or ""):match("^FILE:(.+)$") or "/tmp/krb5cc_shal"
	local sep = url:find("?", 1, true) and "&" or "?"
	return url .. sep .. "authenticator=krb5&krb5-configfile=/etc/krb5.conf&krb5-credcachefile=" .. ccache
end

local fix_url = { postgres = strip_libpq_only, sqlserver = sqlserver_url }

-- vim.g.dbs -> список коннектов dbee (name/type/url).
local function connections()
	local adapters = { postgres = "postgres", postgresql = "postgres", sqlserver = "sqlserver", mysql = "mysql", sqlite = "sqlite" }
	local out = {}
	for name, url in pairs(vim.g.dbs or {}) do
		local scheme = url:match("^(%a+)://")
		local kind = scheme and adapters[scheme]
		if kind then
			table.insert(out, { name = name, type = kind, url = fix_url[kind] and fix_url[kind](url) or url })
		end
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

-- Режет текст по `;` верхнего уровня из treesitter-дерева: `;` в строке или
-- комментарии не делит. Дерево с ERROR не страшно — непойманная `;` лишь
-- оставляет запросы одним куском. Кусок начинается с запроса, не с комментария
-- над ним: так запись в call log читается по select. stop — смещение его `;`
-- (или конца текста): по нему <leader>De находит запрос под курсором.
local function split_statements(query)
	local root = vim.treesitter.get_string_parser(query, "sql"):parse()[1]:root()
	local out, first = {}, nil
	for node in root:iter_children() do
		local kind = node:type()
		local _, _, pos = node:start()
		if kind == ";" then
			if first then
				table.insert(out, { text = query:sub(first + 1, pos), stop = pos })
			end
			first = nil
		elseif kind ~= "comment" and kind ~= "marginalia" then
			first = first or pos
		end
	end
	if first then
		table.insert(out, { text = vim.trim(query:sub(first + 1)), stop = #query })
	end
	return out
end

-- Коннект буфера: строка `-- db: <имя>` в начале файла (заметки dbee не знают
-- b:db), иначе имя из vim.g.dbs по b:db. Ни того ни другого — остаётся
-- коннект из drawer.
local function buffer_connection()
	local header = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] or ""
	return header:match("^%-%-%s*db:%s*(%S+)")
		or vim.iter(vim.g.dbs or {}):find(function(_, url)
			return url == vim.b.db
		end)
end

-- false — коннект назван, но его нет в dbee: запрос не уходит в чужую базу.
local function use_buffer_connection()
	local name = buffer_connection()
	if not name then
		return true
	end
	local core = require("dbee.api").core
	for _, source in ipairs(core.get_sources()) do
		for _, conn in ipairs(core.source_get_connections(source:name())) do
			if conn.name == name then
				core.set_current_connection(conn.id)
				return true
			end
		end
	end
	vim.notify("Dbee: нет коннекта " .. name, vim.log.levels.ERROR)
	return false
end

-- Готовый .sql-файл (или выделение) — в dbee: результат таблицей в Results.
-- Каждый запрос — свой вызов в call log: в одном вызове Go-бэкенд склеивает
-- наборы строк под заголовком первого запроса.
local function execute_buffer()
	local query = require("shako.dburl").buffer_query()
	if not query or not use_buffer_connection() then
		return
	end
	for _, statement in ipairs(split_statements(query)) do
		require("dbee").execute(statement.text)
	end
end

-- Один запрос — тот, в чьих границах (до его `;` включительно) стоит курсор.
local function execute_statement()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local cursor = col
	for i = 1, row - 1 do
		cursor = cursor + #lines[i] + 1
	end
	local statement = vim.iter(split_statements(table.concat(lines, "\n"))):find(function(s)
		return s.stop >= cursor
	end)
	if statement and use_buffer_connection() then
		require("dbee").execute(statement.text)
	end
end

-- Call log Go-бэкенд держит в памяти и пишет в /tmp/dbee-calllog.json на своём
-- выходе, уже после VimLeavePost; очистки в API нет. Поэтому <leader>DC только
-- ставит маркер, а файлы удаляет следующий старт nvim до restoreCallLog.
local clear_marker = vim.fn.stdpath("state") .. "/dbee/clear-calllog"

local function mark_call_log_clear()
	vim.fn.mkdir(vim.fs.dirname(clear_marker), "p")
	vim.fn.writefile({}, clear_marker)
	vim.notify("Dbee: call log очистится при следующем запуске nvim")
end

return {
	"kndndrj/nvim-dbee",
	-- Плагин вешает автокоманду на BufModifiedSet, которого в Neovim 0.13-dev нет;
	-- имя события подменяет шим в init.lua. Апстрим стоит с 2025-07-25 (dda5176).
	dependencies = { "MunifTanjim/nui.nvim" },
	init = function()
		if vim.uv.fs_stat(clear_marker) then
			vim.fn.delete("/tmp/dbee-calllog.json")
			vim.fn.delete("/tmp/dbee-history", "rf")
			vim.fn.delete(clear_marker)
		end
	end,
	build = function()
		require("dbee").install()
	end,
	keys = {
		{ "<leader>Db", function() require("dbee").toggle() end, desc = "Dbee: toggle UI" },
		{ "<leader>DE", execute_buffer, ft = { "sql", "mysql", "plsql" }, mode = { "n", "x" }, desc = "Dbee: выполнить файл/выделение" },
		{ "<leader>De", execute_statement, ft = { "sql", "mysql", "plsql" }, desc = "Dbee: выполнить запрос под курсором" },
		{ "<leader>DC", mark_call_log_clear, desc = "Dbee: очистить call log при следующем запуске" },
		{
			"<leader>DB",
			function()
				require("dbee").store("csv", "file", { extra_arg = vim.fn.expand("~") .. "/dbee-" .. os.date("%Y%m%d-%H%M%S") .. ".csv" })
			end,
			desc = "Dbee: store result as CSV",
		},
		{
			"<leader>DX",
			function()
				-- dbee пишет только csv/json: весь результат в CSV, затем scripts/csv2xlsx.py.
				local base = vim.fn.expand("~") .. "/dbee-" .. os.date("%Y%m%d-%H%M%S")
				require("dbee").store("csv", "file", { extra_arg = base .. ".csv" })
				local script = vim.fn.stdpath("config") .. "/scripts/csv2xlsx.py"
				vim.system({ "uv", "run", "--script", script, base .. ".csv", base .. ".xlsx" }, { text = true }, function(o)
					vim.schedule(function()
						if o.code ~= 0 then
							return vim.notify("xlsx не собран:\n" .. o.stderr, vim.log.levels.ERROR)
						end
						vim.fn.delete(base .. ".csv")
						vim.notify("Сохранено: " .. base .. ".xlsx")
					end)
				end)
			end,
			desc = "Dbee: store result as XLSX",
		},
	},
	config = function()
		require("dbee").setup({
			sources = { require("dbee.sources").MemorySource:new(connections()) },
			-- Ровно то, ради чего он тут: страницы тянутся из бэкенда по требованию.
			-- focus_result = false: курсор остаётся в SQL, правка и перезапуск без прыжков.
			result = { page_size = 200, focus_result = false },
			extra_helpers = {
				postgres = {
					["Count"] = 'select count(*) from "{{ .Schema }}"."{{ .Table }}"',
					["Size"] = "select pg_size_pretty(pg_total_relation_size('\"{{ .Schema }}\".\"{{ .Table }}\"'))",
				},
				sqlserver = {
					["Count"] = "select count_big(*) from [{{ .Schema }}].[{{ .Table }}]",
					["Size"] = "exec sp_spaceused '[{{ .Schema }}].[{{ .Table }}]'",
				},
			},
		})
	end,
}
