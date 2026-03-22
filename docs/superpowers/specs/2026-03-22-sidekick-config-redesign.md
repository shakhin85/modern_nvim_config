# Sidekick.nvim Config Redesign

## Problem

Current `lua/shako/plugins/sidekick.lua` has diverged from the official sidekick.nvim API, causing:
- Prompts sent empty (`{selection}` not resolved)
- NES not showing suggestions (wrong trigger events, wrong config structure)
- Telescope picker glitches (custom reimplementation instead of built-in)
- CLI window misbehavior (keymap conflicts)

## Approach

Full rewrite of the config to match official sidekick.nvim documentation (folke/sidekick.nvim), preserving all custom prompts but using the correct API.

## Changes

### 1. Remove `adaptive()` function

The custom `adaptive(prefix)` function concatenates `\n{selection}` or `\n{this}` based on `ctx.range`. This is unnecessary — sidekick's `{this}` context variable already resolves to `{position}` in normal mode and appends `{selection}` in visual mode.

**Delete:** lines 24-31.

### 2. Remove `prompt_telescope()` function

The 59-line custom Telescope picker reimplements sidekick's built-in `cli.prompt()`. With `picker = "telescope"` in config, the built-in picker uses Telescope natively.

**Delete:** lines 59-117.

### 3. Fix prompts format

Replace all `adaptive("prefix")` calls with plain strings using `{this}`:

| Old | New |
|-----|-----|
| `adaptive("Explain the following code in detail:")` | `"Explain {this}"` |
| `adaptive("Help debug this code:")` | `"Help debug {this}"` |
| `"Fix this issue:\n{diagnostics}\n\nCode context:\n{this}"` | `"Can you fix {this}?\n{diagnostics}"` |

All custom prompts (security, debug, edge_cases, mocks, commit, pr, dockerfile, ci, logging) are preserved with corrected format.

### 4. Fix NES config structure

| Option | Old (broken) | New (correct) |
|--------|-------------|---------------|
| `nes.trigger.events` | `{ "InsertLeave", ... }` | `{ "ModeChanged i:n", ... }` |
| `nes.clear.events` | `{ ..., "TextChanged", "BufWritePre", ... }` | `{ "TextChangedI", "InsertEnter" }` (extra events caused premature clearing) |
| signs | `signs = { enabled = true, icon = " " }` (top-level, wrong structure) | `nes.signs = true` (boolean inside nes) |
| jumplist | `jump = { jumplist = true }` (top-level, wrong structure) | `nes.jumplist = true` (boolean inside nes) |
| diff.show | missing | `"always"` (explicit default) |

### 5. Fix CLI config

- Add `cli.picker = "telescope"` to use built-in Telescope integration for prompt selection
- Remove `win_p` key (`<c-w>p` for blur conflicts with Vim's native `<c-w>p`; default `<c-z>` already provides blur)
- Simplify `mux.enabled` to `vim.env.ZELLIJ ~= nil`

### 6. Fix keymaps

**API verification** (from `lua/sidekick/init.lua` and `lua/sidekick/nes/init.lua`):
- Top-level module exports: `setup()`, `clear()`, `nes_jump_or_apply()` — nothing else
- NES module exports: `enable()`, `disable()`, `toggle()`, `update()`, `clear()`, `jump()`, `have()`, `apply()`
- There is NO `nes_prev()`, `nes_toggle()`, `nes_fetch()`, or `nes_clear()` on the top-level module

| Keymap | Old | New | Reason |
|--------|-----|-----|--------|
| `<tab>` | missing | `require("sidekick").nes_jump_or_apply()` with expr=true | From README — primary NES interaction |
| `<c-.>` | `focus()`, mode `{ "n", "v" }` | `focus()`, mode `{ "n", "t", "i", "x" }` | Expand modes per README |
| `<A-]>` | `require("sidekick").nes_jump_or_apply()` | same (already correct) | Keep as-is |
| `<A-[>` | `require("sidekick").nes_prev()` (non-existent) | **REMOVE** | No `prev()` API exists in sidekick |
| `<leader>an` | `require("sidekick").nes_toggle()` (non-existent) | `require("sidekick.nes").toggle()` | Correct module path |
| `<leader>af` | `require("sidekick").nes_fetch()` (non-existent) | `require("sidekick.cli").send({ msg = "{file}" })` | Align with README (Send File) |
| `<leader>au` | missing | `require("sidekick.nes").update()` | New mapping for NES fetch |
| `<leader>ax` | `require("sidekick").nes_clear()` (non-existent) | `require("sidekick.nes").clear()` | Correct module path |
| `<leader>ap` | two mappings (n, v) → custom Telescope | one mapping (n, x) → `cli.prompt()` | Use built-in picker |
| `<leader>at` | missing | `cli.send({ msg = "{this}" })` (n, x) | From README |
| `<leader>av` | missing | `cli.send({ msg = "{selection}" })` (x only) | From README |

**Keymaps unchanged:** `<leader>aa`, `<leader>ac`, `<leader>am`, `<leader>ag`, `<leader>ao`, `<leader>as`, `<leader>ad`, `<leader>ah`.

### 7. Result

- ~150 lines instead of 310
- All features work per official documentation
- All custom prompts preserved
- No custom code duplicating built-in functionality
- All keymaps call verified, existing API functions
