; extends
; Операторы SQL в четырёх цветах: в tokyonight @operator и @keyword.operator совпадают,
; и "=" не отличить от AND. Парсер sql общий для PostgreSQL и T-SQL.
; Цвета групп — lua/shako/plugins/colorscheme.lua (on_highlights).
[(keyword_and) (keyword_or) (keyword_not)] @keyword.operator.logical
[(keyword_in) (keyword_is) (keyword_like) (keyword_between) (keyword_exists)] @keyword.operator.predicate
["=" "<" "<=" "!=" ">=" ">" "<>"] @operator.comparison
["+" "-" "/" "%" "^"] @operator.arithmetic
