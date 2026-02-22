vim.g.mapleader = " "

local keymap = vim.keymap -- for conciseness

keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

keymap.set("n", "<leader>nhl", ":nohl<CR>", { desc = "Clear search highlights" })

-- increment/decrement numbers
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" }) -- increment
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" }) -- decrement

-- window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" }) -- split window vertically
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" }) -- split window horizontally
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" }) -- make split windows equal width & height
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" }) -- close current split window

keymap.set("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" }) -- open new tab
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" }) -- close current tab
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" }) --  go to next tab
keymap.set("n", "<leader>tP", "<cmd>tabp<CR>", { desc = "Go to previous tab" }) --  go to previous tab (changed from tp to avoid conflict)
keymap.set("n", "<leader>tF", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  move current buffer to new tab (changed from tf to avoid conflict)

-- Window navigation
keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
keymap.set("n", "<C-j>", "<C-w>j", { desc = "Move to window below" })
keymap.set("n", "<C-k>", "<C-w>k", { desc = "Move to window above" })
keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Window resizing
keymap.set("n", "<A-h>", "<C-w><", { desc = "Decrease window width" })
keymap.set("n", "<A-l>", "<C-w>>", { desc = "Increase window width" })
keymap.set("n", "<A-j>", "<C-w>-", { desc = "Decrease window height" })
keymap.set("n", "<A-k>", "<C-w>+", { desc = "Increase window height" })

-- Flash-enhanced window and buffer navigation (defined in flash.lua)
-- <leader>sw for window jump, <leader>sb for buffer jump

-- Buffer management
-- <leader>bd handled by snacks.bufdelete (smarter, no window close side-effects)
keymap.set("n", "<leader>ba", ":bufdo bd<CR>", { desc = "Delete all buffers" })
keymap.set("n", "<leader>bo", ":only<CR>", { desc = "Keep only current window" })
keymap.set("n", "<leader>bs", ":ls<CR>", { desc = "Show buffer list" })

-- Debug keymaps - removed to avoid conflicts with nvim-dap plugin
-- DAP plugin handles all F-key bindings for debugging

-- LazyGit: handled by snacks.lazygit (<leader>lg)

-- Bufferline navigation
keymap.set("n", "<Tab>", ":BufferLineCycleNext<CR>", { desc = "Next buffer" })
keymap.set("n", "<S-Tab>", ":BufferLineCyclePrev<CR>", { desc = "Previous buffer" })

-- Disable vim-visual-multi <C-n> in normal mode
keymap.set("n", "<C-n>", "<Nop>", { desc = "Disabled (vim-visual-multi conflict)" })

-- Keymaps navigation
keymap.set("n", "<leader>fk", "<cmd>Telescope keymaps<CR>", { desc = "Find keymaps" })

