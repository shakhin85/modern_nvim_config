-- Windows: tree-sitter CLI defaults to cl.exe (MSVC); force gcc instead
if vim.fn.has("win32") == 1 then
	vim.env.CC = "gcc"
end

vim.opt.termguicolors = true
vim.opt.tgc = true

require("shako.core")
require("shako.lazy")

local function get_lemonade_cmd()
	-- Проверяем WSL
	local is_wsl = (vim.uv.os_uname().release or ""):lower():find("microsoft") ~= nil

	if is_wsl then
		-- WSL - получаем IP Windows хоста
		local ip_handle = io.popen("ip route show | grep -i default | awk '{ print $3}'")
		local windows_ip = ip_handle:read("*a"):gsub("%s+", "")
		ip_handle:close()

		return {
			copy = string.format("lemonade --host=%s --port=2489 copy", windows_ip),
			paste = string.format("lemonade --host=%s --port=2489 paste | sed 's/\\r$//'", windows_ip),
		}
	else
		-- Нативный Linux
		return {
			copy = "lemonade copy",
			paste = "lemonade paste",
		}
	end
end

local lemonade_cmd = get_lemonade_cmd()

-- Clipboard configuration
if vim.fn.has("win32") == 1 then
	-- Windows: use win32yank
	vim.g.clipboard = {
		name = "win32yank",
		copy = {
			["+"] = "win32yank.exe -i --crlf",
			["*"] = "win32yank.exe -i --crlf",
		},
		paste = {
			["+"] = "win32yank.exe -o --lf",
			["*"] = "win32yank.exe -o --lf",
		},
		cache_enabled = 0,
	}
elseif vim.fn.executable("lemonade") == 1 then
	-- Linux: use lemonade (если нет — nvim сам подберёт xclip/wl-copy)
	vim.g.clipboard = {
		name = "lemonade",
		copy = {
			["+"] = lemonade_cmd.copy,
			["*"] = lemonade_cmd.copy,
		},
		paste = {
			["+"] = lemonade_cmd.paste,
			["*"] = lemonade_cmd.paste,
		},
		cache_enabled = 1,
	}
end

-- Cached Python path detection (lazy-loaded on first Python file)
local python_path_cache = nil

local function get_uv_python()
	-- Return cached result if available
	if python_path_cache then
		return python_path_cache
	end

	-- 1. Приоритет: локальный .venv в текущей директории
	local cwd = vim.fn.getcwd()
	local venv_python

	if vim.fn.has("win32") == 1 then
		-- Windows: use backslashes and proper path
		venv_python = cwd .. "\\.venv\\Scripts\\python.exe"
	else
		venv_python = cwd .. "/.venv/bin/python"
	end

	if vim.fn.executable(venv_python) == 1 then
		python_path_cache = venv_python
		return venv_python
	end

	-- 2. nvim venv с модулем neovim (для самого Neovim)
	local nvim_venv_python
	if vim.fn.has("win32") == 1 then
		nvim_venv_python = vim.fn.expand("~/.local/share/nvim-venv/Scripts/python.exe")
	else
		nvim_venv_python = vim.fn.expand("~/.local/share/nvim-venv/bin/python")
	end

	if vim.fn.executable(nvim_venv_python) == 1 then
		python_path_cache = nvim_venv_python
		return nvim_venv_python
	end

	-- 3. uv python find — асинхронно (см. refresh_uv_python), здесь не блокируем старт

	-- 4. Fallback к системному Python (кросс-платформенно)
	local python_candidates = {}

	if vim.fn.has("win32") == 1 then
		python_candidates = { "python", "python3", "py" }
	else
		python_candidates = { "python3", "python", "/usr/bin/python3" }
	end

	for _, candidate in ipairs(python_candidates) do
		if vim.fn.executable(candidate) == 1 then
			python_path_cache = candidate
			return candidate
		end
	end

	-- 5. Последний fallback
	local fallback = vim.fn.has("win32") == 1 and "python" or "python3"
	python_path_cache = fallback
	return fallback
end

-- uv-managed Python: уточняем асинхронно, не блокируя старт
local function refresh_uv_python()
	if vim.fn.executable("uv") ~= 1 or (python_path_cache and python_path_cache:find("/%.venv/")) then
		return
	end
	vim.system({ "uv", "python", "find" }, { text = true }, function(o)
		local py = vim.trim(o.stdout or "")
		if o.code == 0 and py ~= "" then
			vim.schedule(function()
				python_path_cache = py
				vim.g.python3_host_prog = py
			end)
		end
	end)
end

-- Set Python provider immediately for neovim plugin support
vim.g.python3_host_prog = get_uv_python()
refresh_uv_python()

-- Invalidate cache when changing directories
vim.api.nvim_create_autocmd("DirChanged", {
	callback = function()
		python_path_cache = nil
		vim.g.python3_host_prog = get_uv_python()
		refresh_uv_python()
	end,
})

vim.opt.fileformats = { "unix", "dos" }

-- Перехватываем "+p и "*p для автоматической очистки CR
vim.keymap.set({ "n", "x" }, '"+p', function()
	local content = vim.fn.getreg("+")
	if vim.fn.has("wsl") == 1 and content:find("\r") then
		content = content:gsub("\r\n", "\n"):gsub("\r", "")
		vim.fn.setreg("+", content)
	end
	vim.cmd('normal! "+p')
end, { desc = "Paste from + register (cleaned)" })

vim.keymap.set({ "n", "x" }, '"+P', function()
	local content = vim.fn.getreg("+")
	if vim.fn.has("wsl") == 1 and content:find("\r") then
		content = content:gsub("\r\n", "\n"):gsub("\r", "")
		vim.fn.setreg("+", content)
	end
	vim.cmd('normal! "+P')
end, { desc = "Paste before from + register (cleaned)" })

-- То же самое для "*
vim.keymap.set({ "n", "x" }, '"*p', function()
	local content = vim.fn.getreg("*")
	if vim.fn.has("wsl") == 1 and content:find("\r") then
		content = content:gsub("\r\n", "\n"):gsub("\r", "")
		vim.fn.setreg("*", content)
	end
	vim.cmd('normal! "*p')
end, { desc = "Paste from * register (cleaned)" })

vim.keymap.set({ "n", "x" }, '"*P', function()
	local content = vim.fn.getreg("*")
	if vim.fn.has("wsl") == 1 and content:find("\r") then
		content = content:gsub("\r\n", "\n"):gsub("\r", "")
		vim.fn.setreg("*", content)
	end
	vim.cmd('normal! "*P')
end, { desc = "Paste before from * register (cleaned)" })
