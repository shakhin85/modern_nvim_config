-- Живая psql-сессия: один процесс на базу, поэтому переживают BEGIN/ROLLBACK,
-- CREATE TEMP TABLE, SET search_path и \timing.
-- Через :DB этого нет и не будет: dadbod поднимает psql заново на каждый запрос,
-- и транзакция закрывается вместе с процессом. У nvim-dbee то же ограничение по
-- другой причине — Client.Query берёт соединение из пула database/sql
-- (dbee/core/builders/client.go), так что BEGIN и COMMIT попадут в разные сессии.
local dburl = require("shako.dburl")

local sessions = {} -- имя базы -> Terminal
local current = nil

local function terminal(name)
	if sessions[name] then
		return sessions[name]
	end
	local url = (vim.g.dbs or {})[name]
	if not dburl.is_pg(url) then
		vim.notify("Живая сессия только для postgres: " .. name, vim.log.levels.WARN)
		return nil
	end
	local safe, env = dburl.pg_split(url)
	-- ~/.psqlrc здесь НЕ отключаем, в отличие от <leader>Dc: парсить вывод
	-- некому, а \timing и рамки в интерактиве нужны.
	sessions[name] = require("toggleterm.terminal").Terminal:new({
		cmd = "psql -w --dbname " .. vim.fn.shellescape(safe),
		-- PSQLRC=/dev/null из init dadbod наследуется терминалом — возвращаем свой rc.
		env = vim.tbl_extend("force", env or {}, { PSQLRC = vim.fn.expand("~/.psqlrc") }),
		direction = "vertical",
		close_on_exit = false, -- psql упал — сообщение должно остаться на экране
		hidden = true,
		display_name = "psql:" .. name,
	})
	return sessions[name]
end

-- Поднять сессию к выбранной базе. Повторный выбор той же базы переиспользует
-- процесс: открытая транзакция и temp-таблицы остаются живыми.
local function connect()
	local names = dburl.pg_names()
	if #names == 0 then
		return vim.notify("vim.g.dbs пуст", vim.log.levels.WARN)
	end
	vim.ui.select(names, { prompt = "psql-сессия:" }, function(name)
		if not name then
			return
		end
		local term = terminal(name)
		if not term then
			return
		end
		current = name
		if not term:is_open() then
			term:open()
		end
	end)
end

-- Отправить выделение (или весь буфер) в живую сессию.
local function send()
	if not current or not sessions[current] then
		return vim.notify("Сессия не поднята (<leader>Dr)", vim.log.levels.WARN)
	end
	local lines = dburl.buffer_lines()
	local last
	for i = #lines, 1, -1 do
		if vim.trim(lines[i]) ~= "" then
			last = i
			break
		end
	end
	if not last then
		return vim.notify("Пустой запрос", vim.log.levels.WARN)
	end
	lines = vim.list_slice(lines, 1, last)
	-- Без ';' psql просто копит ввод и ничего не выполняет. Мета-команды (\d, \timing)
	-- завершаются переводом строки, им точка с запятой не нужна.
	local tail = vim.trim(lines[last])
	if not tail:match(";$") and not tail:match("^\\") then
		lines[last] = lines[last] .. ";"
	end
	local term = sessions[current]
	if not term:is_open() then
		term:open() -- job_id появляется только после запуска, до этого send некуда писать
	end
	term:send(lines, true)
end

local function toggle()
	if not current or not sessions[current] then
		return vim.notify("Сессия не поднята (<leader>Dr)", vim.log.levels.WARN)
	end
	sessions[current]:toggle()
end

return {
	"akinsho/toggleterm.nvim",
	optional = true, -- спека самого плагина живёт в toggleterm.lua, здесь только маппинги
	keys = {
		{ "<leader>Dr", connect, desc = "psql: поднять живую сессию" },
		{ "<leader>Dq", send, mode = { "n", "x" }, desc = "psql: отправить запрос в сессию" },
		{ "<leader>DR", toggle, desc = "psql: показать/скрыть окно сессии" },
	},
}
