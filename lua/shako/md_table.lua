-- Таблица под курсором → TSV в "+": Excel/Google Sheets вставляют её ячейками.
-- Форматы: markdown (| a | b |) и box-drawing (│ a │ b │) — второй печатают CLI и агенты.
-- HTML в буфер не кладём: OSC-52 и lemonade переносят только текст.
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
	vim.fn.setreg(
		"+",
		vim.tbl_map(function(row)
			return table.concat(vim.tbl_map(number, row), "\t")
		end, rows),
		"l"
	)
	vim.notify(("Таблица в буфере: %d строк (TSV)"):format(#rows))
end

return M
