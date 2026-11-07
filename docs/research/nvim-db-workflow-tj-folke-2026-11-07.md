# SQL/DB в Neovim: практика TJ DeVries и Folke (2026-11-07)

Метки: [V] проверено в конфиге/видео/исходнике; [I] вывод, не проверено.

## TJ DeVries

- [V] Использует vim-dadbod + vim-dadbod-completion + vim-dadbod-ui. Конфиг плагинов - 3 строки без опций:
  https://github.com/tjdevries/config.nvim/blob/master/lua/custom/plugins/dadbod.lua
- [V] nvim-dbee в его конфиге есть, но `enabled = false`. Комментарий в файле: "For now, I'm going to stick with dadbod, but if the completion continues to improve I will probably switch". Коммит 2024-05-11:
  https://github.com/tjdevries/config.nvim/blob/master/lua/custom/plugins/dbee.lua
  Причина отказа от dbee - автодополнение, не скорость.
- [V] Если включить dbee, он ставит filetype `sql.dbee` для заметок dbee и вешает на `BufWritePost` выполнение всего буфера (`dbee.execute(query)`), keymap `<space>od` открывает dbee:
  https://github.com/tjdevries/config.nvim/blob/master/lua/custom/dbee.lua
  https://github.com/tjdevries/config.nvim/blob/master/after/ftplugin/dbee.lua
- [V] Видео "Vim Dadbod - My Favorite SQL Plugin": https://www.youtube.com/watch?v=ALGBuFLzDSA
  - открывает `:DBUI` в отдельном tab;
  - пишет запрос в буфере, сохраняет файл - запрос сразу выполняется, результат в нижнем окне (dbout);
  - сохранённые запросы на каждую БД (reset-запросы, частые выборки);
  - completion: для ft `sql` источники `vim-dadbod-completion` + `buffer`; буфер нужен для литералов (логины и т.п.);
  - дополнение учитывает алиасы и таблицы из JOIN (`twitch_users.` -> только колонки этой таблицы);
  - БД: Postgres и SQLite.
- [V] Completion в его конфиге: `cmp.setup.filetype({"sql"}, { sources = { {name="vim-dadbod-completion"}, {name="buffer"} } })` (nvim-cmp, не blink):
  https://github.com/tjdevries/config.nvim/blob/master/lua/custom/completion.lua
- [V] Форматтер SQL, psql в терминале, LSP для SQL: в его config.nvim не найдено (поиск `sqlfluff` по его репозиториям - пусто).

## Folke / LazyVim

- [V] Личные dotfiles `folke/dot`: про БД ничего нет. Единственное упоминание - парсер `sql` в treesitter:
  https://github.com/folke/dot/blob/master/nvim/lua/plugins/treesitter.lua
  dadbod/dbee/sqlfluff в `folke/dot` не найдены (поиск по репозиторию).
- [V] Экстра LazyVim `lang.sql` (поддерживает сообщество LazyVim, не лично Folke):
  https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/plugins/extras/lang/sql.lua
  - плагины: `tpope/vim-dadbod` (`cmd = "DB"`), `vim-dadbod-ui` (`cmd = DBUI*`, key `<leader>D`), `vim-dadbod-completion` (`ft = {sql,mysql,plsql}`);
  - `vim.g.omni_sql_default_compl_type = "syntax"` и `vim.g.loaded_sql_completion = true` - отключает встроенный sql_completion ради совместимости с omni в blink;
  - blink: `sources.default = {"dadbod"}`, `providers.dadbod = { name="Dadbod", module="vim_dadbod_completion.blink" }`; без `async`, `timeout_ms`, `min_keyword_length`;
  - dadbod-ui: `db_ui_execute_on_save = false` с комментарием: автозапуск на save на большом запросе "can crash neovim", ручной запуск `<leader>S`; `db_ui_auto_execute_table_helpers = 1`;
  - edgy.nvim: DBUI справа (30%), `dbout` внизу;
  - lint: nvim-lint `sqlfluff`; format: conform `sqlfluff` с `args = { "format", "--dialect=ansi", "-" }`; mason ставит sqlfluff.
- [V] Родная интеграция dadbod-completion с blink: https://github.com/kristijanhusak/vim-dadbod-completion
  - README: плагин кэширует таблицы и колонки, сброс `:DBCompletionClearCache`;
  - исходник `lua/vim_dadbod_completion/blink.lua` вызывает `vim_dadbod_completion#omni` синхронно (vimscript), на каждый запрос дедуплицирует результат в Lua и возвращает пустую функцию отмены (async не реализован):
    https://github.com/kristijanhusak/vim-dadbod-completion/blob/master/lua/vim_dadbod_completion/blink.lua
- В LazyVim нет dbee и нет postgres_lsp для SQL (в этом файле).

## Форматирование и выравнивание SQL

| Инструмент | Выравнивание алиасов/колонок | Источник |
|---|---|---|
| sqlfluff | Да, настраиваемое: `spacing_before = align`, `align_within` (select_clause/statement), `align_scope` (bracketed/file), `alignment_coordinate_space`; работает для alias_expression, join_on_condition и др. | https://docs.sqlfluff.com/en/stable/configuration/layout.html |
| sql-formatter | Нет. Опции `tabulateAlias` и `commaPosition` удалены в v14 | https://github.com/sql-formatter-org/sql-formatter-vscode/blob/master/CHANGELOG.md ; https://github.com/sql-formatter-org/sql-formatter/blob/master/README.md |
| pgFormatter (`pg_format`) | Нет выравнивания; есть comma, comma-break, keyword/type/function-case, spaces, wrap-limit, wrap-after, format-type, placeholder, extra-function/keyword | https://github.com/darold/pgFormatter/blob/master/doc/pg_format.conf.sample |
| sleek | Нет; только indent-spaces, uppercase, lines-between-queries | https://github.com/nrempel/sleek |

- [V] Примеры конфигов sqlfluff:
  - выровнять алиасы в SELECT: `[sqlfluff:layout:type:alias_expression] spacing_before=align / align_within=select_clause / align_scope=bracketed` (док выше);
  - выровнять и алиасы таблиц в JOIN: `align_within = statement` (док выше);
  - выровнять `ON` в JOIN: `[sqlfluff:layout:type:join_on_condition] spacing_before=align, align_within=statement, align_scope=bracketed`; ограничение: дополнительные `AND` не выравниваются: https://stackoverflow.com/questions/78986544/align-the-table-aliases-in-the-join-clause-with-sqlfluff
- [V] Ограничения sqlfluff: выравнивание ломается с jinja-шаблонами (https://github.com/sqlfluff/sqlfluff/issues/5429); не использует табы для padding при `indent_unit = tab` (https://github.com/sqlfluff/sqlfluff/issues/6575).
- [V] conform.nvim: `sqlfluff` по умолчанию запускает `sqlfluff fix -` и требует `.sqlfluff`/pyproject в корне (`require_cwd = true`): https://github.com/stevearc/conform.nvim/blob/master/lua/conform/formatters/sqlfluff.lua
- Вывод: для PostgreSQL самая настраиваемая раскладка - sqlfluff, `--dialect=postgres` (LazyVim по умолчанию ставит `ansi`, это [V] из sql.lua). [I] sqlfluff - Python-процесс на каждый save, форматирование заметно медленнее pg_format; замер не делал.

## dbee и blink: производительность

- [V] nvim-dbee issue #116 (open): "[Performance] Disable automatic database drawer refresh" - drawer постоянно перерисовывается на лишних триггерах, заметно на удалённых БД. Автор нашёл причину: автокоманда `BufModifiedSet` в `modified_suffix` (`lua/dbee/ui/drawer/convert.lua`) вызывает refresh:
  https://github.com/kndndrj/nvim-dbee/issues/116
  Код в `main` с этой автокомандой присутствует: https://github.com/kndndrj/nvim-dbee/blob/main/lua/dbee/ui/drawer/convert.lua
  [I] На больших схемах/удалённом Postgres это даёт лаги при каждом изменении заметки.
- [V] Автор dbee в видео: результаты отдаются через итератор постранично, большой результат начинает отображаться сразу, дочитывается дальше; запрос можно отменить из call history: https://www.youtube.com/watch?v=MDlYsGbKJyQ
  [I] Лаг на огромных SELECT снимается `LIMIT`/страницами, а не настройкой.
- [V] Опции провайдера blink (`timeout_ms` default 2000, `async` default false, `min_keyword_length` default 0, `max_items`, `fallbacks`, `score_offset`, `transform_items`). Явных performance-рекомендаций в доке нет: https://cmp.saghen.dev/configuration/sources
  [I] Так как dadbod-источник синхронный, `async = true` и `min_keyword_length = 2` на провайдере не ускоряют сам вызов, но не блокируют показ остальных источников.
- [V] blink issue #2229 (closed): fuzzy-поиск с dadbod-источником отличается от nvim-cmp; maintainer ответил "report to vim-dadbod repo": https://github.com/saghen/blink.cmp/issues/2229
- Не найдено: официальные issues про лаг blink именно на SQL; документ с настройкой dbee на скорость.

## Что взять нам

1. Не запускать запрос на каждый save/modify автоматически; ручной запуск (LazyVim: `db_ui_execute_on_save=false`, "can crash neovim"). У TJ автозапуск на save - только на маленьких локальных БД. Проверь, нет ли у нас BufWritePost-автозапуска в dbee/dadbod.
2. Обход лага dbee #116: отключить/ограничить refresh drawer на `BufModifiedSet` (патч локально или окно drawer закрыто при наборе); закрывать drawer на время редактирования заметки.
3. Для blink-провайдера dadbod: `async = true`, `min_keyword_length = 2`, `max_items = 50`, `score_offset` ниже LSP - проверить замером (:BlinkCmp profile / ощущение), не вслепую. Источник синхронный, поэтому не вешать на него `timeout_ms` больше 200-300.
4. Источники SQL ограничить: `dadbod` + `buffer` (как у TJ) на ft sql; postgres_lsp и snippets/path не добавлять в sql-ветку, если лагает - отключать по одному.
5. Выравнивание: sqlfluff через conform, `--dialect=postgres`, `.sqlfluff` с `spacing_before = align` для `alias_expression` и `join_on_condition` (`align_within=select_clause|statement`, `align_scope=bracketed`). Это единственный форматтер с настраиваемым выравниванием.
6. Форматировать по команде (keymap/`gq`), не на save: sqlfluff медленный на каждый вызов [I]. Для быстрого прохода без выравнивания - `pg_format` (`keyword-case`, `comma`, `wrap-limit`).
7. `:DBCompletionClearCache` как команда/keymap после DDL; кэш dadbod-completion иначе устаревает.
8. Копировать идею TJ: сохранённые запросы на каждую БД (dadbod-ui save location) и reset-запросы под рукой; открывать DB-UI в отдельном tab, не в split.

## Не найдено

Видео/конфигов TJ про форматирование SQL и psql; у Folke лично - ничего про БД кроме парсера treesitter; официальных perf-рекомендаций для dbee и blink+SQL.
