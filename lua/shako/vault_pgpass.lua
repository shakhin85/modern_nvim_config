-- Пароли PG живут в Vault одним секретом: ключ — имя коннекта из vim.g.dbs.
-- На старте собираем .pgpass в tmpfs и отдаём его всем клиентам через PGPASSFILE
-- (psql/dadbod, dbee через lib/pq, migra). Пароля нет ни в конфиге, ни в argv.
-- Перенос из старого dbs.local.lua: nvim -l scripts/dbs-to-vault.lua
local M = {}

M.path = "secret/products/data-and-analytics/nvim-dbs"
-- tmpfs: файл исчезает при перезагрузке и не попадает в бэкапы домашнего каталога.
M.file = ("/run/user/%d/nvim-pgpass"):format(vim.uv.getuid())

-- В .pgpass ':' и '\' — служебные.
local function escape(s)
	return (s:gsub("\\", "\\\\"):gsub(":", "\\:"))
end

function M.write(passwords)
	local dburl = require("shako.dburl")
	local lines = {}
	for name, url in pairs(vim.g.dbs or {}) do
		local parts = dburl.pg_parts(url)
		if parts and passwords[name] then
			table.insert(lines, table.concat({ parts.host, parts.port, parts.db, escape(parts.user), escape(passwords[name]) }, ":"))
		end
	end
	table.sort(lines)
	vim.fn.writefile(lines, M.file)
	vim.uv.fs_chmod(M.file, 384) -- 0600: libpq молча игнорирует файл с более широкими правами
end

-- Старт nvim не ждёт Vault: запрос асинхронный. Файл в tmpfs живёт до перезагрузки,
-- поэтому в Vault идём, только если файла нет или force (:DbVaultRefresh).
function M.sync(force)
	vim.env.PGPASSFILE = M.file
	if not force and vim.uv.fs_stat(M.file) then
		return
	end
	vim.system({ "vault", "kv", "get", "-format=json", M.path }, { text = true }, function(o)
		vim.schedule(function()
			if o.code ~= 0 then
				return vim.notify("Vault: пароли БД не получены\n" .. o.stderr, vim.log.levels.WARN)
			end
			M.write(vim.json.decode(o.stdout).data.data)
			if force then
				vim.notify("PGPASSFILE обновлён из Vault")
			end
		end)
	end)
end

return M
