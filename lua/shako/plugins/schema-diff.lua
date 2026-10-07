-- Сверка схем двух баз двумя способами, потому что они отвечают на разные вопросы.
--   <leader>DD  pg_dump -s обеих баз в vimdiff — видно ВСЁ расхождение целиком,
--               включая комментарии и порядок объектов, но переносить руками.
--   <leader>DM  migra — сразу готовый ALTER-скрипт, но только то, что он умеет
--               выразить в DDL.
local dburl = require("shako.dburl")

local function cache_dir()
	local dir = vim.fn.stdpath("cache") .. "/schema-diff"
	vim.fn.mkdir(dir, "p")
	return dir
end

-- Два последовательных выбора; вторым списком идут все базы, кроме уже выбранной.
local function pick_pair(prompt_a, prompt_b, on_done)
	local names = dburl.pg_names()
	if #names < 2 then
		return vim.notify("Нужны хотя бы две postgres-базы в vim.g.dbs", vim.log.levels.WARN)
	end
	vim.ui.select(names, { prompt = prompt_a }, function(a)
		if not a then
			return
		end
		local rest = vim.tbl_filter(function(n)
			return n ~= a
		end, names)
		vim.ui.select(rest, { prompt = prompt_b }, function(b)
			if b then
				on_done(a, b)
			end
		end)
	end)
end

local function dump_schema(name, path, on_done)
	local safe, env = dburl.pg_split((vim.g.dbs or {})[name])
	local cmd = { "pg_dump", "--schema-only", "--no-owner", "--no-privileges", "--dbname", safe }
	vim.system(cmd, { text = true, env = env }, function(o)
		vim.schedule(function()
			if o.code ~= 0 then
				return vim.notify("pg_dump " .. name .. " упал:\n" .. o.stderr, vim.log.levels.ERROR)
			end
			vim.fn.writefile(vim.split(o.stdout, "\n"), path)
			on_done()
		end)
	end)
end

local function diff_schemas()
	pick_pair("Схема A:", "Схема B (сравнить с A):", function(a, b)
		local dir = cache_dir()
		local pa = ("%s/%s.sql"):format(dir, a)
		local pb = ("%s/%s.sql"):format(dir, b)
		local ready = 0
		local function done()
			ready = ready + 1
			if ready < 2 then
				return
			end
			vim.cmd("tabnew " .. vim.fn.fnameescape(pa))
			vim.cmd("diffthis")
			vim.cmd("vsplit " .. vim.fn.fnameescape(pb))
			vim.cmd("diffthis")
		end
		dump_schema(a, pa, done)
		dump_schema(b, pb, done)
	end)
end

local function migra_diff()
	if vim.fn.executable("migra") == 0 then
		return vim.notify('migra не установлен: uv tool install --python 3.11 --with "setuptools<81" "migra[pg]"', vim.log.levels.WARN)
	end
	pick_pair("migra: из какой базы:", "migra: к какой привести:", function(a, b)
		-- Две базы под разными ролями, одной PGUSER не обойтись — пароли migra
		-- берёт из общего PGPASSFILE (shako.vault_pgpass), а не из argv.
		local url_a = dburl.pg_url_nopass(vim.g.dbs[a])
		local url_b = dburl.pg_url_nopass(vim.g.dbs[b])
		-- --unsafe обязателен: без него migra МОЛЧА пропускает DROP-ы, и неполный
		-- вывод читается как «различий нет».
		vim.system({ "migra", "--unsafe", url_a, url_b }, {
			text = true,
		}, function(o)
			vim.schedule(function()
				-- Коды migra: 0 — схемы совпали, 2 — есть различия, 1 — ошибка.
				-- stderr непустой всегда (deprecation-warning), признаком сбоя не служит.
				if o.code == 0 then
					return vim.notify(("Схемы совпали: %s = %s"):format(a, b))
				end
				if o.code ~= 2 then
					return vim.notify("migra упал:\n" .. o.stderr, vim.log.levels.ERROR)
				end
				vim.cmd("tabnew")
				local buf = vim.api.nvim_get_current_buf()
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(o.stdout, "\n"))
				vim.bo[buf].filetype = "sql"
				vim.bo[buf].buftype = "nofile" -- скрипт на чтение, а не на выполнение
				vim.api.nvim_buf_set_name(buf, ("migra %s → %s"):format(a, b))
			end)
		end)
	end)
end

-- Маппинги ставим сами, а не через lazy keys: сверка схем не зависит ни от
-- одного плагина (только pg_dump, migra и vim.g.dbs), а повесить её на
-- vim-dadbod нельзя — он к этому моменту уже загружен как зависимость
-- vim-dadbod-ui, и lazy для загруженного плагина keys не регистрирует.
vim.keymap.set("n", "<leader>DD", diff_schemas, { desc = "Схемы: pg_dump двух баз в vimdiff" })
vim.keymap.set("n", "<leader>DM", migra_diff, { desc = "Схемы: migra → ALTER-скрипт" })

return {}
