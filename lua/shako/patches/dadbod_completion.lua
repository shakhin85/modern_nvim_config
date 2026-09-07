-- Патч vim-dadbod-completion: научить его матвью PostgreSQL.
--
-- Апстрим берёт схему из INFORMATION_SCHEMA.COLUMNS (schemas.vim:1-5), а матвью
-- там нет — они лежат в pg_class с relkind='m'. Проверено на базе omman:
-- 8 матвью из 8 невидимы, при том что таблиц там 7. Точки расширения у плагина
-- нет: запросы объявлены скриптовыми переменными s:, снаружи их не подменить.
--
-- Поэтому правим сам файл, но только словарь s:postgres — общие s:query и
-- s:table_column_query трогать нельзя, на них сидят MySQL и MSSQL.
-- Патч накладывается build-хуком lazy после каждого обновления плагина и падает
-- с ошибкой, если апстрим изменил строку: молчащее автодополнение хуже сборки,
-- которая громко упала.
local M = {}

local MARKER = '" shako: matview-aware queries'

-- Матвью PostgreSQL: колонки из pg_attribute, отсеивая системные и удалённые.
local MV_COLUMNS = "SELECT c.relname,a.attname FROM pg_class c "
	.. "JOIN pg_namespace n ON n.oid=c.relnamespace "
	.. "JOIN pg_attribute a ON a.attrelid=c.oid "
	.. "WHERE c.relkind='m' AND a.attnum>0 AND NOT a.attisdropped"

local MV_NAMES = "SELECT n.nspname,c.relname FROM pg_class c "
	.. "JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind='m'"

-- Определения вставляем перед словарём s:postgres, чтобы не задеть другие СУБД.
local function definitions()
	return table.concat({
		MARKER,
		'let s:pg_column_query = s:base_column_query." UNION ALL ' .. MV_COLUMNS .. ' ORDER BY 2 ASC"',
		-- ORDER BY 2, а не по имени: в UNION имя колонки берётся из первой ветки.
		'let s:pg_table_column_query = s:base_column_query." WHERE TABLE_NAME={db_tbl_name} '
			.. 'UNION ALL '
			.. MV_COLUMNS
			.. " AND c.relname={db_tbl_name}\"",
		'let s:pg_count_query = "SELECT COUNT(*) AS total FROM (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS '
			.. "UNION ALL SELECT 1 FROM pg_class c JOIN pg_attribute a ON a.attrelid=c.oid "
			.. "WHERE c.relkind='m' AND a.attnum>0 AND NOT a.attisdropped) t\"",
		'let s:pg_schema_query = s:schema_query." UNION ALL ' .. MV_NAMES .. '"',
		"",
	}, "\n")
end

-- Замены применяются ТОЛЬКО внутри словаря s:postgres: те же строки дословно
-- повторяются у mysql и mssql, и правка по всему файлу сломала бы их.
local REPLACEMENTS = {
	{ "\\ 'column_query': s:query,", "\\ 'column_query': s:pg_column_query," },
	{ "\\ 'count_column_query': s:count_query,", "\\ 'count_column_query': s:pg_count_query," },
	{ "\\ 'schemas_query': s:schema_query,", "\\ 'schemas_query': s:pg_schema_query," },
	{
		-- Флаг 'g' обязателен: в запросе теперь два вхождения {db_tbl_name}.
		"{table -> substitute(s:table_column_query, '{db_tbl_name}', \"'\".table.\"'\", '')}",
		"{table -> substitute(s:pg_table_column_query, '{db_tbl_name}', \"'\".table.\"'\", 'g')}",
	},
}

-- Границы словаря s:postgres в тексте файла.
local function postgres_block(src)
	local head = "let s:postgres = {"
	local from = src:find(head, 1, true)
	if not from then
		error("patch: не нашёл словарь s:postgres — апстрим изменился")
	end
	local to = src:find("\n      \\ }", from, true)
	if not to then
		error("patch: не нашёл конец словаря s:postgres — апстрим изменился")
	end
	return from, to
end

local function schemas_path(dir)
	return dir .. "/autoload/vim_dadbod_completion/schemas.vim"
end

function M.apply(dir)
	local path = schemas_path(dir)
	local fd = io.open(path, "r")
	if not fd then
		error("patch: не нашёл " .. path)
	end
	local src = fd:read("*a")
	fd:close()

	if src:find(MARKER, 1, true) then
		return "патч уже наложен"
	end

	-- Оригинал рядом: откат — одна команда cp, без переустановки плагина.
	local backup = path .. ".orig"
	if not vim.uv.fs_stat(backup) then
		vim.fn.writefile(vim.split(src, "\n"), backup)
	end

	local bfrom, bto = postgres_block(src)
	local head, block, tail = src:sub(1, bfrom - 1), src:sub(bfrom, bto), src:sub(bto + 1)

	for _, pair in ipairs(REPLACEMENTS) do
		local from, to = pair[1], pair[2]
		local _, count = block:gsub(vim.pesc(from), "")
		if count ~= 1 then
			error(("patch: якорь встретился в s:postgres %d раз вместо 1 — апстрим изменился:\n%s"):format(count, from))
		end
		block = block:gsub(vim.pesc(from), (to:gsub("%%", "%%%%")), 1)
	end

	src = head .. definitions() .. block .. tail

	vim.fn.writefile(vim.split(src, "\n"), path)
	return "патч наложен: " .. path
end

-- Вернуть плагин в исходное состояние.
function M.revert(dir)
	local path = schemas_path(dir)
	local backup = path .. ".orig"
	if not vim.uv.fs_stat(backup) then
		return "нечего откатывать: " .. backup .. " не найден"
	end
	vim.fn.writefile(vim.fn.readfile(backup), path)
	return "откачено из " .. backup
end

return M
