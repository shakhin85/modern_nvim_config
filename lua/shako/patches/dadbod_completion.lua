-- Патч vim-dadbod-completion: матвью и функции PostgreSQL, дополнение после `(`.
--
-- Функции. Апстрим берёт плоские имена из information_schema.routines: там нет
-- агрегатов (routine_type NULL, это sum и count), а после `dm.` функции не предлагает
-- вовсе. Проверено на lime_prod: `dm.ge` → 0 пунктов при 22 функциях в схеме dm.
-- Берём pg_proc со схемой и добавляем функции в ветку schema_scope у omni.
--
-- Граница слова. blink-провайдер апстрима делит слово только по пробелу: в
-- `coalesce(pg_siz` он получает мусор вместо `pg_siz` и отдаёт пустой список.
--
-- Апстрим берёт схему из INFORMATION_SCHEMA.COLUMNS (schemas.vim:1-5), а матвью
-- там нет — они лежат в pg_class с relkind='m'. Проверено на базе omman:
-- 8 матвью из 8 невидимы, при том что таблиц там 7. Точки расширения у плагина
-- нет: запросы объявлены скриптовыми переменными s:, снаружи их не подменить.
--
-- Поэтому патчим копию файла, но только словарь s:postgres — общие s:query и
-- s:table_column_query трогать нельзя, на них сидят MySQL и MSSQL.
-- Копия лежит вне каталога плагина: правка на месте делает его git-дерево
-- грязным, и lazy отказывается обновлять плагин. Каталог копии стоит в
-- runtimepath раньше плагина, поэтому autoload находит её первой.
-- Копия пересобирается, когда оригинал новее, и сборка падает с ошибкой, если
-- апстрим изменил строку: молчащее автодополнение хуже сборки, которая громко упала.
local M = {}

local MARKER = '" shako: matview-aware queries'

-- Матвью PostgreSQL: колонки из pg_attribute, отсеивая системные и удалённые.
local MV_COLUMNS = "SELECT c.relname,a.attname FROM pg_class c "
	.. "JOIN pg_namespace n ON n.oid=c.relnamespace "
	.. "JOIN pg_attribute a ON a.attrelid=c.oid "
	.. "WHERE c.relkind='m' AND a.attnum>0 AND NOT a.attisdropped"

local MV_NAMES = "SELECT n.nspname,c.relname FROM pg_class c "
	.. "JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind='m'"

-- Функции, агрегаты и оконные; процедуры в SELECT не вызвать.
local FUNCTIONS = "SELECT n.nspname,p.proname FROM pg_proc p "
	.. "JOIN pg_namespace n ON n.oid=p.pronamespace "
	.. "WHERE p.prokind IN ('f','a','w') GROUP BY 1,2"

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
		'let s:pg_functions_query = "' .. FUNCTIONS .. '"',
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
		"\\ 'functions_query': \"SELECT DISTINCT(routine_name) FROM information_schema.routines WHERE routine_type='FUNCTION'\",",
		"\\ 'functions_query': s:pg_functions_query,",
	},
	-- list[1:] отбрасывает заголовок psql: иначе он станет функцией proname.
	{ "\\ 'functions_parser': {list->list[1:-4]},", "\\ 'functions_parser': {list -> s:map_and_filter('|', list[1:])}," },
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

local SCHEMAS = "autoload/vim_dadbod_completion/schemas.vim"
local OMNI = "autoload/vim_dadbod_completion.vim"
local BLINK = "lua/vim_dadbod_completion/blink.lua"

-- Заменить ровно одно вхождение: другое число значит, что апстрим изменился.
local function replace_once(src, from, to)
	local start, stop = src:find(from, 1, true)
	if not start or src:find(from, stop + 1, true) then
		error("patch: якорь встретился не 1 раз — апстрим изменился:\n" .. from)
	end
	return src:sub(1, start - 1) .. to .. src:sub(stop + 1)
end

local function patch_schemas(src)
	local bfrom, bto = postgres_block(src)
	local block = src:sub(bfrom, bto)
	for _, pair in ipairs(REPLACEMENTS) do
		block = replace_once(block, pair[1], pair[2])
	end
	return src:sub(1, bfrom - 1) .. definitions() .. block .. src:sub(bto + 1)
end

local function patch_omni(src)
	src = replace_once(
		src,
		[[  let s:cache[a:db].functions = s:cache[a:db].scheme.functions_parser(a:functions)
  call map(s:cache[a:db].functions, {i,fn -> {'word': fn, 'abbr': fn, 'menu': s:mark, 'info': 'Function', 'kind': 'F' }})
]],
		[[  let names = {}
  let by_schema = {}
  for [schema, fn] in s:cache[a:db].scheme.functions_parser(a:functions)
    let names[fn] = 1
    if !has_key(by_schema, schema)
      let by_schema[schema] = []
    endif
    call add(by_schema[schema], {'word': fn, 'abbr': fn, 'menu': s:mark, 'info': 'Function in '.schema, 'kind': 'F' })
  endfor
  let s:cache[a:db].functions_by_schema = by_schema
  let s:cache[a:db].functions = map(sort(keys(names)), {i,fn -> {'word': fn, 'abbr': fn, 'menu': s:mark, 'info': 'Function', 'kind': 'F' }})
]]
	)
	return replace_once(
		src,
		[[  if !empty(schema_scope)
    let tables = copy(cache_db.schemas[schema_scope])
]],
		[[  if !empty(schema_scope)
    let functions = copy(get(get(cache_db, 'functions_by_schema', {}), schema_scope, []))
    if should_filter
      call filter(functions, 'v:val.abbr =~? s:filter_rgx.a:base')
    endif
    let functions = functions[0:s:limit('functions')]
    let tables = copy(cache_db.schemas[schema_scope])
]]
	)
end

local function patch_blink(src)
	return replace_once(src, "char:match('%s')", "char:match('[^%w_]')")
end

local PATCHES = { [SCHEMAS] = patch_schemas, [OMNI] = patch_omni, [BLINK] = patch_blink }

-- Каталог для runtimepath: в нём лежат пропатченные файлы.
M.root = vim.fn.stdpath("data") .. "/shako-patches/dadbod-completion"

-- Собрать пропатченные копии из закоммиченного оригинала плагина:
-- HEAD не зависит от рабочего дерева, даже если там остались чужие правки.
function M.apply(dir)
	for rel, patch in pairs(PATCHES) do
		local res = vim.system({ "git", "-C", dir, "show", "HEAD:" .. rel }, { text = true }):wait()
		if res.code ~= 0 then
			error("patch: git show не отдал " .. rel .. ": " .. res.stderr)
		end
		local out = M.root .. "/" .. rel
		vim.fn.mkdir(vim.fs.dirname(out), "p")
		vim.fn.writefile(vim.split(patch(res.stdout), "\n"), out)
	end
	return "патч собран: " .. M.root
end

-- Копия устарела: её нет, либо оригинал или сам этот патч новее неё.
local function stale(dir)
	local self_path = debug.getinfo(1, "S").source:sub(2)
	local self_mtime = vim.uv.fs_stat(self_path).mtime.sec
	for rel in pairs(PATCHES) do
		local copy = vim.uv.fs_stat(M.root .. "/" .. rel)
		local orig = vim.uv.fs_stat(dir .. "/" .. rel)
		if not copy or copy.mtime.sec < orig.mtime.sec or copy.mtime.sec < self_mtime then
			return true
		end
	end
	return false
end

-- Пересобрать копии, если они устарели, и поставить их в runtimepath первыми.
function M.setup(dir)
	if not vim.uv.fs_stat(dir .. "/" .. SCHEMAS) then
		return -- плагин ещё не установлен
	end
	if stale(dir) then
		M.apply(dir)
	end
	vim.opt.rtp:prepend(M.root)
end

return M
