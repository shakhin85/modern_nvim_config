-- Отодвигает алиасы колонок select на PAD пробелов вправо от самого длинного поля.
-- sqlfluff выравнивает алиасы в колонку (самое длинное поле + 1 пробел), но ширину
-- зазора не настраивает. Этот шаг идёт в conform после sqlfluff и добавляет PAD-1
-- пробелов к каждому выровненному "as": сдвиг одинаковый, колонка сохраняется.
local M = {}

M.PAD = 20

-- Строки from/join тоже несут "as", но там алиас таблицы, а не колонки.
local skip = { select = true, from = true, join = true, left = true, right = true, inner = true, full = true, cross = true }

function M.pad_aliases(lines)
	local out = {}
	for i, line in ipairs(lines) do
		local head, gap, tail = line:match("^(%s+%S.-)(%s+)([Aa][Ss]%s+[%w_\"%[%]]+,?)$")
		if head and not skip[(head:match("^%s*(%a+)") or ""):lower()] then
			line = head .. string.rep(" ", #gap + M.PAD - 1) .. tail
		end
		out[i] = line
	end
	return out
end

return M
