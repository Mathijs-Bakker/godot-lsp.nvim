local lspconfig = require "lspconfig"
local util = require "lspconfig.util"

-- Default configuration for Godot LSP
local default_config = {
  cmd = { "ncat", "localhost", "6005" }, -- Connect to Godot's LSP port
  filetypes = { "gdscript" },
  root_dir = function(fname)
    return util.root_pattern("project.godot", ".git")(fname) or util.path.dirname(fname)
  end,
  settings = {},
  skip_godot_check = true, -- Skip pgrep check by default since manual ncat works
}

-- Function to check if Godot is running (optional, for debugging)
local function is_godot_running()
  local handle = io.popen "pgrep -f 'godot.*--lsp' 2>/dev/null"
  local result = handle:read "*a"
  handle:close()
  return result ~= ""
end

-- Test ncat connection
local function test_ncat_connection(host, port)
  local cmd = string.format("ncat %s %s --send-only < /dev/null 2>&1", host, port)
  local handle = io.popen(cmd)
  local result = handle:read "*a"
  handle:close()
  return result == ""
end

-- Start the LSP client for a buffer
local function setup_godot_lsp(user_config)
  local config = vim.tbl_deep_extend("force", default_config, user_config or {})
  local lsp_name = "godot_lsp"

  -- Skip Godot check if configured or test ncat connection
  if not config.skip_godot_check then
    if not is_godot_running() then
      print "Godot LSP server not detected via pgrep. Ensure Godot is running with --lsp."
      return
    end
  end

  -- Test ncat connection
  local host, port = config.cmd[2], config.cmd[3]
  if not test_ncat_connection(host, port) then
    print(
      string.format(
        "Failed to connect to Godot LSP server at %s:%s using ncat. Ensure ncat is installed and the port is correct.",
        host,
        port
      )
    )
    return
  end

  lspconfig[lsp_name] = {
    name = lsp_name,
    cmd = config.cmd,
    filetypes = config.filetypes,
    root_dir = config.root_dir,
    settings = config.settings,
  }

  lspconfig[lsp_name].setup {
    cmd = config.cmd,
    filetypes = config.filetypes,
    root_dir = config.root_dir,
    settings = config.settings,
    on_attach = function(client, bufnr)
      print("Godot LSP connected for buffer " .. bufnr .. " on port " .. config.cmd[3])
      -- Add default LSP mappings
      vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
      local opts = { buffer = bufnr, noremap = true, silent = true }
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
      vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    end,
    on_error = function(err)
      print("Godot LSP error: " .. vim.inspect(err))
    end,
    on_exit = function(code, signal)
      print("Godot LSP client exited with code " .. code .. " and signal " .. signal)
    end,
  }

  -- Force LSP start for the current buffer
  local client_id = vim.lsp.start_client(lspconfig[lsp_name].config)
  if not client_id then
    print(
      "Failed to start Godot LSP client. Ensure 'ncat' is installed and Godot is running on port "
        .. config.cmd[3]
        .. "."
    )
  else
    print("Godot LSP client started with ID " .. client_id)
  end
end

-- Autocommand to start LSP for GDScript buffers
vim.api.nvim_create_autocmd("FileType", {
  pattern = "gdscript",
  callback = function()
    setup_godot_lsp()
  end,
})

-- User commands
vim.api.nvim_create_user_command("GodotLspStart", function()
  setup_godot_lsp()
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
    setup_godot_lsp(user_config)
  end,
}
