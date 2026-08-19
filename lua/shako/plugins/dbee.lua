-- nvim-dbee — второй DB-стек, поставлен рядом с dadbod для сравнения на больших
-- выборках (у него настоящая пагинация из Go-бэкенда, у grip — limit + страницы
-- поверх него). Живёт отдельным файлом: проигравший удаляется одним rm.
-- Коннекты не дублируем — те же vim.g.dbs из dbs.local.lua.

-- vim.g.dbs -> список коннектов dbee (name/type/url).
local function connections()
	local adapters = { postgres = "postgres", postgresql = "postgres", sqlserver = "sqlserver", mysql = "mysql", sqlite = "sqlite" }
	local out = {}
	for name, url in pairs(vim.g.dbs or {}) do
		local scheme = url:match("^(%a+)://")
		local kind = scheme and adapters[scheme]
		if kind then
			table.insert(out, { name = name, type = kind, url = url })
		end
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

return {
	"kndndrj/nvim-dbee",
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
