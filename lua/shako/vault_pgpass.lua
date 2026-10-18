-- Пароли PG живут в Vault одним секретом: ключ — имя коннекта из vim.g.dbs.
-- На старте собираем .pgpass в tmpfs и отдаём его всем клиентам через PGPASSFILE
-- (psql/dadbod, dbee через lib/pq, migra). Пароля нет ни в конфиге, ни в argv.
-- Перенос из старого dbs.local.lua: nvim -l scripts/dbs-to-vault.lua
local M = {}

M.path = "secret/products/data-and-analytics/nvim-dbs"
-- Коннекты со своим секретом (ключ password): читаем его напрямую, без копии в M.path,
-- чтобы ротация пароля не оставляла протухшую копию.
M.own = {
	dwh_1c_dev = "secret/products/data-and-analytics/dev/dwh_1c",
}
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
	local sources = { [M.path] = false }
	for name, path in pairs(M.own) do
		sources[path] = name
	end
	local passwords, errors, pending = {}, {}, vim.tbl_count(sources)
	for path, name in pairs(sources) do
		vim.system({ "vault", "kv", "get", "-format=json", path }, { text = true }, function(o)
			vim.schedule(function()
				local ok, decoded = pcall(vim.json.decode, o.stdout)
				if o.code ~= 0 or not ok then
					table.insert(errors, path .. ": " .. (o.code ~= 0 and o.stderr or "ответ Vault не JSON"))
				else
					local data = decoded.data.data
					if name then
						passwords[name] = data.password
					else
						passwords = vim.tbl_extend("keep", passwords, data)
					end
				end
				pending = pending - 1
				if pending > 0 then
					return
				end
				-- Хоть один источник не ответил — рабочий pgpass не трогаем: неполный
				-- файл (истёкший токен) сломал бы коннекты, которые сейчас работают.
				if #errors > 0 then
					vim.notify("Vault: часть паролей БД не получена, PGPASSFILE не изменён, повтор: :DbVaultRefresh\n" .. table.concat(errors, "\n"), vim.log.levels.WARN)
					return
				end
				M.write(passwords)
				if force then
					vim.notify("PGPASSFILE обновлён из Vault")
				end
			end)
		end)
	end
end

return M
