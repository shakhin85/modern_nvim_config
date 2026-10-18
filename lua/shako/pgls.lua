-- postgres_lsp (postgres-language-server): typecheck и hover по живой схеме PG
-- без выполнения запроса. Конфиг сервер ищет в корне workspace, а у ad-hoc .sql
-- и буферов DBUI корня нет. Корнем делаем каталог на базу в state, туда пишем
-- postgres-language-server.jsonc с коннектом из b:db. Пароля в файле нет:
-- сервер читает PGPASSFILE, см. shako.vault_pgpass.
local M = {}

local marker = "postgres-language-server.jsonc"
local state = vim.fn.stdpath("state") .. "/pgls"

-- Каталог-корень для базы из URL; jsonc пишем, только если содержимое поменялось.
-- linter и splinter выключены: миграции уже линтит squawk (nvim-lint), а splinter
-- шлёт в базу свои проверки supabase. plpgsqlCheck требует расширение в базе.
function M.dir_for(url)
	local p = require("shako.dburl").pg_parts(url or "")
	if not p then
		return nil
	end
	local dir = ("%s/%s@%s_%s_%s"):format(state, p.user, p.host, p.port, p.db)
	local text = vim.json.encode({
		linter = { enabled = false },
		splinter = { enabled = false },
		plpgsqlCheck = { enabled = false },
		typecheck = { enabled = true },
		db = { host = p.host, port = tonumber(p.port), username = p.user, database = p.db, connTimeoutSecs = 10 },
	})
	local file = dir .. "/" .. marker
	if vim.uv.fs_stat(file) == nil or table.concat(vim.fn.readfile(file), "\n") ~= text then
		vim.fn.mkdir(dir, "p")
		vim.fn.writefile({ text }, file)
	end
	return dir
end

-- Проектный jsonc важнее b:db: дефолтную базу FileType ставит каждому .sql.
function M.root_dir(buf, on_dir)
	local dir = vim.fs.root(buf, { marker }) or M.dir_for(vim.b[buf].db)
	if dir then
		on_dir(dir)
	end
end

-- Смена b:db в открытом буфере: FileType уже прошёл, vim.lsp.enable сам
-- клиента не перецепит. Отцепляем старый и стартуем под новую базу.
function M.attach(buf)
	local cfg = vim.lsp.config.postgres_lsp
	if not cfg or vim.fn.executable(cfg.cmd[1]) == 0 then
		return
	end
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf, name = "postgres_lsp" })) do
		vim.lsp.buf_detach_client(buf, client.id)
	end
	M.root_dir(buf, function(dir)
		vim.lsp.start(vim.tbl_extend("force", cfg, { root_dir = dir }), { bufnr = buf })
	end)
end

return M
