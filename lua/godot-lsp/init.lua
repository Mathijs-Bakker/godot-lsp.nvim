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
      print("Resolved root_dir: " .. root)
      return root
    end
    print("No project.godot found, falling back to file directory: " .. util.path.dirname(fname))
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
}

-- Store client ID to reuse across buffers
local godot_lsp_client_id = nil

-- Test ncat connection
local function test_ncat_connection(host, port)
  local cmd = string.format("ncat %s %s --send-only < /dev/null 2>&1", host, port)
  local handle = io.popen(cmd)
  local result = handle:read "*a"
  handle:close()
  print("ncat test result: " .. (result == "" and "success" or "failed: " .. result))
  return result == ""
end

-- Attach buffer to LSP client
local function attach_buffer_to_client(bufnr, client_id)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    print("Buffer " .. bufnr .. " is invalid")
    return
  end
  if vim.bo[bufnr].filetype ~= "gdscript" then
    print(
      "Buffer "
        .. bufnr
        .. " ("
        .. vim.api.nvim_buf_get_name(bufnr)
        .. ") is not a GDScript file, filetype: "
        .. vim.bo[bufnr].filetype
    )
    return
  end
  if not vim.api.nvim_buf_is_loaded(bufnr) then
    print("Buffer " .. bufnr .. " (" .. vim.api.nvim_buf_get_name(bufnr) .. ") is not loaded")
    return
  end
  local success, err = pcall(vim.lsp.buf_attach_client, bufnr, client_id)
  if success then
    print(
      "Attached buffer "
        .. bufnr
        .. " ("
        .. vim.api.nvim_buf_get_name(bufnr)
        .. ") to Godot LSP client ID "
        .. client_id
    )
  else
    print(
      "Failed to attach buffer "
        .. bufnr
        .. " ("
        .. vim.api.nvim_buf_get_name(bufnr)
        .. ") to Godot LSP client ID "
        .. client_id
        .. ": "
        .. vim.inspect(err)
    )
  end
end

-- Start or attach to the LSP client
local function setup_godot_lsp(user_config)
  local config = vim.tbl_deep_extend("force", default_config, user_config or {})
  local lsp_name = "godot_lsp"

  -- Test ncat connection
  local host, port = config.cmd[2], config.cmd[3]
  if not test_ncat_connection(host, port) then
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
      print("Reusing existing Godot LSP client with ID " .. godot_lsp_client_id)
      attach_buffer_to_client(vim.api.nvim_get_current_buf(), godot_lsp_client_id)
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
        print(
          "Godot LSP connected for buffer "
            .. bufnr
            .. " ("
            .. vim.api.nvim_buf_get_name(bufnr)
            .. ") with client ID "
            .. client.id
            .. " on port "
            .. port
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
        print("Godot LSP client exited with code " .. code .. " and signal " .. signal)
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
      print("Godot LSP client initialized with ID " .. client.id)
      godot_lsp_client_id = client.id
      -- Attach current buffer
      attach_buffer_to_client(vim.api.nvim_get_current_buf(), client.id)
    end,
  }

  if not godot_lsp_client_id then
    print("Failed to start Godot LSP client. Ensure 'ncat' is installed and Godot is running on port " .. port .. ".")
  else
    print("Godot LSP client started with ID " .. godot_lsp_client_id)
  end
end

-- Ensure filetype is set for .gd files
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.gd",
  callback = function(args)
    local bufnr = args.buf
    vim.bo[bufnr].filetype = "gdscript"
    print("Set filetype to gdscript for buffer " .. bufnr .. " (" .. vim.api.nvim_buf_get_name(bufnr) .. ")")
  end,
})

-- Autocommand to attach GDScript buffers to LSP client
vim.api.nvim_create_autocmd({ "BufEnter", "BufReadPost" }, {
  pattern = "*.gd",
  callback = function(args)
    local bufnr = args.buf
    print(
      "BufEnter/BufReadPost triggered for buffer "
        .. bufnr
        .. " ("
        .. vim.api.nvim_buf_get_name(bufnr)
        .. "), filetype: "
        .. vim.bo[bufnr].filetype
    )
    vim.defer_fn(function()
      if not vim.api.nvim_buf_is_valid(bufnr) then
        print("Buffer " .. bufnr .. " is no longer valid")
        return
      end
      if vim.bo[bufnr].filetype ~= "gdscript" then
        print(
          "Buffer "
            .. bufnr
            .. " ("
            .. vim.api.nvim_buf_get_name(bufnr)
            .. ") is not a GDScript file, filetype: "
            .. vim.bo[bufnr].filetype
        )
        return
      end
      if godot_lsp_client_id then
        local client = vim.lsp.get_client_by_id(godot_lsp_client_id)
        if client then
          attach_buffer_to_client(bufnr, godot_lsp_client_id)
        else
          print("No active Godot LSP client with ID " .. godot_lsp_client_id)
        end
      else
        -- Start LSP client if not already running
        local success, err = pcall(setup_godot_lsp)
        if not success then
          print("Error starting Godot LSP for GDScript buffer: " .. vim.inspect(err))
        end
      end
    end, 1500) -- 1500ms delay to ensure filetype is set
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
  if test_ncat_connection(host, port) then
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
    attach_buffer_to_client(bufnr, godot_lsp_client_id)
  end
end, {})

-- Expose setup function for user configuration
return {
  setup = function(user_config)
    default_config = vim.tbl_deep_extend("force", default_config, user_config or {})
    print "Godot LSP plugin configured. LSP will start when a GDScript file is opened."
  end,
}
