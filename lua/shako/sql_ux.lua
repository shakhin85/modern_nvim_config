-- SQL-удобства поверх vim-dadbod для обычных .sql-буферов и буферов DBUI:
-- statement под курсором (treesitter), bind-параметры :name, EXPLAIN-обёртка,
-- picker сохранённых запросов DBUI и время выполнения :DB.
local M = {}

-- :name как в dadbod-ui, но имя обязано начинаться с буквы: иначе '12:30' в строке
-- и '::int' ловятся как параметры.
local PARAM = "%f[:%w_]:([%a_][%w_]*)"

local function scheme(bufnr)
	return (vim.b[bufnr].db or ""):match("^(%w+):") or ""
end

local function is_pg(bufnr)
	return scheme(bufnr):match("^postgres") ~= nil
end

-- Диапазон (0-based строки, конечная включительно) statement под курсором.
-- Курсор между statement'ами — берём ближайший выше: так ведёт себя «выполнить
-- то, что только что написал».
function M.statement_range(bufnr, row)
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "sql")
	if not ok or not parser then
		return nil
	end
	local root = parser:parse()[1]:root()
	local best
	for node in root:iter_children() do
		local t = node:type()
		if node:named() and t ~= "comment" and t ~= "marginalia" then
			local sr, _, er = node:range()
			if sr > row then
				break
			end
			best = { sr, er }
			if er >= row then
				break
			end
		end
	end
	return best
end

local function statement_lines(bufnr)
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local r = M.statement_range(bufnr, row)
	if not r then
		return nil
	end
	return vim.api.nvim_buf_get_lines(bufnr, r[1], r[2] + 1, false), r
end

-- Textobject aq/iq: построчно выделить statement под курсором.
function M.select_statement()
	local bufnr = vim.api.nvim_get_current_buf()
	local _, r = statement_lines(bufnr)
	if not r then
		return vim.notify("SQL: statement под курсором не найден", vim.log.levels.WARN)
	end
	if vim.fn.mode():match("^[vV\22]") then
		vim.cmd("normal! \27")
	end
	vim.api.nvim_win_set_cursor(0, { r[1] + 1, 0 })
	vim.cmd("normal! V")
	vim.api.nvim_win_set_cursor(0, { r[2] + 1, 0 })
end

function M.params(lines)
	local seen, out = {}, {}
	for _, l in ipairs(lines) do
		for name in l:gmatch(PARAM) do
			if not seen[name] then
				seen[name] = true
				table.insert(out, name)
			end
		end
	end
	return out
end

-- Значения хранятся в b:sql_bind_params и пишутся в текст как есть: строку вводить
-- в кавычках ('abc'), число — без.
local function ask(bufnr, names, force, done)
	local vals = vim.b[bufnr].sql_bind_params or {}
	local i = 0
	local function step()
		i = i + 1
		local name = names[i]
		if not name then
			vim.b[bufnr].sql_bind_params = vals
			return done(vals)
		end
		if vals[name] and not force then
			return step()
		end
		vim.ui.input({ prompt = ":" .. name .. " (SQL-литерал) = ", default = vals[name] }, function(v)
			if v == nil then
				return
			end
			vals[name] = v
			step()
		end)
	end
	step()
end

function M.inject(lines, vals)
	return vim.tbl_map(function(l)
		return (l:gsub(PARAM, function(name)
			return vals[name]
		end))
	end, lines)
end

-- :DB < file: тот же путь, что у :%DB (b:db, окно результата, DBExecutePost),
-- но текст уже с подставленными параметрами.
local function run(bufnr, lines)
	ask(bufnr, M.params(lines), false, function(vals)
		local file = vim.fn.tempname() .. ".sql"
		vim.fn.writefile(M.inject(lines, vals), file)
		vim.cmd("DB < " .. vim.fn.fnameescape(file))
	end)
end

function M.run_buffer()
	run(0, vim.api.nvim_buf_get_lines(0, 0, -1, false))
end

function M.run_selection()
	local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
	vim.cmd("normal! \27")
	run(0, lines)
end

function M.run_statement()
	local bufnr = vim.api.nvim_get_current_buf()
	if vim.b[bufnr].dbui_db_key_name then
		-- Буфер DBUI: выполняет сам DBUI (свои bind-параметры, окно результата).
		M.select_statement()
		return vim.api.nvim_feedkeys(vim.keycode("<Plug>(DBUI_ExecuteQuery)"), "m", false)
	end
	local lines = statement_lines(bufnr)
	if lines then
		run(bufnr, lines)
	end
end

function M.edit_params()
	local bufnr = vim.api.nvim_get_current_buf()
	local names = M.params(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
	if #names == 0 then
		return vim.notify("SQL: в буфере нет параметров :name")
	end
	ask(bufnr, names, true, function(vals)
		vim.notify("SQL: " .. vim.inspect(vals, { newline = " ", indent = "" }))
	end)
end

-- EXPLAIN statement'а/выделения. ANALYZE исполняет запрос, поэтому только для
-- SELECT/WITH; DML/DDL получает план без выполнения. MSSQL: SHOWPLAN_TEXT —
-- оценочный план, запрос не исполняется.
function M.explain(lines)
	local bufnr = vim.api.nvim_get_current_buf()
	local body = vim.trim(table.concat(lines, "\n")):gsub(";%s*$", "")
	local wrapped
	if is_pg(bufnr) then
		local read_only = body:lower():match("^%s*select") or body:lower():match("^%s*with")
		wrapped = (read_only and "EXPLAIN (ANALYZE, BUFFERS) " or "EXPLAIN ") .. body .. ";"
	elseif scheme(bufnr) == "sqlserver" then
		wrapped = "SET SHOWPLAN_TEXT ON\nGO\n" .. body .. "\nGO\nSET SHOWPLAN_TEXT OFF\nGO"
	else
		return vim.notify("SQL: EXPLAIN-обёртка есть только для PostgreSQL и MSSQL", vim.log.levels.WARN)
	end
	run(bufnr, vim.split(wrapped, "\n"))
end

function M.explain_statement()
	local lines = statement_lines(0)
	if lines then
		M.explain(lines)
	end
end

function M.explain_selection()
	local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
	vim.cmd("normal! \27")
	M.explain(lines)
end

-- Сохранённые запросы DBUI лежат в <save_location>/<имя базы>/<файл>.
function M.saved_queries()
	require("snacks").picker.files({ cwd = vim.g.db_ui_save_location, title = "Saved queries (DBUI)" })
end

function M.grep_saved_queries()
	require("snacks").picker.grep({ cwd = vim.g.db_ui_save_location, title = "Grep saved queries (DBUI)" })
end

-- Ключ vim.g.dbs для файла из save_location, иначе nil.
function M.saved_query_db(bufnr)
	local root = vim.g.db_ui_save_location
	local path = vim.api.nvim_buf_get_name(bufnr)
	if not root or path:sub(1, #root + 1) ~= root .. "/" then
		return nil
	end
	local key = path:sub(#root + 2):match("^([^/]+)/")
	return key and vim.g.dbs and vim.g.dbs[key] and key or nil
end

-- Базы, где ошибочный запрос бьёт по живым данным: имя в statusline красное.
local PROD = { lime_prod = true, jade_mssql = true }

-- Имя базы буфера для statusline: ключ DBUI, ключ vim.g.dbs по URL или
-- db@host из URL (без логина и пароля). nil — буфер не SQL или базы нет.
function M.db_label()
	if not vim.tbl_contains({ "sql", "mysql", "plsql" }, vim.bo.filetype) then
		return nil
	end
	local key = vim.b.dbui_db_key_name
	local url = vim.b.db
	if not key and url then
		for k, v in pairs(vim.g.dbs or {}) do
			if v == url then
				key = k
				break
			end
		end
	end
	if key then
		return key, PROD[key] or false
	end
	if type(url) ~= "string" then
		return nil
	end
	local host = url:match("^%w+://[^@/]*@([^/:?;]+)") or url:match("^%w+://([^/:?;]+)")
	local db = url:match("^%w+://[^/]*/([^?;/]+)") or url:match("[;?&]database=([^;&]+)")
	return host and (db and db .. "@" .. host or host) or url:match("^(%w+):"), false
end

function M.setup_buffer(bufnr)
	local map = function(mode, lhs, rhs, desc)
		vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
	end
	map({ "x", "o" }, "aq", M.select_statement, "SQL statement")
	map({ "x", "o" }, "iq", M.select_statement, "SQL statement")
	map("n", "<leader>Dl", M.run_statement, "Execute statement under cursor")
	map("n", "<leader>Dw", M.explain_statement, "EXPLAIN statement under cursor")
	map("x", "<leader>Dw", M.explain_selection, "EXPLAIN selection")
	if not vim.b[bufnr].dbui_db_key_name then
		-- В буферах DBUI <leader>S и <leader>E — свои, с тем же смыслом.
		map("n", "<leader>S", M.run_buffer, "Execute buffer against b:db")
		map("x", "<leader>S", M.run_selection, "Execute selection against b:db")
		map("n", "<leader>E", M.edit_params, "Edit bind parameters (:name)")
	end
end

-- Длительность :DB. vim-dadbod пишет её через echo, который тут же перекрывает
-- следующее сообщение; DBUI показывает своё уведомление, но только после
-- открытия drawer'а (его augroup dbui_async_queries) — тогда молчим, чтобы не дублировать.
function M.setup_timing()
	local started = {}
	local group = vim.api.nvim_create_augroup("shako_sql_timing", { clear = true })
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "*DBExecutePre",
		callback = function(ev)
			started[ev.match:gsub("/DBExecutePre$", "")] = vim.uv.hrtime()
		end,
	})
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "*DBExecutePost",
		callback = function(ev)
			-- ev.match — имя события целиком: <файл результата>/DBExecutePost.
			local out = ev.match:gsub("/DBExecutePost$", "")
			local t0 = started[out]
			started[out] = nil
			if not t0 or vim.fn.exists("#dbui_async_queries") == 1 then
				return
			end
			vim.notify(string.format("DB: %.3f s", (vim.uv.hrtime() - t0) / 1e9), vim.log.levels.INFO, { title = "dadbod" })
		end,
	})
end

return M
