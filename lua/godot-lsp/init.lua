local lspconfig = require "lspconfig"
local util = require "lspconfig.util"

-- Configuration for Godot LSP
local godot_lsp = {
  name = "godot_lsp",
  cmd = { "ncat", "localhost", "6005" }, -- Connect to Godot's LSP port (adjust if needed)
  filetypes = { "gdscript" },
  root_dir = function(fname)
    return util.root_pattern("project.godot", ".git")(fname) or util.path.dirname(fname)
  end,
  settings = {},
}

-- Function to check if Godot is running
local function is_godot_running()
  local handle = io.popen "pgrep -f 'godot.*--lsp'"
  local result = handle:read "*a"
  handle:close()
  return result ~= ""
end

-- Start the LSP client for a buffer
local function setup_godot_lsp()
  if not is_godot_running() then
    print "Godot LSP server is not running. Start Godot with --lsp or check the port."
    return
  end

  lspconfig[godot_lsp.name] = godot_lsp
  lspconfig[godot_lsp.name].setup {
    cmd = godot_lsp.cmd,
    filetypes = godot_lsp.filetypes,
    root_dir = godot_lsp.root_dir,
    settings = godot_lsp.settings,
    on_attach = function(client, bufnr)
      print("Godot LSP connected for buffer " .. bufnr)
      -- Add default LSP mappings
      vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")
      local opts = { buffer = bufnr, noremap = true, silent = true }
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
      vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    end,
  }

  -- Force LSP start for the current buffer
  vim.lsp.start_client(lspconfig[godot_lsp.name].config)
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
  if is_godot_running() then
    print "Godot LSP server is running."
  else
    print "Godot LSP server is not running."
  end
end, {})

return {
  setup = setup_godot_lsp,
}
