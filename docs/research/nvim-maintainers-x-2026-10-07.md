# Практики Neovim-конфигов с X (2026-10-07)

Срез твитов мейнтейнеров и ключевых контрибьюторов: folke, Saghen, stevearc, mfussenegger, kristijanhusak, tpope, echasnovski, justinmk / @Neovim. Привязка к `lua/shako/plugins/` (blink.lua, formatting.lua, nvim-lint.lua, dadbod.lua, dbee.lua, lsp/).

## Метод

- Дата: 2026-10-07.
- Инструменты этого прогона: Grok `x_keyword_search` / `x_semantic_search` / `x_thread_fetch` (X/Twitter); `agent-reach doctor --json` (twitter-cli установлен, **не аутентифицирован**); dual-graph `graph_read` по текущим spec.
- Status-URL ниже открыты этими вызовами в этом прогоне.

## Практики

### vim.lsp.config полностью заменяет lspconfig.setup

justinmk: в коммите с `lspconfig.denols.setup()` видна путаница — `vim.lsp.config` **полностью** заменяет `require('lspconfig')`, держать оба пути бессмысленно.

Источник: https://x.com/justinmk/status/1941229139706642762

**Как применить в lazy.nvim:** в spec LSP (lua/shako/plugins/lsp/) убрать `require("lspconfig").*.setup`; оставить `vim.lsp.config("<name>", opts)` + `vim.lsp.enable("<name>")`.

### Конфиг сервера — vim.lsp.config(), не только файлы lsp/

justinmk: каталог `lsp/` — не единственный способ; конфиг можно задать `vim.lsp.config()`.

Источник: https://x.com/justinmk/status/1969912132637778047

**Как применить в lazy.nvim:** per-server оверрайды (cmd, root_markers) держать в lua spec `opts`/`config`, не плодить дубли в `lsp/*.lua` и lspconfig.

### vim.lsp.enable стартует клиент по требованию

@Neovim про 0.11.2: `vim.lsp.enable()` starts/stops clients on-demand; есть `is_enabled()`; клиенты отцепляются при смене `'filetype'`.

Источник: https://x.com/Neovim/status/1928431197039759537

**Как применить в lazy.nvim:** в spec LSP вызывать `vim.lsp.enable({ "lua_ls", "gopls", ... })` один раз; не звать `LspStart` на VimEnter.

### LSP молчит, пока не вызван vim.lsp.enable

@Neovim: «LSP is not activated unless you call vim.lsp.enable()».

Источник: https://x.com/Neovim/status/2032569577326903320

**Как применить в lazy.nvim:** после `vim.lsp.config` обязателен `vim.lsp.enable` в том же lua-файле spec; иначе сервер в `lsp/` не аттачится.

### Внешний форматтер не нужен, если у LSP есть format

justinmk: любой formatter-плагин лишний, если у сервера есть format capability.

Источник: https://x.com/justinmk/status/1929834104565989885

**Как применить в lazy.nvim:** в formatting.lua оставить conform для prettier/stylua/sql_formatter; для go/lua с LSP-format — `lsp_format = "fallback"` в `opts` format_on_save (уже так).

### conform: форматтеры + fallback на LSP + format_on_save

Практика вокруг stevearc/conform.nvim: отдельный форматтер, при отсутствии — LSP, легко включить format on save.

Источник: https://x.com/peterszarvas94/status/1902046737130516655

**Как применить в lazy.nvim:** spec `stevearc/conform.nvim` в formatting.lua — `format_on_save` возвращает `{ lsp_format = "fallback" }` (уже; не трогать dadbod-ui буферы).

### nvim-lint: не вешать eslint_d на InsertLeave

eslint_d на InsertLeave лочит Neovim (репорт пользователя плагина mfussenegger/nvim-lint).

Источник: https://x.com/IanMitchel1/status/1823607883004834190

**Как применить в lazy.nvim:** в nvim-lint.lua autocmd сузить до `BufWritePost` (+ `BufEnter`); `InsertLeave` оставить только для дешёвых линтеров, не для eslint_d.

### nvim-lint вместо null-ls

После смерти null-ls стек: mfussenegger/nvim-lint + отдельный format-on-save.

Источник: https://x.com/yutkat/status/1691024601017692160

**Как применить в lazy.nvim:** держать раздельно spec nvim-lint.lua (lint) и formatting.lua (conform); не возвращать none-ls.

### blink.cmp: нативные sources через LSP, не nvim-cmp совместимость

При миграции на Saghen/blink.cmp нет нативного ctags-source: путь — ctags-lsp, не cmp-плагин.

Источник: https://x.com/delphinus35/status/2047475063050662360

**Как применить в lazy.nvim:** в blink.lua `opts.sources.default` — lsp/path/snippets/buffer/dadbod; не тащить cmp-* через blink.compat.

### blink.compat оставляет живые rg-процессы

blink.compat для cmp-source держит rg и тормозит UI; у blink.cmp есть API отмены source.

Источник: https://x.com/delphinus35/status/2046853435706990791

**Как применить в lazy.nvim:** spec blink.lua — только native providers (`vim_dadbod_completion.blink`), без blink.compat.

### SQL в редакторе через dadbod (tpope / kristijanhusak)

Запросы из буфера без отдельного GUI: neovim dadbod.

Источник: https://x.com/eduardovedes/status/1959666292081688646

**Как применить в lazy.nvim:** spec dadbod.lua (`tpope/vim-dadbod`, `kristijanhusak/vim-dadbod-ui`); dbee.lua — второй стек с пагинацией, те же `vim.g.dbs`.

### Snacks Profiler для startuptime / performance

folke: Snacks Profiler — профилировать Lua-старт и hot paths.

Источник: https://x.com/Folke/status/1863218871190126710

**Как применить в lazy.nvim:** в snacks spec включить `opts.profiler` / `:lua Snacks.profiler.scratch()`; смотреть startuptime до правок lazy `event`.

### Выключить checker lazy.nvim

folke: «Disable the checker for lazy.nvim» — апдейт-чекер на старте.

Источник: https://x.com/Folke/status/1674102046687887374

**Как применить в lazy.nvim:** в bootstrap/spec lazy: `opts = { checker = { enabled = false } }` (или `concurrency`/редкий `frequency`).

### jdtls: nvim-jdtls + vim.lsp.enable (mfussenegger)

@Neovim: `vim.pack.add{ nvim-jdtls }` → поправить debug config → `vim.lsp.enable('jdtls')`.

Источник: https://x.com/Neovim/status/2061774033058697441

**Как применить в lazy.nvim:** если появится Java — spec `mfussenegger/nvim-jdtls` + `vim.lsp.enable("jdtls")`, не mason-lspconfig setup.

## Не проверено

- **Saghen** (`blink.cmp` sources/fuzzy/signature): `from:saghen_` / `from:SaghenDev` — **твит не найден**. Профиль: https://x.com (хэндл не подтверждён этим поиском). Signature в blink.lua закомментирован (`signature = { enabled = true }`) — апстрим experimental, без status-ссылки автора.
- **stevearc** (conform/oil от первого лица): `from:stevearc1` — **твит не найден**. Практики conform взяты у пользователей плагина.
- **tpope** (vim-dadbod от первого лица): `from:tpope dadbod` — **твит не найден**.
- **kristijanhusak** (dadbod-ui/completion от первого лица): **твит не найден** (в выдаче только GitHub-trending-боты).
- **echasnovski** / mini.nvim: есть https://x.com/echasnovski/status/1760201592991564097 («Most of mini.nvim») — не конфиг-практика, в счёт 8 не входит.
- twitter-cli (agent-reach) без `TWITTER_AUTH_TOKEN`/`CT0`; все status-ссылки — из Grok X search/thread fetch.
