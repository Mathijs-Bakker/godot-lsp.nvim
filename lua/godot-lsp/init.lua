local M = {}

-- Default configuration
local defaults = {
  cmd = { "ncat", "localhost", "6005" },
  filetypes = { "gdscript" },
  skip_godot_check = true,
  debug_logging = false,
  keymaps = {
    definition = "gd",
    declaration = "gD",
    type_definition = "gt",
    hover = "K",
    code_action = "<leader>ca",
    completion = "<C-x><C-o>",
    diagnostic_open_float = "<leader>cd",
    diagnostic_goto_next = "]d",
    diagnostic_goto_prev = "[d",
    references = "<leader>cr",
    rename = "<leader>rn",
    workspace_symbols = "<leader>ws",
    format = "<leader>f",
    -- DAP keymaps (optional)
    dap_continue = "<F5>",
    dap_toggle_breakpoint = "<F9>",
    dap_step_over = "<F10>",
    dap_step_into = "<F11>",
    dap_step_out = "<F12>",
    dap_ui = "<leader>du",
  },
  dap = false, -- Enable DAP support (experimental)
}

-- Global client ID to track godot_lsp
local godot_lsp_client_id = nil

-- Setup function
function M.setup(opts)
  opts = vim.tbl_deep_extend("force", defaults, opts or {})

  -- Debug: Check if lspconfig is available
  local status_ok, lspconfig = pcall(require, "lspconfig")
  if not status_ok then
    vim.notify("nvim-lspconfig not found. Please ensure it is installed and loaded.", vim.log.levels.ERROR)
    return
  end

  -- Register godot_lsp in lspconfig.configs globally (once)
  if not lspconfig.configs.godot_lsp then
    lspconfig.configs.godot_lsp = {
      default_config = {
        cmd = opts.cmd,
        filetypes = opts.filetypes,
        root_dir = function(fname)
          return vim.fs.dirname(vim.fs.find({ "project.godot" }, { upward = true })[1]) or vim.fn.getcwd()
        end,
      },
      docs = {
        description = "Godot LSP for GDScript",
        default_config = {
          root_dir = [[vim.fs.dirname(vim.fs.find({'project.godot'}, { upward = true })[1])]],
        },
      },
      on_new_config = function(new_config, new_root_dir)
        new_config.cmd = opts.cmd
      end,
    }
    vim.notify("Registered godot_lsp client with lspconfig", vim.log.levels.INFO)
  else
    vim.notify("godot_lsp config already registered, reusing", vim.log.levels.INFO)
  end

  -- LSP on_attach function
  local on_attach = function(client, bufnr)
    godot_lsp_client_id = client.id
    vim.notify("Attached godot_lsp client (id: " .. godot_lsp_client_id .. ") to buffer " .. bufnr, vim.log.levels.INFO)
    -- Disable unsupported capabilities for Godot LSP
    client.server_capabilities.document_formatting = false
    client.server_capabilities.document_range_formatting = false
    client.server_capabilities.workspace = {
      configuration = false,
    }
    local function map(mode, lhs, rhs, desc)
      if lhs then
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
      end
    end

    -- LSP Keymaps
    map("n", opts.keymaps.definition, vim.lsp.buf.definition, "Go to definition")
    map("n", opts.keymaps.declaration, vim.lsp.buf.declaration, "Go to declaration")
    map("n", opts.keymaps.type_definition, vim.lsp.buf.type_definition, "Go to type definition")
    map("n", opts.keymaps.hover, vim.lsp.buf.hover, "Show hover documentation")
    map("n", opts.keymaps.code_action, vim.lsp.buf.code_action, "Code actions")
    map("i", opts.keymaps.completion, vim.lsp.buf.completion, "Trigger completion")
    map("n", opts.keymaps.diagnostic_open_float, vim.diagnostic.open_float, "Show diagnostics")
    map("n", opts.keymaps.diagnostic_goto_next, vim.diagnostic.goto_next, "Next diagnostic")
    map("n", opts.keymaps.diagnostic_goto_prev, vim.diagnostic.goto_prev, "Previous diagnostic")
    map("n", opts.keymaps.references, ":Telescope lsp_references<CR>", "Show references")
    map("n", opts.keymaps.rename, vim.lsp.buf.rename, "Rename symbol")
    map("n", opts.keymaps.workspace_symbols, ":Telescope lsp_workspace_symbols<CR>", "Workspace symbols")
    map("n", opts.keymaps.format, vim.lsp.buf.format, "Format buffer")

    -- DAP Keymaps (if enabled)
    if opts.dap then
      map("n", opts.keymaps.dap_continue, require("dap").continue, "Continue debugging")
      map("n", opts.keymaps.dap_toggle_breakpoint, require("dap").toggle_breakpoint, "Toggle breakpoint")
      map("n", opts.keymaps.dap_step_over, require("dap").step_over, "Step over")
      map("n", opts.keymaps.dap_step_into, require("dap").step_into, "Step into")
      map("n", opts.keymaps.dap_step_out, require("dap").step_out, "Step out")
      map("n", opts.keymaps.dap_ui, require("dapui").toggle, "Toggle DAP UI")
    end

    -- Optional: Highlight current symbol
    if client.server_capabilities.documentHighlightProvider then
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        buffer = bufnr,
        callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd("CursorMoved", {
        buffer = bufnr,
        callback = vim.lsp.buf.clear_references,
      })
    end
  end

  -- Configure LSP server only if not already started
  if not godot_lsp_client_id then
    local success, err = pcall(function()
      lspconfig.godot_lsp.setup {
        cmd = opts.cmd,
        filetypes = opts.filetypes,
        on_attach = on_attach,
        flags = { debounce_text_changes = 150 },
        handlers = {
          ["workspace/didChangeConfiguration"] = function(err, result, ctx, config)
            if err then
              vim.notify("LSP workspace config error: " .. vim.inspect(err), vim.log.levels.ERROR)
            end
          end,
        },
      }
      local clients = vim.lsp.get_clients { name = "godot_lsp" }
      if #clients > 0 then
        godot_lsp_client_id = clients[1].id
        vim.notify("Started godot_lsp client (id: " .. godot_lsp_client_id .. ")", vim.log.levels.INFO)
      else
        vim.notify("Failed to start godot_lsp client, attempting manual start", vim.log.levels.WARN)
        local client = vim.lsp.start {
          name = "godot_lsp",
          cmd = opts.cmd,
          on_attach = on_attach,
          root_dir = vim.fs.dirname(vim.fs.find({ "project.godot" }, { upward = true })[1]) or vim.fn.getcwd(),
        }
        if client then
          godot_lsp_client_id = client.id
          vim.notify("Manually started godot_lsp client (id: " .. godot_lsp_client_id .. ")", vim.log.levels.INFO)
        end
      end
    end)
    if not success then
      vim.notify("Failed to setup godot_lsp: " .. vim.inspect(err), vim.log.levels.ERROR)
      return
    end
  end

  -- Ensure logging directory exists
  local log_dir = vim.fn.stdpath "cache" .. "/nvim/godot-lsp.log"
  vim.fn.mkdir(vim.fn.fnamemodify(log_dir, ":h"), "p")
  if opts.debug_logging then
    vim.lsp.set_log_level "debug"
    vim.notify("Godot LSP debug logging enabled at " .. log_dir, vim.log.levels.INFO)
  end

  -- Autocommands
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "gdscript",
    callback = function()
      vim.notify("FileType gdscript detected, attaching Godot LSP", vim.log.levels.INFO)
      if godot_lsp_client_id then
        vim.lsp.buf_attach_client(0, godot_lsp_client_id)
        vim.notify("Attached buffer to godot_lsp client (id: " .. godot_lsp_client_id .. ")", vim.log.levels.INFO)
      else
        vim.cmd "GodotLspStart"
      end
    end,
    desc = "Start Godot LSP for GDScript files",
  })

  vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = "*.gd",
    callback = function()
      vim.notify("BufReadPost *.gd, attaching Godot LSP", vim.log.levels.INFO)
      if godot_lsp_client_id then
        vim.lsp.buf_attach_client(0, godot_lsp_client_id)
        vim.notify("Attached buffer to godot_lsp client (id: " .. godot_lsp_client_id .. ")", vim.log.levels.INFO)
      else
        vim.cmd "GodotLspAttachAll"
      end
    end,
    desc = "Attach GDScript buffers to LSP",
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.gd",
    callback = function()
      if vim.fn.has "nvim-0.9.0" == 1 then
        require("nvim-treesitter.install").update { with_sync = true } "gdscript"
      end
    end,
    desc = "Ensure TreeSitter highlighting for GDScript",
  })

  -- godot/reloadScript not supported by Godot
  -- vim.api.nvim_create_autocmd("BufWritePost", {
  --   pattern = "*.gd",
  --   callback = function()
  --     vim.lsp.buf_notify(0, "godot/reloadScript", { uri = vim.uri_from_bufnr(0) })
  --   end,
  --   desc = "Notify Godot to reload script on save",
  -- })

  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*.gd",
    callback = function()
      local file = vim.fn.expand "%:p"
      -- Check if Godot is running (basic check via system call)
      local godot_running = vim.fn.system "pgrep -f 'godot.*--editor'" ~= ""
      if godot_running then
        vim.fn.system { vim.fn.expand "~/.local/bin/open-nvim-godot.sh", file, "1", "1", "reload" }
      else
        vim.notify("Godot editor not running. Please start Godot with --editor --lsp --verbose.", vim.log.levels.WARN)
      end
    end,
    desc = "Reload script in Godot on save via launch script",
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    pattern = "*.gd",
    callback = function()
      if godot_lsp_client_id then
        vim.lsp.buf_detach_client(0, godot_lsp_client_id)
      end
    end,
    desc = "Detach GDScript buffer from LSP on close",
  })

  -- DAP Setup (if enabled)
  if opts.dap then
    local dap_status_ok, dap = pcall(require, "dap")
    if not dap_status_ok then
      vim.notify("nvim-dap not found. Install it to use DAP features.", vim.log.levels.WARN)
      return
    end

    local dapui_status_ok, dapui = pcall(require, "dapui")
    if not dapui_status_ok then
      vim.notify("nvim-dap-ui not found. Install it for a better DAP UI.", vim.log.levels.WARN)
    else
      dapui.setup()
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end

    -- Godot DAP Adapter (Experimental)
    dap.adapters.godot = {
      type = "server",
      host = "localhost",
      port = 6006, -- Default Godot debug port (adjust if needed)
      executable = {
        command = "godot",
        args = { "--remote-debug", "localhost:6006", "--editor" },
      },
    }

    -- Godot Debug Configuration
    dap.configurations.gdscript = {
      {
        type = "godot",
        request = "launch",
        name = "Launch Godot Debug",
        program = vim.fn.getcwd() .. "/project.godot", -- Adjust path to your Godot project
        stopOnEntry = true,
      },
    }

    vim.notify("Godot DAP initialized (experimental). Run :DapContinue to start debugging.", vim.log.levels.INFO)
  end

  -- Commands
  vim.api.nvim_create_user_command("GodotLspStart", function()
    local success, err = pcall(function()
      if not godot_lsp_client_id then
        lspconfig.godot_lsp.setup {
          cmd = opts.cmd,
          filetypes = opts.filetypes,
          on_attach = on_attach,
          flags = { debounce_text_changes = 150 },
        }
        local clients = vim.lsp.get_clients { name = "godot_lsp" }
        if #clients > 0 then
          godot_lsp_client_id = clients[1].id
          vim.notify("Started godot_lsp client (id: " .. godot_lsp_client_id .. ")", vim.log.levels.INFO)
        else
          local client = vim.lsp.start {
            name = "godot_lsp",
            cmd = opts.cmd,
            on_attach = on_attach,
            root_dir = vim.fs.dirname(vim.fs.find({ "project.godot" }, { upward = true })[1]) or vim.fn.getcwd(),
          }
          if client then
            godot_lsp_client_id = client.id
            vim.notify("Manually started godot_lsp client (id: " .. godot_lsp_client_id .. ")", vim.log.levels.INFO)
          end
        end
      end
    end)
    if not success then
      vim.notify("Failed to start godot_lsp: " .. vim.inspect(err), vim.log.levels.ERROR)
    end
    if opts.debug_logging then
      vim.notify("Godot LSP started", vim.log.levels.INFO)
    end
  end, { desc = "Start Godot LSP client" })

  vim.api.nvim_create_user_command("GodotLspStatus", function()
    local clients = vim.lsp.get_clients { name = "godot_lsp" }
    if #clients > 0 then
      vim.notify("Godot LSP is running (id: " .. clients[1].id .. ")", vim.log.levels.INFO)
    else
      vim.notify("Godot LSP is not running", vim.log.levels.WARN)
    end
  end, { desc = "Check Godot LSP status" })

  vim.api.nvim_create_user_command("GodotLspAttachAll", function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].filetype == "gdscript" then
        if godot_lsp_client_id then
          vim.lsp.buf_attach_client(buf, godot_lsp_client_id)
          vim.notify(
            "Attached buffer " .. buf .. " to godot_lsp client (id: " .. godot_lsp_client_id .. ")",
            vim.log.levels.INFO
          )
        end
      end
    end
  end, { desc = "Attach all GDScript buffers to LSP" })
end

return M
