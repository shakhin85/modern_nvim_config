-- Markdown-таблица под курсором → TSV в "+": Excel/Google Sheets вставляют её ячейками.
-- HTML в буфер не кладём: OSC-52 и lemonade переносят только текст.
local M = {}

local function is_row(line)
	return line:match("^%s*|") ~= nil
end

local function cells(line)
	local s = line:gsub("\\|", "\0"):gsub("^%s*|", ""):gsub("|%s*$", "")
	local out = {}
	for cell in (s .. "|"):gmatch("(.-)|") do
		cell = cell:gsub("%z", "|"):gsub("%*%*(.-)%*%*", "%1"):gsub("`(.-)`", "%1")
		table.insert(out, vim.trim(cell))
	end
	return out
end

function M.yank()
	local lnum = vim.fn.line(".")
	if not is_row(vim.fn.getline(lnum)) then
		vim.notify("Курсор не на строке таблицы", vim.log.levels.WARN)
		return
	end
	local first, last = lnum, lnum
	while first > 1 and is_row(vim.fn.getline(first - 1)) do
		first = first - 1
	end
	while last < vim.fn.line("$") and is_row(vim.fn.getline(last + 1)) do
		last = last + 1
	end

	local rows = {}
	for _, line in ipairs(vim.fn.getline(first, last)) do
		if not line:match("^%s*|[%s:|%-]+|?%s*$") then
			table.insert(rows, table.concat(cells(line), "\t"))
		end
	end
	vim.fn.setreg("+", rows, "l")
	vim.notify(("Таблица в буфере: %d строк (TSV)"):format(#rows))
end

return M
