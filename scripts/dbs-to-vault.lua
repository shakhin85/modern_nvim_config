-- Однократный перенос: пароли PG из lua/shako/dbs.local.lua -> Vault (секрет nvim-dbs),
-- в dbs.local.lua остаются URL без паролей. Запуск: nvim -l scripts/dbs-to-vault.lua
-- Пароли идут в vault через stdin, не через argv и не через файл на диске.
local cfg = vim.fn.stdpath("config")
package.path = cfg .. "/lua/?.lua;" .. package.path
local dburl = require("shako.dburl")
local vp = require("shako.vault_pgpass")

local file = cfg .. "/lua/shako/dbs.local.lua"
local passwords = {}
for name, url in pairs(dofile(file)) do
	local parts = dburl.pg_parts(url)
	if parts and parts.pass ~= "" then
		passwords[name] = parts.pass
	end
end
if vim.tbl_isempty(passwords) then
	print("В dbs.local.lua паролей нет — переносить нечего")
	return
end

local put = vim.system({ "vault", "kv", "put", vp.path, "@/dev/stdin" }, { stdin = vim.json.encode(passwords), text = true }):wait()
assert(put.code == 0, "vault kv put: " .. put.stderr)

-- Файл переписываем, только когда Vault вернул ровно то, что положили.
local get = vim.system({ "vault", "kv", "get", "-format=json", vp.path }, { text = true }):wait()
assert(get.code == 0, "vault kv get: " .. get.stderr)
local stored = vim.json.decode(get.stdout).data.data
for name, pass in pairs(passwords) do
	assert(stored[name] == pass, "Vault вернул другое значение для " .. name .. " — dbs.local.lua не тронут")
end

local src = table.concat(vim.fn.readfile(file), "\n")
local stripped = src:gsub("(postgres%a*://[^:/@\"]*):[^@/\"]*@", "%1@")
vim.fn.writefile(vim.split(stripped, "\n"), file)

local names = vim.tbl_keys(passwords)
table.sort(names)
print(("Перенесено в %s: %s"):format(vp.path, table.concat(names, ", ")))
