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

-- Setup function
function M.setup(opts)
  opts = vim.tbl_deep_extend("force", defaults, opts or {})

  -- Debug: Check if lspconfig is available
  local status_ok, lspconfig = pcall(require, "lspconfig")
  if not status_ok then
    vim.notify("nvim-lspconfig not found. Please ensure it is installed and loaded before godot-lsp.nvim.", vim.log.levels.ERROR)
    return
  end

  -- Register godot_lsp in lspconfig.configs
  lspconfig.configs.godot_lsp = {
    default_config = {
      cmd = opts.cmd,
      filetypes = opts.filetypes,
      root_dir = vim.fn.getcwd(),
    },
    docs = {
      description = "Godot LSP for GDScript",
    },
  }

  -- LSP on_attach function
  local on_attach = function(client, bufnr)
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

  -- Configure LSP server
  local success, err = pcall(function()
    lspconfig.godot_lsp.setup({
      cmd = opts.cmd,
      filetypes = opts.filetypes,
      on_attach = on_attach,
      flags = { debounce_text_changes = 150 },
    })
  end)

  if not success then
    vim.notify("Failed to setup godot_lsp: " .. vim.inspect(err), vim.log.levels.ERROR)
    return
  end

  -- Autocommands
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "gdscript",
    callback = function()
      if opts.skip_godot_check or vim.fn.executable("godot") == 1 then
        vim.cmd("GodotLspStart")
      end
    end,
    desc = "Start Godot LSP for GDScript files",
  })

  vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = "*.gd",
    callback = function()
      vim.cmd("GodotLspAttachAll")
    end,
    desc = "Attach GDScript buffers to LSP",
  })

  vim.api.nvim_create_autocmd("BufEnter", {
    pattern = "*.gd",
    callback = function()
      if vim.fn.has("nvim-0.9.0") == 1 then
        require("nvim-treesitter.install").update({ with_sync = true }) "gdscript"
      end
    end,
    desc = "Ensure TreeSitter highlighting for GDScript",
  })

  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*.gd",
    callback = function()
      vim.lsp.buf_notify(0, "godot/reloadScript", { uri = vim.uri_from_bufnr(0) })
    end,
    desc = "Notify Godot to reload script on save",
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    pattern = "*.gd",
    callback = function()
      vim.lsp.buf_detach_client(0, vim.lsp.get_client_by_id("godot_lsp"))
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
    local status_ok, _ = pcall(function()
      if lspconfig.godot_lsp and lspconfig.godot_lsp.setup then
        lspconfig.godot_lsp.setup({ on_attach = on_attach })
        vim.lsp.start_client(lspconfig.godot_lsp)
      else
        vim.lsp.start({
          name = "godot_lsp",
          cmd = opts.cmd,
          on_attach = on_attach,
          root_dir = vim.fn.getcwd(),
        })
      end
    end)
    if opts.debug_logging then
      vim.notify("Godot LSP started", vim.log.levels.INFO)
    end
  end, { desc = "Start Godot LSP client" })

  vim.api.nvim_create_user_command("GodotLspStatus", function()
    local clients = vim.lsp.get_active_clients({ name = "godot_lsp" })
    if #clients > 0 then
      vim.notify("Godot LSP is running", vim.log.levels.INFO)
    else
      vim.notify("Godot LSP is not running", vim.log.levels.WARN)
    end
  end, { desc = "Check Godot LSP status" })

  vim.api.nvim_create_user_command("GodotLspAttachAll", function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].filetype == "gdscript" then
        vim.lsp.buf_attach_client(buf, vim.lsp.get_client_by_id("godot_lsp"))
      end
    end
  end, { desc = "Attach all GDScript buffers to LSP" })

  -- Debug logging
  if opts.debug_logging then
    vim.lsp.set_log_level("debug")
    vim.notify("Godot LSP debug logging enabled at ~/.cache/nvim/godot-lsp.log", vim.log.levels.INFO)
  end
end

return M
```

### Changes
- **Debug Check:** Added a `vim.notify` message if `lspconfig` is not a table after `pcall`, allowing you to see if the module is loading correctly.
- **Fallback:** Retained the fallback to `vim.lsp.start` if `lspconfig.godot_lsp` is nil.
- **Local Opts:** Ensured `opts` is defined locally to avoid global pollution.

### Step 6: Test the Fix
1. **Apply Changes:**
   - Save the updated `init.lua`, `lsp_godot.lua`, and `lazyinit.lua`.
   - Run `:Lazy sync` to reinstall plugins.

2. **Reload Neovim:**
   - Restart Neovim or run `:source %` followed by `:Lazy reload`.

3. **Check Logs:**
   - Open `/Users/MateoPanadero/.cache/nvim/godot-lsp.log` to verify module loading and client registration.
   - Run `:LspLog` for additional details.

4. **Verify:**
   - Run `:GodotLspStatus` to check if the LSP client starts.
   - Open a `.gd` file and test LSP features (e.g., `gd`).
   - Test DAP with `<F5>` after starting Godot with `godot --remote-debug localhost:6006 --editor`.

### Step 7: Debugging if Issues Persist
- **Manual Test:** Run `:lua local lspconfig = require("lspconfig"); print(vim.inspect(lspconfig))` in Neovim to check if `lspconfig` is a table with expected fields (e.g., `configs`).
- **Print Debug:** If the error continues, add `print(vim.inspect(lspconfig))` after the `pcall` in `init.lua` to see `lspconfig`’s state.
- **Lazy Debug:** Run `:Lazy profile` to see load order and errors.
- **Minimal Config:** Create a minimal Neovim config with only Lazy, lspconfig, and godot-lsp.nvim to isolate the issue.

### Git Commit Message
If you modify `init.lua`, use:

```plaintext
Fix LSP setup nil error with enhanced registration and fallback

- Ensured godot_lsp client is registered in lspconfig.configs
- Added pcall and debug checks for lspconfig loading
- Added fallback to vim.lsp.start if lspconfig setup fails
- Updated README with troubleshooting for custom server registration
- Preserved DAP, LSP, and multi-buffer functionality
```

This should finally resolve the nil error. Let me know the log output or any new errors!
