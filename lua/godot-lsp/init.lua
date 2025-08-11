-- lua/godot-lsp/init.lua
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
  },
}

-- Setup function
function M.setup(opts)
  opts = vim.tbl_deep_extend("force", defaults, opts or {})

  -- Setup LSP client
  local lspconfig = require "lspconfig"
  lspconfig.godot_lsp = {
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

    -- Keymaps
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
  lspconfig.godot_lsp.setup {
    cmd = opts.cmd,
    filetypes = opts.filetypes,
    on_attach = on_attach,
    flags = { debounce_text_changes = 150 },
  }

  -- Autocommands
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "gdscript",
    callback = function()
      if opts.skip_godot_check or vim.fn.executable "godot" == 1 then
        vim.cmd "GodotLspStart"
      end
    end,
    desc = "Start Godot LSP for GDScript files",
  })

  vim.api.nvim_create_autocmd("BufReadPost", {
    pattern = "*.gd",
    callback = function()
      vim.cmd "GodotLspAttachAll"
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

  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*.gd",
    callback = function()
      -- Optional: Notify Godot to reload the script (if supported by LSP)
      vim.lsp.buf_notify(0, "godot/reloadScript", { uri = vim.uri_from_bufnr(0) })
    end,
    desc = "Notify Godot to reload script on save",
  })

  vim.api.nvim_create_autocmd("BufDelete", {
    pattern = "*.gd",
    callback = function()
      vim.lsp.buf_detach_client(0, vim.lsp.get_client_by_id "godot_lsp")
    end,
    desc = "Detach GDScript buffer from LSP on close",
  })

  -- Commands
  vim.api.nvim_create_user_command("GodotLspStart", function()
    lspconfig.godot_lsp.setup { on_attach = on_attach }
    vim.lsp.start_client(lspconfig.godot_lsp)
    if opts.debug_logging then
      vim.notify("Godot LSP started", vim.log.levels.INFO)
    end
  end, { desc = "Start Godot LSP client" })

  vim.api.nvim_create_user_command("GodotLspStatus", function()
    local clients = vim.lsp.get_active_clients { name = "godot_lsp" }
    if #clients > 0 then
      vim.notify("Godot LSP is running", vim.log.levels.INFO)
    else
      vim.notify("Godot LSP is not running", vim.log.levels.WARN)
    end
  end, { desc = "Check Godot LSP status" })

  vim.api.nvim_create_user_command("GodotLspAttachAll", function()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].filetype == "gdscript" then
        vim.lsp.buf_attach_client(buf, vim.lsp.get_client_by_id "godot_lsp")
      end
    end
  end, { desc = "Attach all GDScript buffers to LSP" })

  -- Debug logging
  if opts.debug_logging then
    vim.lsp.set_log_level "debug"
    vim.notify("Godot LSP debug logging enabled at ~/.cache/nvim/godot-lsp.log", vim.log.levels.INFO)
  end
end

return M
