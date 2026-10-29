-- Таблица под курсором → TSV в "+": Excel/Google Sheets вставляют её ячейками.
-- Форматы: markdown (| a | b |) и box-drawing (│ a │ b │) — второй печатают CLI и агенты.
-- Word/Outlook берут таблицу с рамками из HTML-формата буфера — его кладёт put() через Windows-помощник.
local M = {}

local BORDER = "┌├└┬┼┴─╞╪╘╒╔╠╚═"

-- "|"/"│" — строка данных с этим разделителем, "rule" — линия рамки, nil — не таблица.
local function kind(line)
	local s = vim.trim(line)
	if s:find("^|") then
		return s:match("^|[%s:|%-]+|?$") and "rule" or "|"
	end
	local ch = vim.fn.strcharpart(s, 0, 1)
	if ch == "│" or ch == "║" then
		return "│"
	end
	if ch ~= "" and BORDER:find(ch, 1, true) then
		return "rule"
	end
end

local function cells(line, sep)
	local s = vim.trim(line):gsub("║", "│"):gsub("\\|", "\0")
	s = s:sub(#sep + 1)
	if s:sub(-#sep) == sep then
		s = s:sub(1, -#sep - 1)
	end
	local out = {}
	for _, cell in ipairs(vim.split(s, sep, { plain = true })) do
		cell = cell:gsub("%z", "|"):gsub("%*%*(.-)%*%*", "%1"):gsub("`(.-)`", "%1")
		table.insert(out, vim.trim(cell))
	end
	return out
end

-- "12 450" / "5 120,5" → без пробелов-разрядов, иначе Excel берёт ячейку как текст.
-- Только строгие группы по 3 цифры: телефон "8 800 555 35 35" не трогаем.
local GROUPED = vim.regex([[\v^-?\d{1,3}([  ]\d{3})+([,.]\d+)?$]])
local function number(cell)
	return GROUPED:match_str(cell) and cell:gsub("[  ]", "") or cell
end

-- Ячейка box-таблицы, перенесённая на следующую строку рамки: первая колонка пустая.
local function continues(row, prev)
	return prev and row[1] == "" and #row == #prev
end

local function html(rows)
	local function esc(s)
		return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
	end
	local out = { '<table border="1" style="border-collapse:collapse">' }
	for r, row in ipairs(rows) do
		local tag = r == 1 and "th" or "td"
		local tr = {}
		for _, cell in ipairs(row) do
			table.insert(tr, ("<%s>%s</%s>"):format(tag, esc(cell), tag))
		end
		table.insert(out, "<tr>" .. table.concat(tr) .. "</tr>")
	end
	table.insert(out, "</table>")
	return table.concat(out)
end

-- Буфер Windows получает Text (TSV) + HTML через scripts/clip-html.ps1 на winhost.
-- Помощник недоступен → только TSV через "+ (OSC 52 + lemonade): Excel всё равно берёт ячейки.
-- "+ при успехе не пишем: асинхронная копия lemonade затёрла бы HTML-формат текстом.
local function put(rows)
	local tsv = vim.tbl_map(function(row)
		return table.concat(row, "\t")
	end, rows)
	vim.fn.setreg('"', tsv, "l")
	local payload = table.concat(tsv, "\n") .. "\n\0" .. html(rows)
	vim.system(
		{ "ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=3", "-W", "127.0.0.1:2490", "winhost" },
		{ stdin = payload, timeout = 5000 },
		vim.schedule_wrap(function(r)
			if r.code == 0 and vim.trim(r.stdout or "") == "ok" then
				vim.notify(("Таблица в буфере: %d строк (TSV + HTML)"):format(#rows))
				return
			end
			vim.fn.setreg("+", tsv, "l")
			-- Порт закрыт → Windows sshd отдаёт exit 0 и пустой ответ, поэтому проверяем именно "ok".
			local reply = vim.trim((r.stdout or "") .. " " .. (r.stderr or ""))
			local why = reply == "" and "помощник не отвечает на winhost:2490" or reply
			vim.notify(("Таблица в буфере: %d строк (только TSV, clip-html: %s)"):format(#rows, why), vim.log.levels.WARN)
		end)
	)
end

function M.yank()
	local lnum = vim.fn.line(".")
	if not kind(vim.fn.getline(lnum)) then
		vim.notify("Курсор не на строке таблицы", vim.log.levels.WARN)
		return
	end
	local first, last = lnum, lnum
	while first > 1 and kind(vim.fn.getline(first - 1)) do
		first = first - 1
	end
	while last < vim.fn.line("$") and kind(vim.fn.getline(last + 1)) do
		last = last + 1
	end

	-- prev сбрасывается на линии рамки: строка после ├──┤ — новая запись, не перенос.
	local rows, prev = {}, nil
	for _, line in ipairs(vim.fn.getline(first, last)) do
		local k = kind(line)
		if k == "rule" then
			prev = nil
		else
			local row = cells(line, k)
			if k == "│" and continues(row, prev) then
				for i, cell in ipairs(row) do
					if cell ~= "" then
						prev[i] = prev[i] == "" and cell or prev[i] .. " " .. cell
					end
				end
			else
				table.insert(rows, row)
				prev = row
			end
		end
	end
	if #rows == 0 then
		vim.notify("В таблице нет строк данных", vim.log.levels.WARN)
		return
	end
	for _, row in ipairs(rows) do
		for i, cell in ipairs(row) do
			row[i] = number(cell)
		end
	end
	put(rows)
end

return M
