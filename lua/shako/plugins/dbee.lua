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
-- над ним: так запись в call log читается по select.
local function split_statements(query)
	local root = vim.treesitter.get_string_parser(query, "sql"):parse()[1]:root()
	local out, first = {}, nil
	for node in root:iter_children() do
		local kind = node:type()
		local _, _, pos = node:start()
		if kind == ";" then
			if first then
				table.insert(out, query:sub(first + 1, pos))
			end
			first = nil
		elseif kind ~= "comment" and kind ~= "marginalia" then
			first = first or pos
		end
	end
	if first then
		table.insert(out, vim.trim(query:sub(first + 1)))
	end
	return out
end

-- Готовый .sql-файл (или выделение) — в dbee: результат таблицей в Results.
-- Каждый запрос — свой вызов в call log: в одном вызове Go-бэкенд склеивает
-- наборы строк под заголовком первого запроса.
-- Коннект dbee переключаем на базу буфера (b:db), иначе запрос уйдёт туда,
-- что выбрано в drawer.
local function execute_buffer()
	local query = require("shako.dburl").buffer_query()
	if not query then
		return
	end
	local core = require("dbee.api").core
	local name = vim.iter(vim.g.dbs or {}):find(function(_, url)
		return url == vim.b.db
	end)
	for _, source in ipairs(core.get_sources()) do
		for _, conn in ipairs(core.source_get_connections(source:name())) do
			if conn.name == name then
				core.set_current_connection(conn.id)
			end
		end
	end
	for _, statement in ipairs(split_statements(query)) do
		require("dbee").execute(statement)
	end
end

return {
	"kndndrj/nvim-dbee",
	-- Плагин вешает автокоманду на BufModifiedSet, которого в Neovim 0.13-dev нет;
	-- имя события подменяет шим в init.lua. Апстрим стоит с 2025-07-25 (dda5176).
	dependencies = { "MunifTanjim/nui.nvim" },
	build = function()
		require("dbee").install()
	end,
	keys = {
		{ "<leader>Db", function() require("dbee").toggle() end, desc = "Dbee: toggle UI" },
		{ "<leader>DE", execute_buffer, ft = { "sql", "mysql", "plsql" }, mode = { "n", "x" }, desc = "Dbee: выполнить файл/выделение" },
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
			result = { page_size = 200 },
		})
	end,
}
