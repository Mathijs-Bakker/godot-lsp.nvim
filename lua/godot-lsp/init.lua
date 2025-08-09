local ok, lspconfig = pcall(require, "lspconfig")
if not ok then
  print "Error: nvim-lspconfig is not installed or failed to load. Please install it to use godot-lsp.nvim."
  return
end
local util = require "lspconfig.util"

-- Default configuration for Godot LSP
local default_config = {
  cmd = { "ncat", "localhost", "6005" }, -- Simplified ncat command
  filetypes = { "gdscript" },
  root_dir = function(fname)
    return util.root_pattern("project.godot", ".git")(fname) or util.path.dirname(fname)
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

-- Test ncat connection
local function test_ncat_connection(host, port)
  local cmd = string.format("ncat %s %s --send-only < /dev/null 2>&1", host, port)
  local handle = io.popen(cmd)
  local result = handle:read "*a"
  handle:close()
  print("ncat test result: " .. (result == "" and "success" or "failed: " .. result))
  return result == ""
end

-- Start the LSP client for a buffer
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
        print("Godot LSP connected for buffer " .. bufnr .. " with client ID " .. client.id .. " on port " .. port)
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
      end,
    }
  end)

  if not success then
    print("Failed to setup Godot LSP: " .. vim.inspect(err))
    return
  end

  -- Start LSP client
  local client_id = vim.lsp.start {
    name = lsp_name,
    cmd = config.cmd,
    root_dir = config.root_dir(),
    capabilities = config.capabilities,
    on_error = function(err)
      print("Godot LSP client error: " .. vim.inspect(err))
    end,
    on_init = function(client)
      print("Godot LSP client initialized with ID " .. client.id)
    end,
  }

  if not client_id then
    print("Failed to start Godot LSP client. Ensure 'ncat' is installed and Godot is running on port " .. port .. ".")
  else
    print("Godot LSP client started with ID " .. client_id)
  end
end

-- Autocommand to start LSP for GDScript buffers with delay
vim.api.nvim_create_autocmd("FileType", {
  pattern = "gdscript",
  callback = function()
    vim.defer_fn(function()
      local success, err = pcall(setup_godot_lsp)
      if not success then
        print("Error starting Godot LSP for GDScript buffer: " .. vim.inspect(err))
      end
    end, 1000) -- 1000ms delay to ensure initialization
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

-- Expose setup function for user configuration
return {
  setup = function(user_config)
    default_config = vim.tbl_deep_extend("force", default_config, user_config or {})
    print "Godot LSP plugin configured. LSP will start when a GDScript file is opened."
  end,
}
