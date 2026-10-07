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

-- vim.g.dbs -> список коннектов dbee (name/type/url).
local function connections()
	local adapters = { postgres = "postgres", postgresql = "postgres", sqlserver = "sqlserver", mysql = "mysql", sqlite = "sqlite" }
	local out = {}
	for name, url in pairs(vim.g.dbs or {}) do
		local scheme = url:match("^(%a+)://")
		local kind = scheme and adapters[scheme]
		if kind then
			table.insert(out, { name = name, type = kind, url = kind == "postgres" and strip_libpq_only(url) or url })
		end
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
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
		{
			"<leader>DB",
			function()
				require("dbee").store("csv", "file", { extra_arg = vim.fn.expand("~") .. "/dbee-" .. os.date("%Y%m%d-%H%M%S") .. ".csv" })
			end,
			desc = "Dbee: store result as CSV",
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
