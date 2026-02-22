-- Windows: tree-sitter CLI defaults to cl.exe (MSVC); force gcc instead
if vim.fn.has("win32") == 1 then
	vim.env.CC = "gcc"
end

vim.opt.termguicolors = true
vim.opt.tgc = true

require("shako.core")
require("shako.lazy")

