# Neovim-практики 2025–2026 (r/neovim + CN)

Срез: 2026-10-07. Nvim 0.11–0.12. Источники: r/neovim (rdt-cli), GitHub issues, Bilibili, V2EX, 掘金, 知乎, 博客园, 少数派.

## Reddit (r/neovim)

1. **blink.cmp 1.0 — де-факто стандарт completion.** Saghen анонсировал 1.0 ([1jjpk7g](https://www.reddit.com/r/neovim/comments/1jjpk7g/), 1042↑) и beta ([1fyh2bn](https://www.reddit.com/r/neovim/comments/1fyh2bn/), 959↑). В 2025-гайдах blink стоит рядом с oil/conform: [1jfok8l](https://www.reddit.com/r/neovim/comments/1jfok8l/) (linkarzu, 42 мин, dadbod + nvim-lint + blink), [1my7wvi](https://www.reddit.com/r/neovim/comments/1my7wvi/) (codingmilk: blink + conform + dadbod).

2. **cmdline: сначала не было, потом включили, потом отключают.** Тред [1hh4pw2](https://www.reddit.com/r/neovim/comments/1hh4pw2/): до 2024-12 cmdline не всплывал без Tab, `preset = super-tab` в insert не применялся к `:`/`/`. Автор обновил пост: cmdline реализован, конфиг из docs заработал. Отключение: [1ht17pe](https://www.reddit.com/r/neovim/comments/1ht17pe/). Цикл в cmdline: [1hlctjs](https://www.reddit.com/r/neovim/comments/1hlctjs/). LazyVim 15 явно **включила** blink cmdline ([1njdl3o](https://www.reddit.com/r/neovim/comments/1njdl3o/), 873↑) и сразу поправила поведение «как обычный cmdline».

3. **dadbod source в blink — per_filetype, не default.** Официальный рецепт Saghen: `per_filetype.sql = { 'dadbod' }`, `providers.dadbod = { module = "vim_dadbod_completion.blink" }` ([docs/sources](https://cmp.saghen.dev/configuration/sources)). Fuzzy по колонкам/таблицам **не** работает как у LSP: [dadbod-completion#90](https://github.com/kristijanhusak/vim-dadbod-completion/issues/90) — `apic` не матчит `api_call_logs`. Пустой кэш схемы → только buffer; обход в issue #88: дождаться `b:db` и `vim_dadbod_completion#omni` / fetch.

4. **signature help в blink ещё сырой.** Open: [#1071 stabilization](https://github.com/saghen/blink.cmp/issues/1071), [#2236 cmdline-like signature](https://github.com/saghen/blink.cmp/issues/2236), [#2626 toggle docs inside signature](https://github.com/saghen/blink.cmp/issues/2626). Многие оставляют native `vim.lsp.buf.signature_help` на `K`/`C-s`.

5. **LazyVim 15 = канон миграции на 0.11.** [1njdl3o](https://www.reddit.com/r/neovim/comments/1njdl3o/): Neovim ≥ 0.11.2; **mason + mason-lspconfig v2**; native `vim.lsp.config`; treesitter `main` (нужен `tree-sitter` CLI); blink cmdline; LSP folds. Старый nvim — pin, [LazyVim#6421](https://github.com/LazyVim/LazyVim/issues/6421).

6. **mason-lspconfig v2: `setup_handlers` мёртв, `vim.lsp.enable` делает mason.** Тред [1khusqb](https://www.reddit.com/r/neovim/comments/1khusqb/) (75↑): `vim.lsp.config("*", {})` + `vim.lsp.enable({...})`. Топ-коммент — пример автора Mason: [williamboman/nvim-config@mason-v2-example](https://github.com/williamboman/nvim-config/tree/mason-v2-example). Конфиг сервера — `after/lsp/<name>.lua` / `lsp/<name>.lua` в rtp (`:h lsp-config`). Релиз [mason-lspconfig v2.0.0](https://github.com/mason-org/mason-lspconfig.nvim/releases/tag/v2.0.0): Neovim 0.11, Mason v2, lspconfig v2; `automatic_enable` по умолчанию; `handlers`/`automatic_installation` удалены. Ловушка lazy-load: `vim.lsp.enable` после FileType → LSP не цепляется, пока не отредактируешь буфер ([#545](https://github.com/mason-org/mason-lspconfig.nvim/issues/545), williamboman).

7. **vim.lsp.config после enable не применяется.** [1mhx924](https://www.reddit.com/r/neovim/comments/1mhx924/) — норма: конфиг резолвится при старте клиента. 0.11.2 починил enable: [1kz0a23](https://www.reddit.com/r/neovim/comments/1kz0a23/).

8. **conform + SQL: dialect из файла, не хардкод; DBUI не форматировать.** Embedded SQL в Python не трогается, если нет injected: [19e6b6a](https://www.reddit.com/r/neovim/comments/19e6b6a/) (`formatters_by_ft` + `injected`). LazyVim extra: убрать `--dialect=postgres` из args, чтобы читался `.sqlfluff` ([LazyVim#4594](https://github.com/LazyVim/LazyVim/discussions/4594)). sqlfluff+dbt: stdin не работает — `stdin=false`, `args = { "fix", "$FILENAME" }` ([conform#708](https://github.com/stevearc/conform.nvim/issues/708)). sql-formatter на Windows/MSYS2 ломает path ([#887](https://github.com/stevearc/conform.nvim/issues/887)).

9. **nvim-lint + sqlfluff: дефолт уже stdin, TextChanged ломался исторически.** Апстрим сейчас: `args = { "lint", "--format=json", "-" }`, `stdin = true` ([sqlfluff.lua](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/sqlfluff.lua)). Старый баг TextChanged: [#469](https://github.com/mfussenegger/nvim-lint/issues/469) — stdin когда-то выключали (#294); обход: явно `stdin=true` + `"-"`. Триггеры в дикой природе: `BufWritePost` + `InsertLeave`; `TextChanged` через `vim.defer_fn`. Альтернатива zero-config: [simple-sqlfluff.nvim](https://github.com/michhernand/simple-sqlfluff.nvim) (реддит [1kj44p0](https://www.reddit.com/r/neovim/comments/1kj44p0/), тест на 0.11).

10. **dadbod: UI живой, рантайм janky.** [1gqfvf9](https://www.reddit.com/r/neovim/comments/1gqfvf9/) (38 комм.): freeze на запросе; отдельный nvim-инстанс; не закрывает коннекты (max connections); CSV-экспорт нет ([ui#354](https://github.com/kristijanhusak/vim-dadbod-ui/issues/354)). Альтернативы в треде: lazysql, rainfrog, harlequin, [nvim-dbee](https://www.reddit.com/r/neovim/comments/13ggdto/), sqlua.nvim. Oracle+sqlcl медленный, схемы не грузятся: [1pd8azu](https://www.reddit.com/r/neovim/comments/1pd8azu/).

## Китайские ресурсы

1. **知乎 · Neovim 中文周刊 №4 (2025-03)** — [zhuanlan.zhihu.com/p/1889355418687472162](https://zhuanlan.zhihu.com/p/1889355418687472162). Сводка r/neovim: в 0.11 всё ещё берут blink/nvim-cmp (fuzzy, non-LSP sources, ghost text, signature), не `vim.lsp.completion`. mini.completion — «идеальная форма» встроенного omni (любой символ, TS signature). echasnovski готов апстримить mini, ядро взяло nvim-lsp-compl. Статья gpanders: `vim.lsp.config`/`enable`, lspconfig → репозиторий дефолтов.

2. **知乎 · LazyVim vs LunarVim vs AstroNvim** — [question/643266503](https://www.zhihu.com/question/643266503/answer/2009929706452034880). LunarVim мёртв; LazyVim — живой (автор = топ-плагины); свой конфиг на breaking changes 0.10/0.11 дорого.

3. **知乎 · Termux + LazyVim keymaps (2025-09)** — [p/1956393885480747277](https://zhuanlan.zhihu.com/p/1956393885480747277). `lua/config/keymaps.lua`; yank → `termux-clipboard-set`. Паттерн: не трогать extras, патчить только keymaps.

4. **知乎 · minuet-ai.nvim + blink.cmp** — [p/21665712730](https://zhuanlan.zhihu.com/p/21665712730). LLM-completion как source blink/cmp; throttle отдельно от blink. CN-практика: Deepseek/Ollama, не Copilot binary.

5. **知乎 · LSP для нескольких языков (NvChad-era)** — [p/667884657](https://zhuanlan.zhihu.com/p/667884657). pyright/clangd/tsserver через `servers = {...}` в lspconfig. Для 0.11 это уже legacy: список серверов → `vim.lsp.enable`.

6. **掘金 · 2026 конфиг, 30 минут** — [juejin.cn/post/7594028166135529472](https://juejin.cn/post/7594028166135529472) (2026-01). Таблица VSCode→nvim: completion = **blink.cmp + Mason**; поиск = Telescope/snacks; новичкам LazyVim starter, дальше модули. Скрин с blink в статье.

7. **掘金 · конфиг-диета 493→55 строк** — [juejin.cn/post/7663184761033572388](https://juejin.cn/post/7663184761033572388) (2026-07). 0.11/0.12: `vim.pack.add`, mini.* вместо which-key/gitsigns/startify. Совпадает с echasnovski. Oil/fzf-lua/fugitive **не** меняют на mini (preview/index).

8. **掘金 · Neovim Go IDE** — [post/7487142802662031394](https://juejin.cn/post/7487142802662031394). Mason+lspconfig стек для gopls; типичный CN-путь «сначала distro, потом extra lang».

9. **V2EX · LazyDB (2026)** — [t/1240547](https://www.v2ex.com/t/1240547). TUI Postgres/MySQL/SQLite/SQL Server + **nvim-плагин с LSP completion колонок**. Прямой конкурент dadbod в CN-треде; MCP для агентов.

10. **V2EX · «ещё на Vim?»** — [t/1236792](https://www.v2ex.com/t/1236792) (86 replies). C/C++ + Claude Code в Vim; привычка, не IDE-фичи. Соседние: [t/1196307](https://www.v2ex.com/t/1196307) (AI vs ручной LSP), GUI [nvim-gpui](https://www.v2ex.com/t/1240339) (nerd font + snacks.image).

11. **V2EX · LazyVim LSP signature popup** — [t/1100396](https://www.v2ex.com/t/1100396). Как убрать «подробности функции» (signature/docs). Практический CN-баг blink/noice/lsp: отключить `signature.enabled` или `docs.auto_show` в blink. Рекомендация LazyVim: [t/934194](https://www.v2ex.com/t/934194).

12. **Bilibili · blink.cmp как учебник.** [BV1kVPhzUE5v](https://www.bilibili.com/video/BV1kVPhzUE5v/) (jiazZel, dotfiles); cmdline [BV1TWoyYsEDS](https://www.bilibili.com/video/BV1TWoyYsEDS/) + [BV1WE52zoE2r](https://www.bilibili.com/video/BV1WE52zoE2r/) (ссылка на cmp.saghen.dev); intro [BV1Y3wreeEgH](https://www.bilibili.com/video/BV1Y3wreeEgH/); LSP [BV1iG7rzTEaz](https://www.bilibili.com/video/BV1iG7rzTEaz/) (11k plays); kickstart [BV1h4wxzmExk](https://www.bilibili.com/video/BV1h4wxzmExk/).

13. **博客园 · 0.11.5 vs 0.12** — [cnblogs.com/codigger/p/19326801](https://www.cnblogs.com/codigger/p/19326801). 0.11.5 — прод (LSP float flicker, diagnostic virt text opt-in). 0.12 — `vim.pack`, lsp-файлы в rtp, `vim.lsp.enable("gitlab_duo")`, signature latency. Другие: LSP внутренности [p/19000504](https://www.cnblogs.com/wzzkaifa/p/19000504); LazyVim Python/C++ [p/19795323](https://www.cnblogs.com/yuanshq/p/19795323); headless LSP clients=0 [p/23077541](https://www.cnblogs.com/owlman/p/23077541) (GUI vs `nvim --headless`).

14. **少数派 · Kickstart** — [sspai.com/post/90115](https://sspai.com/post/90115). kickstart-modular + `NVIM_APPNAME`; mason + lspconfig + nvim-cmp (статья 2024, до blink). CN-новички всё ещё стартуют отсюда; 2026-гайды на 掘金 уже ставят blink вместо cmp.

## Известные баги DB-плагинов

| Симптом | Issue | Обход |
|---|---|---|
| blink dadbod: completion есть, fuzzy нет (`apic` ↛ `api_call_logs`) | [completion#90](https://github.com/kristijanhusak/vim-dadbod-completion/issues/90) | Prefix-match; не ждать fuzzy как у LSP |
| blink dadbod молчит, omni работает | [completion#88](https://github.com/kristijanhusak/vim-dadbod-completion/issues/88) (closed: плохой spec) | `sources.per_filetype.sql = { "dadbod" }`, `module = "vim_dadbod_completion.blink"`; `b:db` до fetch. Исторически `kind` ломал blink: [#78](https://github.com/kristijanhusak/vim-dadbod-completion/issues/78), [#79](https://github.com/kristijanhusak/vim-dadbod-completion/issues/79) |
| Пустой кэш схемы / колонки не всплывают | [#50](https://github.com/kristijanhusak/vim-dadbod-completion/issues/50), [#3](https://github.com/kristijanhusak/vim-dadbod-completion/issues/3) | Лимит ~10k колонок — lazy-load. Вызвать `vim_dadbod_completion#fetch` **после** `b:db` (`vim.schedule`). Профиль `profile func *` |
| Postgres `search_path`: файл целиком ок, кусок — «relation does not exist» | [ui#229](https://github.com/kristijanhusak/vim-dadbod-ui/issues/229) | `SET search_path TO schema;` в каждый statement **или** qualify `schema.table`. Сессионного search_path у DBUI нет |
| Views / materialized views свалены с tables | [ui#222](https://github.com/kristijanhusak/vim-dadbod-ui/issues/222), [#123](https://github.com/kristijanhusak/vim-dadbod-ui/issues/123) | Нет категории views. Не INSERT в multi-table view. MV руками через SQL |
| DBUI result format (SQL Server обрезает колонки) | [ui#283](https://github.com/kristijanhusak/vim-dadbod-ui/issues/283) | Формат = CLI (`sqlcmd`), не UI. `SQLCMDMAXVARTYPEWIDTH=36` + `SQLCMDMAXFIXEDTYPEWIDTH=36` |
| format_on_save ломает query/result буферы | [ui#280](https://github.com/kristijanhusak/vim-dadbod-ui/issues/280) (буфер на каждый `:w`) | `format_on_save` skip `buftype ~= ""` / filetype `dbui`/`dbout`; не писать result |
| Freeze UI на запросе; max connections | Reddit [1gqfvf9](https://www.reddit.com/r/neovim/comments/1gqfvf9/) | Отдельный nvim; TUI (lazysql/LazyDB); dbee (свой Go-рантайм) |
| MySQL completion мёртв, Postgres жив | [completion#85](https://github.com/kristijanhusak/vim-dadbod-completion/issues/85) | Проверить CLI `mysql` vs `mariadb`; schema empty: [ui#331](https://github.com/kristijanhusak/vim-dadbod-ui/issues/331) |
| Alias колонок | [completion#62](https://github.com/kristijanhusak/vim-dadbod-completion/issues/62), [#67](https://github.com/kristijanhusak/vim-dadbod-completion/issues/67) | Один alias на таблицу; `t.` после FROM |
| sqlcomplete#DrillIntoTable E117 | [completion#92](https://github.com/kristijanhusak/vim-dadbod-completion/issues/92) | Не использовать omni drill без sqlcomplete |
| nvim-dbee: 0.13 `BufModifiedSet` invalid | [dbee#241](https://github.com/kndndrj/nvim-dbee/issues/241) | Не nightly 0.13 без патча; на 0.11/0.12 ок |
| dbee не закрывает коннект / pgbouncer max | [#172](https://github.com/kndndrj/nvim-dbee/issues/172), [#152](https://github.com/kndndrj/nvim-dbee/issues/152) | Рестарт nvim; лимит пула на сервере |
| dbee cmdline cmp | [#161](https://github.com/kndndrj/nvim-dbee/issues/161) | Нет cmdline source; только editor buffer |
| BigQuery tables не в drawer | [ui#341](https://github.com/kristijanhusak/vim-dadbod-ui/issues/341) | Query руками; drawer неполный |
| Oracle slow / empty result | [ui#317](https://github.com/kristijanhusak/vim-dadbod-ui/issues/317), [#328](https://github.com/kristijanhusak/vim-dadbod-ui/issues/328), reddit 1pd8azu | Не sqlcl-daemon; ожидать секунды; схемы DBUI не видит |

## Что берут из конфигов мейнтейнеров

| Кто | Что копируют |
|---|---|
| **folke / LazyVim** | 0.11.2 floor; mason v2; `vim.lsp.config` + enable; blink **cmdline on**; LSP folds; treesitter `main`. Личный [folke/dot](https://github.com/folke/dot): mini.align, lazydev, без ручного mason-handlers. |
| **Saghen** | Docs = спецификация: dadbod только `per_filetype.sql`; cmdline/term отдельно от insert; `:BlinkCmp status`; compat слой для cmp-sources. Личный `Saghen/nvim`: `lua/{config,core,langs}`. |
| **stevearc** | [dotfiles format.lua](https://github.com/stevearc/dotfiles): `event = BufWritePre`, `lsp_format = "fallback"`, ручной `gqq` async; `format_on_save` в личном конфиге **выключен** (search: `opts.format_on_save = false`). SQL: sqlfluff `stdin=false` для dbt. |
| **echasnovski** | mini.nvim как замена which-key/files/pick/completion. CN 掘金 и 知乎-дневник прямо советуют mini.completion вместо blink, если нужен omni-стиль. |
| **mfussenegger** | nvim-lint узкий: spawn + diagnostics. sqlfluff json+stdin. Триггер не в плагине — autocmd пользователя (`BufWritePost`/`InsertLeave`). |

## Практический минимум под SQL-стек (из пересечения источников)

```lua
-- blink: dadbod не в default
sources = {
  default = { "lsp", "path", "snippets", "buffer" },
  per_filetype = { sql = { "dadbod" } },
  providers = { dadbod = { module = "vim_dadbod_completion.blink" } },
}
-- cmdline: включить как LazyVim 15 или выключить keymap.cmdline
-- LSP 0.11: vim.lsp.config + mason-lspconfig v2 automatic_enable; не setup_handlers
-- conform: sqlfluff без --dialect; skip DBUI/dbout; dbt → stdin=false
-- lint: sqlfluff stdin=true args={"lint","--format=json","-"}; BufWritePost+InsertLeave
```

Метод: agent-reach (reddit=rdt-cli, bilibili=bili-cli, v2ex=public API + sov2ex, github=gh). Zhihu search UI — капча; статьи взяты по прямым URL.
