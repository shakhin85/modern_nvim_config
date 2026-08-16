return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "saghen/blink.cmp",
    { "antosha417/nvim-lsp-file-operations", config = true },
    { "folke/neodev.nvim", opts = {} },
    "b0o/schemastore.nvim",
  },
  config = function()
    -- import mason_lspconfig plugin
    local mason_lspconfig = require("mason-lspconfig")

    local keymap = vim.keymap -- for conciseness

    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("UserLspConfig", {}),
      callback = function(ev)
        -- Buffer local mappings.
        -- See `:help vim.lsp.*` for documentation on any of the below functions
        local opts = { buffer = ev.buf, silent = true }

        -- set keybinds
        -- Один путь на действие: снимаем дефолты 0.11 (grr/gri/grn/gra)
        for _, lhs in ipairs({ "grr", "gri", "grn", "gra" }) do
          pcall(vim.keymap.del, "n", lhs)
        end
        local tb = require("telescope.builtin")

        opts.desc = "Go to definition (jump on single result)"
        keymap.set("n", "gd", function() tb.lsp_definitions({ reuse_win = true }) end, opts)

        opts.desc = "Go to declaration"
        keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

        opts.desc = "Find usages / references (picker)"
        keymap.set("n", "gr", function() tb.lsp_references({ include_declaration = false }) end, opts)

        opts.desc = "Go to implementation"
        keymap.set("n", "gI", tb.lsp_implementations, opts)

        opts.desc = "Go to type definition"
        keymap.set("n", "gy", tb.lsp_type_definitions, opts)

        opts.desc = "Document symbols"
        keymap.set("n", "gO", tb.lsp_document_symbols, opts)

        opts.desc = "Workspace symbols"
        keymap.set("n", "<leader>ws", tb.lsp_dynamic_workspace_symbols, opts)

        opts.desc = "Toggle inlay hints"
        keymap.set("n", "<leader>uh", function()
          vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
        end, opts)

        opts.desc = "See available code actions"
        keymap.set({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, opts) -- see available code actions, in visual mode will apply to selection

        opts.desc = "Smart rename"
        keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts) -- smart rename

        opts.desc = "Show buffer diagnostics"
        keymap.set("n", "<leader>xd", "<cmd>Telescope diagnostics bufnr=0<CR>", opts) -- <leader>D зарезервирован под Database

        opts.desc = "Show line diagnostics"
        keymap.set("n", "gl", vim.diagnostic.open_float, opts) -- show diagnostics for line

        opts.desc = "Go to previous diagnostic"
        keymap.set("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, opts) -- jump to previous diagnostic in buffer

        opts.desc = "Go to next diagnostic"
        keymap.set("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, opts) -- jump to next diagnostic in buffer

        opts.desc = "Show documentation for what is under cursor"
        keymap.set("n", "K", vim.lsp.buf.hover, opts) -- show documentation for what is under cursor

        opts.desc = "Restart LSP"
        keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts) -- mapping to restart lsp if necessary
      end,
    })

    -- used to enable autocompletion (assign to every lsp server config)
    local capabilities = require("blink.cmp").get_lsp_capabilities()

    -- Change the Diagnostic symbols in the sign column (gutter)
    vim.diagnostic.config({
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = " ",
          [vim.diagnostic.severity.WARN] = " ",
          [vim.diagnostic.severity.HINT] = "󰠠 ",
          [vim.diagnostic.severity.INFO] = " ",
        },
      },
    })

    local servers = {
      "ts_ls",
      "html",
      "cssls",
      "tailwindcss",
      "svelte",
      "lua_ls",
      "emmet_ls",
      "basedpyright",
      "powershell_es",
      "graphql",
      "sqls",
      "marksman",
      "jsonls",
      "eslint",
      "yamlls",
      "dockerls",
      "docker_compose_language_service",
      "helm_ls",
      "gopls",
      "taplo",
    }

    for _, server in ipairs(servers) do
      local opts = {
        capabilities = capabilities,
      }

      -- Specific configurations
      if server == "graphql" then
        opts.filetypes = { "graphql", "gql", "svelte", "typescriptreact", "javascriptreact" }
      end

      if server == "sqls" then
        opts.filetypes = { "sql", "mysql", "plsql", "sqlite" }
      end

      if server == "eslint" then
        opts.filetypes = {
          "javascript",
          "javascriptreact",
          "javascript.jsx",
          "typescript",
          "typescriptreact",
          "typescript.tsx",
          "svelte",
        }
        opts.settings = {
          workingDirectory = { mode = "auto" },
        }
      end

      if server == "yamlls" then
        opts.settings = {
          yaml = {
            schemaStore = { enable = false, url = "" },
            schemas = require("schemastore").yaml.schemas(),
            validate = true,
            completion = true,
          },
        }
      end

      if server == "jsonls" then
        opts.settings = {
          json = {
            schemas = require("schemastore").json.schemas(),
            validate = { enable = true },
          },
        }
      end

      if server == "emmet_ls" then
        opts.filetypes = {
          "html",
          "typescriptreact",
          "javascriptreact",
          "css",
          "sass",
          "scss",
          "less",
          "svelte",
        }
      end

      if server == "lua_ls" then
        opts.settings = {
          Lua = {
            diagnostics = {
              globals = { "vim" },
            },
            completion = {
              callSnippet = "Replace",
            },
          },
        }
      end

      if server == "svelte" then
        opts.on_attach = function(client, bufnr)
          vim.api.nvim_create_autocmd("BufWritePost", {
            pattern = { "*.js", "*.ts" },
            callback = function(ctx)
              client.notify("$/onDidChangeTsOrJsFile", { uri = ctx.match })
            end,
          })
        end
      end

      if server == "basedpyright" then
        opts.settings = {
          basedpyright = {
            analysis = {
              typeCheckingMode = "standard",
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              diagnosticMode = "openFilesOnly",
            },
          },
        }
      end

      -- The new Neovim 0.11+ API way:
      -- Configure the server
      vim.lsp.config(server, opts)
      -- Enable the server
      vim.lsp.enable(server)
    end
  end,
}