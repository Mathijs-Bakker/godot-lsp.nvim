local ok, lspconfig = pcall(require, "lspconfig")
if not ok then
  print "Error: nvim-lspconfig is not installed or failed to load. Please install it to use godot-lsp.nvim."
  return
end
local util = require "lspconfig.util"

-- Default configuration for Godot LSP
local default_config = {
  cmd = { "ncat", "localhost", "6005" }, -- Connect to Godot's LSP port
  filetypes = { "gdscript" },
  root_dir = function(fname)
    local root = util.root_pattern "project.godot"(fname)
    if root then
      return root
    end
    return util.path.dirname(fname)
  end,
  settings = {},
  skip_godot_check = true, -- Skip pgrep check since manual ncat works
  capabilities = {
    textDocument = {
      completion = { completionItem = { snippetSupport = true } },
      definition = { linkSupport = true },
      hover = { contentFormat = { "markdown", "plaintext" } },
      publishDiagnostics = { relatedInformation = true },
    },
  },
  debug_logging = false, -- Enable to log debug messages to ~/.cache/nvim/godot-lsp.log
}

-- Store client ID to reuse across buffers
local godot_lsp_client_id = nil

-- Logging function
local function log_message(msg, config)
  if config.debug_logging then
    local log_file = vim.fn.stdpath "cache" .. "/godot-lsp.log"
    local file = io.open(log_file, "a")
    if file then
      file:write(os.date "[%Y-%m-%d %H:%M:%S] " .. msg .. "\n")
      file:close()
    end
  end
end

-- Test ncat connection
local function test_ncat_connection(host, port, config)
  local cmd = string.format("ncat %s %s --send-only < /dev/null 2>&1", host, port)
  local handle = io.popen(cmd)
  local result = handle:read "*a"
  handle:close()
  local success = result == ""
  log_message("ncat test result: " .. (success and "success" or "failed: " .. result), config)
  return success
end

-- Attach buffer to LSP client
local function attach_buffer_to_client(bufnr, client_id, config)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    log_message("Buffer " .. bufnr .. " is invalid", config)
    return
  end
  if vim.bo[bufnr].filetype ~= "gdscript" then
    log_message(
      "Buffer "
        .. bufnr
        .. " ("
        .. vim.api.nvim_buf_get_name(bufnr)
        .. ") is not a GDScript file, filetype: "
        .. vim.bo[bufnr].filetype,
      config
    )
    return
  end
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    log_message("Buffer " .. bufnr .. " (" .. vim.api.nvim_buf_get_name(bufnr) .. ") is not loaded", config)
    return
  end
  local success, err = pcall(vim.lsp.buf_attach_client, bufnr, client_id)
  if success then
    log_message(
      "Attached buffer "
        .. bufnr
        .. " ("
        .. vim.api.nvim_buf_get_name(bufnr)
        .. ") to Godot LSP client ID "
        .. client_id,
      config
    )
  else
    log_message(
      "Failed to attach buffer "
        .. bufnr
        .. " ("
        .. vim.api.nvim_buf_get_name(bufnr)
        .. ") to Godot LSP client ID "
        .. client_id
        .. ": "
        .. vim.inspect(err),
      config
    )
  end
end

-- Start or attach to the LSP client
local function setup_godot_lsp(user_config)
  local config = vim.tbl_deep_extend("force", default_config, user_config or {})
  local lsp_name = "godot_lsp"

  -- Test ncat connection
  local host, port = config.cmd[2], config.cmd[3]
  if not test_ncat_connection(host, port, config) then
    print(
      string.format(
        "Failed to connect to Godot LSP server at %s:%s using ncat. Ensure ncat is installed and Godot is running.",
        host,
        port
      )
    )
    return
  end

  -- Check if LSP client is already running
  if godot_lsp_client_id then
    local client = vim.lsp.get_client_by_id(godot_lsp_client_id)
    if client then
      log_message("Reusing existing Godot LSP client with ID " .. godot_lsp_client_id, config)
      attach_buffer_to_client(vim.api.nvim_get_current_buf(), godot_lsp_client_id, config)
      return
    end
  end

  -- Check for existing godot_lsp clients to avoid duplicates
  for _, client in ipairs(vim.lsp.get_active_clients()) do
    if client.name == lsp_name then
      log_message("Found existing godot_lsp client with ID " .. client.id, config)
      godot_lsp_client_id = client.id
      attach_buffer_to_client(vim.api.nvim_get_current_buf(), godot_lsp_client_id, config)
      return
    end
  end

  -- Ensure lspconfig[lsp_name] is initialized
  if not lspconfig[lsp_name] then
    lspconfig[lsp_name] = {}
  end

  -- Setup LSP client
  local success, err = pcall(function()
    lspconfig[lsp_name].setup {
      cmd = config.cmd,
      filetypes = config.filetypes,
      root_dir = config.root_dir,
      settings = config.settings,
      capabilities = vim.tbl_deep_extend("force", vim.lsp.protocol.make_client_capabilities(), config.capabilities),
      on_attach = function(client, bufnr)
        log_message(
          "Godot LSP connected for buffer "
            .. bufnr
            .. " ("
            .. vim.api.nvim_buf_get_name(bufnr)
            .. ") with client ID "
            .. client.id
            .. " on port "
            .. port,
          config
        )
        -- Add default LSP mappings
        vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
        local opts = { buffer = bufnr, noremap = true, silent = true }
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
        vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
        -- Enable diagnostics
        vim.diagnostic.config {
          virtual_text = true,
          signs = true,
          underline = true,
          update_in_insert = false,
        }
      end,
      on_error = function(err)
        print("Godot LSP error: " .. vim.inspect(err))
      end,
      on_exit = function(code, signal)
        log_message("Godot LSP client exited with code " .. code .. " and signal " .. signal, config)
        godot_lsp_client_id = nil -- Reset client ID on exit
      end,
    }
  end)

  if not success then
    print("Failed to setup Godot LSP: " .. vim.inspect(err))
    return
  end

  -- Start LSP client
  godot_lsp_client_id = vim.lsp.start {
    name = lsp_name,
    cmd = config.cmd,
    root_dir = config.root_dir(vim.api.nvim_buf_get_name(0)),
    capabilities = config.capabilities,
    on_error = function(err)
      print("Godot LSP client error: " .. vim.inspect(err))
    end,
    on_init = function(client)
      log_message("Godot LSP client initialized with ID " .. client.id, config)
      godot_lsp_client_id = client.id
      -- Attach current buffer
      attach_buffer_to_client(vim.api.nvim_get_current_buf(), client.id, config)
    end,
  }

  if not godot_lsp_client_id then
    print("Failed to start Godot LSP client. Ensure 'ncat' is installed and Godot is running on port " .. port .. ".")
  end
end

-- Ensure filetype and TreeSitter highlighting for .gd files
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile", "BufEnter" }, {
  pattern = "*.gd",
  callback = function(args)
    local bufnr = args.buf
    vim.bo[bufnr].filetype = "gdscript"
    local config = default_config -- Use current config
    log_message(
      "Set filetype to gdscript for buffer " .. bufnr .. " (" .. vim.api.nvim_buf_get_name(bufnr) .. ")",
      config
    )
    -- Force TreeSitter highlighting
    local ok, ts = pcall(require, "nvim-treesitter.configs")
    if ok then
      local ts_status = ts.get_module "highlight"
      log_message("TreeSitter status for buffer " .. bufnr .. ": " .. vim.inspect(ts_status), config)
      if ts_status and not ts_status.enable then
        log_message("Enabling TreeSitter highlighting for buffer " .. bufnr, config)
        ts.setup { highlight = { enable = true, additional_vim_regex_highlighting = false } }
      end
      local parser_ok, _ = pcall(vim.treesitter.start, bufnr, "gdscript")
      if not parser_ok then
        log_message("Failed to start TreeSitter parser for gdscript in buffer " .. bufnr, config)
      end
    else
      log_message("nvim-treesitter not loaded for buffer " .. bufnr, config)
    end
  end,
})

-- Autocommand to attach GDScript buffers to LSP client
vim.api.nvim_create_autocmd({ "BufEnter", "BufReadPost" }, {
  pattern = "*.gd",
  callback = function(args)
    local bufnr = args.buf
    local config = default_config
    log_message(
      "BufEnter/BufReadPost triggered for buffer "
        .. bufnr
        .. " ("
        .. vim.api.nvim_buf_get_name(bufnr)
        .. "), filetype: "
        .. vim.bo[bufnr].filetype,
      config
    )
    vim.defer_fn(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        log_message("Buffer " .. bufnr .. " is no longer valid", config)
        return
      end
      if vim.bo[bufnr].filetype ~= "gdscript" then
        log_message(
          "Buffer "
            .. bufnr
            .. " ("
            .. vim.api.nvim_buf_get_name(bufnr)
            .. ") is not a GDScript file, filetype: "
            .. vim.bo[bufnr].filetype,
          config
        )
        return
      end
      if godot_lsp_client_id then
        local client = vim.lsp.get_client_by_id(godot_lsp_client_id)
        if client then
          attach_buffer_to_client(bufnr, godot_lsp_client_id, config)
        else
          log_message("No active Godot LSP client with ID " .. godot_lsp_client_id, config)
        end
      else
        -- Start LSP client if not already running
        local success, err = pcall(setup_godot_lsp)
        if not success then
          print("Error starting Godot LSP for GDScript buffer: " .. vim.inspect(err))
        end
      end
    end, 100) -- 100ms delay
  end,
})

-- User commands
vim.api.nvim_create_user_command("GodotLspStart", function()
  local success, err = pcall(setup_godot_lsp)
  if not success then
    print("Error starting Godot LSP: " .. vim.inspect(err))
  end
end, {})

vim.api.nvim_create_user_command("GodotLspStatus", function()
  local host, port = default_config.cmd[2], default_config.cmd[3]
  if test_ncat_connection(host, port, default_config) then
    print(string.format("Godot LSP server is reachable at %s:%s.", host, port))
  else
    print(string.format("Godot LSP server is not reachable at %s:%s. Ensure Godot is running with --lsp.", host, port))
  end
end, {})

vim.api.nvim_create_user_command("GodotLspAttachAll", function()
  if not godot_lsp_client_id then
    print "No active Godot LSP client to attach buffers to."
    return
  end
  local client = vim.lsp.get_client_by_id(godot_lsp_client_id)
  if not client then
    print("Godot LSP client with ID " .. godot_lsp_client_id .. " is no longer active.")
    godot_lsp_client_id = nil
    return
  end
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    attach_buffer_to_client(bufnr, godot_lsp_client_id, default_config)
  end
end, {})

-- Expose setup function for user configuration
return {
  setup = function(user_config)
    default_config = vim.tbl_deep_extend("force", default_config, user_config or {})
    print "Godot LSP plugin configured. LSP will start when a GDScript file is opened."
  end,
}
