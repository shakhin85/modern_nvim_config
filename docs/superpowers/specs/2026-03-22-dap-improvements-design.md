# DAP Improvements Design

## Problem

Current `lua/shako/plugins/dap.lua` has several issues:
- **pythonPath** uses `vim.g.python3_host_prog` (Neovim provider path) instead of project venv
- **Only 1 Python launch config** ("Launch file") — no pytest, no module debug
- **Missing keymaps** for hover, eval, logpoints, run-to-cursor
- **No exception breakpoints** — uncaught exceptions don't auto-stop

## Approach

Improve dap.lua to be project-aware and feature-complete, without adding new plugins. Use existing venv-selector VIRTUAL_ENV, dap.ui.widgets for inspect, and dap.defaults for exception breakpoints.

## Changes

### 1. Fix pythonPath — use project venv

Replace hardcoded `vim.g.python3_host_prog` with a shared function:
1. `VIRTUAL_ENV` (set by venv-selector)
2. `CONDA_PREFIX`
3. `.venv/bin/python` in cwd (fallback for projects without venv-selector)
4. `vim.fn.exepath("python3") or "python3"` (last resort, matches neotest pattern)

### 2. Add Python launch configurations

Add 3 configs alongside existing "Launch file":

| Name | What it does |
|------|-------------|
| Debug pytest (file) | `python -m pytest ${file} -v` — debug tests in current file |
| Debug pytest (all) | `python -m pytest -v` — debug entire test suite |
| Debug module (-m) | `python -m <input>` — debug any module by name |

All use shared `pythonPath` function. All include `justMyCode = false` (consistent with neotest-python config) and `console = "integratedTerminal"`.

Note: "Debug nearest test" is NOT included — neotest `<leader>Td` already does this better with cursor-aware test discovery.

### 3. Add missing keymaps

5 new keymaps under `<leader>d` prefix:

| Keymap | Action | Description |
|--------|--------|-------------|
| `<leader>dh` | `require("dap.ui.widgets").hover()` | Show value under cursor (popup), works in n+v mode |
| `<leader>de` | `vim.fn.input("Expr: ")` then `widgets.hover(expr)` | Evaluate arbitrary expression |
| `<leader>dp` | `dap.set_breakpoint(nil, nil, vim.fn.input("Log: "))` | Logpoint — logs message without stopping |
| `<leader>dc` | `dap.run_to_cursor()` | Execute until cursor line |
| `<leader>dx` | `dap.set_exception_breakpoints(filters)` | Cycle exception breakpoints: uncaught → all → none |

`<leader>dx` cycles through 3 states using a module-level variable:
- State 1: `{ "uncaught" }` — stop only on uncaught (default)
- State 2: `{ "uncaught", "raised" }` — stop on all exceptions
- State 3: `{}` — no exception breakpoints

No `<leader>df` for frames — dap-view "threads" section already shows the call stack.

Existing 9 keymaps unchanged (F5/F10/F11/F12, leader-db/dB/dr/dt/dl). Total: 14 keymaps in dap.lua (9 existing + 5 new, including `<leader>dx`).

### 4. Exception breakpoints — declarative defaults

Use idiomatic nvim-dap API instead of listeners:

```lua
dap.defaults.fallback.exception_breakpoints = { "uncaught" }
```

This applies to all adapters (Python, JS, Go) at session start. No listener management needed.

### 5. What stays unchanged

- JS/TS configuration (pwa-node adapter + launch/attach)
- Go configuration (delve adapter + debug/test)
- mason-nvim-dap (ensure_installed + handlers)
- nvim-dap-virtual-text (commented = true)
- dap-view.lua (auto_toggle handles open/close, sections correct)
- All existing keymaps and signs
- dap-view keymaps (dv, dw, dj) — no conflicts with new <leader>d* keymaps

### 6. Result

- dap.lua: ~145 lines (from 117)
- Project-aware Python debugging (venv auto-detection)
- 4 Python launch configs instead of 1
- 14 total keymaps instead of 9
- Exception breakpoints auto-enabled via dap.defaults
- No new plugins required
