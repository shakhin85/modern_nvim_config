-- Общий разбор коннектов из vim.g.dbs.
-- Пароль везде уходит в окружение дочернего процесса, а не в argv:
-- /proc/<pid>/cmdline читает любой локальный пользователь.
local M = {}

function M.is_pg(url)
	return type(url) == "string" and url:match("^postgres") ~= nil
end

-- URL без креденшелов + env с PGUSER/PGPASSWORD. Форма для psql: юзер уходит
-- отдельной переменной, поэтому вырезаем из URL всю пару user:pass.
function M.pg_split(url)
	local user, pass = url:match("^postgres%a*://([^:/@]*):?([^@/]*)@")
	local safe = url:gsub("^(postgres%a*://)[^@/]*@", "%1")
	local env = {}
	if user and user ~= "" then
		env.PGUSER = user
	end
	if pass and pass ~= "" then
		env.PGPASSWORD = pass
	end
	return safe, env
end

-- URL без пароля, но с юзером — форма для инструментов, которые ходят сразу в
-- две базы под разными ролями (одной PGUSER там не обойтись). Пароль такой
-- клиент возьмёт из PGPASSFILE, см. shako.vault_pgpass.
-- Схему приводим к postgresql://: SQLAlchemy 2.x короткую postgres:// не принимает.
function M.pg_url_nopass(url)
	local u = url:gsub("^(postgres%a*://[^:/@]*):[^@/]*@", "%1@")
	return (u:gsub("^postgres://", "postgresql://"))
end

-- Разбор URL на части для строки .pgpass.
function M.pg_parts(url)
	local user, pass, host, port, db = url:match("^postgres%a*://([^:/@]*):?([^@/]*)@([^:/?]+):?(%d*)/([^?]+)")
	if not host then
		return nil
	end
	return {
		user = user,
		pass = vim.uri_decode(pass or ""),
		host = host,
		port = port ~= "" and port or "5432",
		db = db,
	}
end

-- Имена PG-коннектов из vim.g.dbs, по алфавиту.
function M.pg_names()
	local names = {}
	for name, url in pairs(vim.g.dbs or {}) do
		if M.is_pg(url) then
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

-- Строки запроса: выделение в visual-режиме, иначе весь буфер.
function M.buffer_lines()
	if vim.fn.mode():match("[vV]") then
		vim.cmd([[normal! <Esc>]])
		return vim.api.nvim_buf_get_lines(0, vim.fn.line("'<") - 1, vim.fn.line("'>"), false)
	end
	return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

-- Тот же текст одной строкой без хвостовой ';' — форма для vim.system и dadbod.
function M.buffer_query()
	local query = vim.trim(table.concat(M.buffer_lines(), "\n")):gsub(";%s*$", "")
	return query ~= "" and query or nil
end

return M
