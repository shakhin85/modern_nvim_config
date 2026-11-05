-- postgres_lsp (postgres-language-server): typecheck и hover по живой схеме PG
-- без выполнения запроса. Конфиг сервер ищет в корне workspace, а у ad-hoc .sql
-- и буферов DBUI корня нет. Корнем делаем каталог на базу в state, туда пишем
-- postgres-language-server.jsonc с коннектом из b:db. Пароля в файле нет:
-- сервер читает PGPASSFILE, см. shako.vault_pgpass.
local M = {}

local marker = "postgres-language-server.jsonc"
local state = vim.fn.stdpath("state") .. "/pgls"

-- Сервер держит свой пул коннектов на базу. Под рабочей учёткой он занимал слоты
-- bitrix_user и dwh_1c, нужные ETL (SHA-413). Для этих баз ходим ролью nvim_ro:
-- CONNECTION LIMIT 5 и read-only держит PostgreSQL. Пароль — shako.vault_pgpass.
M.ro = { user = "nvim_ro", dbs = { bitrix24 = true, dwh_1c = true } }

-- lsp-proxy не выходит по EOF в stdin: после смерти nvim он остаётся сиротой, держит
-- сокет демона, а демон с --stop-on-disconnect держит пулы коннектов к базам.
-- pdeathsig: ядро шлёт прокси SIGTERM при любом выходе nvim, включая SIGKILL.
function M.cmd()
	local server = "postgres-language-server"
	if vim.fn.executable(server) == 1 and vim.fn.executable("setpriv") == 1 then
		return { "setpriv", "--pdeathsig", "TERM", "--", server, "lsp-proxy" }
	end
end

-- Каталог-корень для базы из URL; jsonc пишем, только если содержимое поменялось.
-- linter и splinter выключены: миграции уже линтит squawk (nvim-lint), а splinter
-- шлёт в базу свои проверки supabase. plpgsqlCheck требует расширение в базе.
function M.dir_for(url)
	local p = require("shako.dburl").pg_parts(url or "")
	if not p then
		return nil
	end
	local user = M.ro.dbs[p.db] and M.ro.user or p.user
	local name = ("%s@%s_%s_%s"):format(user, p.host, p.port, p.db):gsub("[^%w@._-]", "_")
	local dir = state .. "/" .. name
	local cfg = {
		linter = { enabled = false },
		splinter = { enabled = false },
		plpgsqlCheck = { enabled = false },
		typecheck = { enabled = true },
		db = { host = p.host, port = tonumber(p.port), username = user, database = p.db, connTimeoutSecs = 10 },
	}
	-- Сравниваем таблицы, не текст: порядок ключей vim.json.encode от запуска к запуску разный.
	local file = dir .. "/" .. marker
	local ok, old = pcall(function()
		return vim.json.decode(table.concat(vim.fn.readfile(file), "\n"))
	end)
	if not (ok and vim.deep_equal(old, cfg)) then
		vim.fn.mkdir(dir, "p")
		vim.fn.writefile({ vim.json.encode(cfg) }, file)
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
	if not cfg or vim.fn.executable(cfg.cmd[#cfg.cmd - 1]) == 0 then
		return
	end
	local old = vim.lsp.get_clients({ bufnr = buf, name = "postgres_lsp" })
	local new_id
	M.root_dir(buf, function(dir)
		new_id = vim.lsp.start(vim.tbl_extend("force", cfg, { root_dir = dir }), { bufnr = buf })
	end)
	-- Старого отцепляем сразу: stop у сервера идёт 7-9 с, клиент всё это время
	-- остаётся в буфере и не отвечает, а blink ждёт его до таймаута на каждую клавишу.
	for _, client in ipairs(old) do
		if client.id ~= new_id then
			vim.lsp.buf_detach_client(buf, client.id)
			-- Клиент без буферов держит пул коннектов к старой базе до выхода из nvim.
			-- Без таймаута прокси гасится 7-9 с; через 1 с nvim шлёт SIGTERM сам.
			if vim.tbl_isempty(client.attached_buffers) then
				client:stop(1000)
			end
		end
	end
end

return M
