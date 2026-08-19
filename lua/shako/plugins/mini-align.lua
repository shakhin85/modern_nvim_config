return {
	"echasnovski/mini.align",
	event = "VeryLazy",
	opts = {
		modifiers = {
			-- ga/gA + a: выравнивание списка выражений по ключевому слову AS.
			-- Дефолтные модификаторы ',', '=' и '|' уже покрывают список колонок,
			-- условия WHERE/SET и таблицы результата; AS они не видят.
			["a"] = function(steps, opts)
				opts.split_pattern = "%f[%w][Aa][Ss]%f[%W]"
				table.insert(steps.pre_justify, require("mini.align").gen_step.trim())
				opts.merge_delimiter = " "
			end,
			-- ga/gA + o: выравнивание условий соединения по ON в цепочке JOIN.
			["o"] = function(steps, opts)
				opts.split_pattern = "%f[%w][Oo][Nn]%f[%W]"
				table.insert(steps.pre_justify, require("mini.align").gen_step.trim())
				opts.merge_delimiter = " "
			end,
		},
	},
}
