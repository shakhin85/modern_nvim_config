# SQL UX в Neovim, 2025–2026

Дата: 2026-10-16. Read-only research. Конфиг уже содержит: nvim-dbee, vim-dadbod-ui, dadbod-completion через blink (матвью-патч), sqlfluff formatter, treesitter SQL, tokyonight `@keyword.sql`, live psql в toggleterm (`<leader>Dr/Dq`), schema diff pg_dump+migra, export xlsx, Postgres+MSSQL, Vault pgpass. В `dadbod.lua`/`dbee.lua` также уже есть Grip (history/explain/profile), visidata/csvlens, yank CSV/JSON/XML, `<leader>S` на буфер/выделение — эти вещи в топ-10 не входят.

Источники: r/neovim через rdt-cli, GitHub `gh`, YouTube (yt-dlp + transcript), Exa, Wigolo.

## Что говорят в 2025–2026

- r/neovim всё ещё крутится вокруг dadbod/dbee, но топ постов года — новые клиенты: [sqlit.nvim](https://www.reddit.com/r/neovim/comments/1qswj2z/sqlitnvim_a_lazygit_style_inspired_sql_neovim/) (~775↑, TUI как lazygit, [Maxteabag/sqlit](https://github.com/Maxteabag/sqlit) 4.9k★), [sqmeow.nvim](https://www.reddit.com/r/neovim/comments/1wm9llk/sqmeownvim_rustpowered_db_client_for_neovim/) (~330↑, statement-under-cursor + grid edit), [sqlserver.nvim](https://www.reddit.com/r/neovim/comments/1wc7i72/sqlservernvim_a_sql_servernative_workspace_for/) (SSMS-like, процедуры, которых нет в DBUI).
- YouTube: TJ [Vim Dadbod](https://www.youtube.com/watch?v=ALGBuFLzDSA) — saved queries + completion; автор dbee [overview](https://www.youtube.com/watch?v=MDlYsGbKJyQ) — paging и call history; туториал [Ultimate Database Control](https://www.youtube.com/watch?v=NhTPVXP8n7w) повторяет dadbod+ui+completion+treesitter (у вас это уже есть).
- Пробел, который все три стека (dadbod issue, sqls.nvim maps, sqmeow README) называют отдельно: **выполнить statement под курсором**, не буфер и не visual.
- Для Postgres «приятный SQL» в 2026 = LSP на `libpg_query` с typecheck без EXECUTE: [supabase-community/postgres-language-server](https://github.com/supabase-community/postgres-language-server) (5.3k★), [type checking](https://pg-language-server.com/latest/features/type_checking/). nvim-lspconfig: `postgres_lsp`, `workspace_required = true`.

## Топ-10 (не из skip-листа)

| # | Что | Плагин / опция | URL | Мин | Зачем каждый день |
|---|-----|----------------|-----|-----|-------------------|
| 1 | Textoбъект SQL-statement + execute под курсором | `aq` из dadbod#33 + `db#op_exec()` / `<leader>S` на motion | https://github.com/tpope/vim-dadbod/issues/33 | 15 | Скрипт из нескольких CTE/SELECT — крутишь один statement, не выделяешь руками |
| 2 | Typecheck/hover Postgres без прогона | `postgres_lsp` (`postgres-language-server lsp-proxy`), mason `postgres-language-server`, `postgres-language-server.jsonc` из текущего `b:db` | https://github.com/supabase-community/postgres-language-server · https://pg-language-server.com/latest/guides/ide_setup/ · https://github.com/neovim/nvim-lspconfig/blob/master/lsp/postgres_lsp.lua | 45 | Опечатка колонки и неверный `::cast` красным до `:DB`; hover типа. Не заменяет dadbod-completion |
| 3 | EXPLAIN ANALYZE как helper + wrap keymap | `g:db_ui_table_helpers.postgresql.Explain` + `xnoremap` обернуть selection | https://github.com/kristijanhusak/vim-dadbod-ui#table-helpers (и `{last_query}` в doc) | 10 | GripExplain уже есть; helper даёт план с дерева таблиц за один клик, wrap — для ad-hoc `.sql` |
| 4 | Sticky header / табличный вид CSV-результата | `hat0uma/csvview.nvim` (`CsvViewEnable`, sticky headers) на `.csv` после `<leader>Dc` | https://github.com/hat0uma/csvview.nvim | 20 | Freeze header в dbee [ещё не сделан](https://github.com/kndndrj/nvim-dbee/issues/217); csvview даёт Excel-like шапку при горизонтальном скролле |
| 5 | Motion-execute + JOIN-по-FK (PG и MSSQL) | `sqls-server/sqls` + `nanotee/sqls.nvim` (`<Plug>(sqls-execute-query)` как operator) | https://github.com/sqls-server/sqls · https://github.com/nanotee/sqls.nvim | 40 | CodeAction Execute/Switch DB; JOIN completion по FK. Конфиг `connections` в yaml из `vim.g.dbs`. Не ставить вместе с postgres_lsp на одном буфере без `root_dir` split |
| 6 | Picker сохранённых запросов DBUI | `snacks.picker.files` / `grep` по `g:db_ui_save_location` (`stdpath("data")/db_ui`) | https://github.com/kristijanhusak/vim-dadbod-ui (Saved queries) · TJ https://www.youtube.com/watch?v=ALGBuFLzDSA | 20 | Saved queries — главный workflow TJ; сейчас это дерево DBUI, не fuzzy |
| 7 | Линт опасных миграций | `sbdchd/squawk` (CLI → nvim-lint custom или `null_ls`/diag) | https://github.com/sbdchd/squawk | 25 | sqlfluff уже форматтер; squawk ловит lock-heavy DDL (`ADD COLUMN` без default, `NOT NULL` без default) до прогона на проде |
| 8 | Сниппеты CTE / EXPLAIN / MERGE | `rafamadriz/friendly-snippets` `sql.json` в blink/native snippets + 3 своих (CTE, `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)`, `MERGE`) | https://github.com/rafamadriz/friendly-snippets | 15 | Набор `WITH … AS (` и EXPLAIN не надо печатать; blink уже есть |
| 9 | Bind-параметры в обычном `.sql` | DBUI `:contactId` + `<Plug>(DBUI_EditBindParameters)` (`<leader>E`) на ft=sql с `b:db`, не только dbui-буферы | https://github.com/kristijanhusak/vim-dadbod-ui/blob/master/doc/dadbod-ui.txt (Bind parameters) | 15 | Один и тот же SELECT с разными id без правки текста; значения в `b:` |
| 10 | Время запроса после execute | autocmd `User DBExecutePost` → `vim.notify` / virttext (dadbod doc: progress bar hooks) | https://github.com/kristijanhusak/vim-dadbod-ui/blob/master/README.md (`DBExecutePre`/`Post`) | 15 | psql `\timing` в toggleterm уже есть; для `:DB`/` <leader>S` длительность сейчас не видна |

## Почему не в списке

- **sqlit / sqmeow / sqlserver.nvim / nvim-db** — полноценные клиенты поверх уже трёх (dbee+DBUI+Grip+psql). Имеет смысл только если решите выкинуть один стек.
- **Freeze header в dbee** — [issue #217](https://github.com/kndndrj/nvim-dbee/issues/217) открыт; highlight groups результата — [#235](https://github.com/kndndrj/nvim-dbee/issues/235). Не конфиг, а патч апстрима.
- **sqlfluff через nvim-lint** — в проекте уже есть `nvim-lint.lua` и диалект из `b:db`; formatter sqlfluff в skip-листе.
- **GripHistory / GripExplain / visidata / xlsx / yank** — уже в `dadbod.lua`.

## Внедрение (коротко)

1. `aq` textobject из [issue 33](https://github.com/tpope/vim-dadbod/issues/33) + `nmap <leader>s vaq:DB<CR>` (не конфликтовать с `<leader>S` буфера).
2. `postgres_lsp`: `cmd = { "postgres-language-server", "lsp-proxy" }`, `root_markers = { "postgres-language-server.jsonc" }`. Для ad-hoc SQL — генерировать jsonc с DSN текущего `b:db` (пароль не писать, PGPASSFILE уже есть). Typecheck требует коннекта, statements на сервер не шлёт.
3. Helper: `Explain = "EXPLAIN (ANALYZE, BUFFERS) {last_query}"` осторожно: повтор helper'а удваивает EXPLAIN (документировано в dadbod-ui). Надёжнее wrap visual.
5. sqls и postgres_lsp не вешать оба на один sql-буфер: sqls — MSSQL-ноты / JOIN, postgres_lsp — `.sql` с `postgres-language-server.jsonc`.

## Источники (выборка)

- Reddit: [sqlit](https://www.reddit.com/r/neovim/comments/1qswj2z/sqlitnvim_a_lazygit_style_inspired_sql_neovim/), [sqmeow](https://www.reddit.com/r/neovim/comments/1wm9llk/sqmeownvim_rustpowered_db_client_for_neovim/), [«чем ходите в БД»](https://www.reddit.com/r/neovim/comments/1pr3h0i/what_are_you_using_to_manage_databases_from/), [sqlserver.nvim](https://www.reddit.com/r/neovim/comments/1wc7i72/sqlservernvim_a_sql_servernative_workspace_for/)
- GitHub: dadbod [#33](https://github.com/tpope/vim-dadbod/issues/33), dbee [#217](https://github.com/kndndrj/nvim-dbee/issues/217) [#235](https://github.com/kndndrj/nvim-dbee/issues/235), [postgres-language-server](https://github.com/supabase-community/postgres-language-server), [sqls](https://github.com/sqls-server/sqls), [sqls.nvim](https://github.com/nanotee/sqls.nvim), [csvview.nvim](https://github.com/hat0uma/csvview.nvim), [squawk](https://github.com/sbdchd/squawk), [nvim-lint sqlfluff](https://github.com/mfussenegger/nvim-lint/blob/master/lua/lint/linters/sqlfluff.lua)
- YouTube: [ALGBuFLzDSA](https://www.youtube.com/watch?v=ALGBuFLzDSA), [MDlYsGbKJyQ](https://www.youtube.com/watch?v=MDlYsGbKJyQ), [NhTPVXP8n7w](https://www.youtube.com/watch?v=NhTPVXP8n7w)
- Статьи: [Jamie Tanna sqls 2024](https://www.jvt.me/posts/2024/06/07/sql-workflow/), [ssp.sh dadbod](https://www.ssp.sh/brain/query-databases-in-vim-vim-dadbod/)

## Бэклог, волна 2 (herdr-route/grok, 2026-10-16)

| # | Что | Источник | Статус |
|---|-----|----------|--------|
| B1 | `g:db_ui_hide_schemas` — без pg_catalog/information_schema/sys | dadbod-ui doc `g:db_ui_hide_schemas` | сделано |
| B2 | Не выполнять на `:w`, auto_execute helpers | LazyVim extras/lang/sql | уже так (execute_on_save=0, auto_execute=0 намеренно) |
| B3 | FK-прыжок из dbout `<Plug>(DBUI_JumpToForeignKey)` | dadbod-ui ftplugin/dbout.vim | сделано |
| B4 | Имя базы в lualine, prod красным | dadbod-ui `db_ui#statusline()` | сделано |
| B5 | Helper'ы Size/Indexes для PG и MSSQL | dadbod-ui #table-helpers | сделано (Size) |
| B6 | Коннекты dbee из `vim.g.dbs` (MemorySource) | nvim-dbee README | уже было в dbee.lua: 1 source, 9 коннектов = 9 в vim.g.dbs |
| B7 | `loaded_sql_completion` — выключить Vim SQL-omni | LazyVim extras/lang/sql | сделано |
| B8 | `application_name=nvim` в DSN, ширина колонок sqlcmd | libpq docs, dadbod-ui #283 | PGAPPNAME=nvim сделано; ширину sqlcmd не трогал — шире 256 раздувает каждую nvarchar(max)-колонку |
