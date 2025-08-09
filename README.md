# 🤖 godot-lsp.nvim

A Neovim plugin to integrate Godot's Language Server Protocol (LSP) for GDScript, providing features like go-to-definition, hover documentation, code actions, diagnostics, and completion. Supports TreeSitter syntax highlighting and automatic buffer attachment for GDScript files.

## ✨ Features

- 🔌 **LSP Integration**: Connects to Godot's LSP server via `ncat` for GDScript autocompletion, definitions, hover info, code actions, and diagnostics.
- 🌳 **TreeSitter Support**: Enables syntax highlighting for GDScript files using `nvim-treesitter`.
- ⚡ **Automatic Buffer Attachment**: Attaches all GDScript buffers to the LSP client automatically.
- ⌨️ **Customizable Keymaps**: Configurable key bindings for LSP actions like go-to-definition, hover, and diagnostics navigation.
- 🛠 **User Commands**: Commands to start the LSP, check server status, and attach buffers manually.
- 📜 **Debug Logging**: Optional logging to `~/.cache/nvim/godot-lsp.log` for troubleshooting.

## 📦 Requirements

- Neovim 0.9.0 or later
- `ncat` (Netcat) installed (`brew install ncat` on macOS, `apt install ncat` on Debian/Ubuntu)
- Godot 4.3 or later with LSP enabled (`godot --editor --lsp --verbose`)
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) for syntax highlighting
- Optional: [fidget.nvim](https://github.com/j-hui/fidget.nvim) for LSP progress notifications
- Optional: [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) for file navigation

## 📥 Installation

Install using your preferred Neovim package manager.

### With [lazy.nvim](https://github.com/folke/lazy.nvim)

Add to your `init.lua`:

```lua
require("lazy").setup({
  {
    "Mathijs-Bakker/godot-lsp.nvim",
    config = function()
      require("godot-lsp").setup({
        skip_godot_check = true, -- Skip Godot process check
        debug_logging = false,    -- Enable debug logs in ~/.cache/nvim/godot-lsp.log
        keymaps = {              -- Customize LSP keymaps
          definition = "gd",
          hover = "K",
          code_action = "<leader>ca",
          completion = "<C-x><C-o>",
          diagnostic_open_float = "<leader>cd",
          diagnostic_goto_next = "]d",
          diagnostic_goto_prev = "[d",
        },
      })
    end,
  },
  { "neovim/nvim-lspconfig" },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter.configs").setup({
        ensure_installed = { "gdscript" },
        highlight = { enable = true, additional_vim_regex_highlighting = false },
      })
    end,
  },
  { "j-hui/fidget.nvim", opts = { notification = { window = { winblend = 0 } } } },
  { "nvim-telescope/telescope.nvim", dependencies = { "nvim-lua/plenary.nvim" } },
})
```

Run `:Lazy sync` to install.

### Install TreeSitter Parser

Ensure the `gdscript` parser is installed:

```lua
:TSInstall gdscript
```

## 🚀 Usage

1. Start Godot with LSP enabled:
   ```bash
   godot --editor --lsp --verbose
   ```
2. Open a GDScript file (`.gd`) in Neovim. The plugin will:
   - Set `filetype = gdscript`.
   - Enable TreeSitter syntax highlighting.
   - Attach the buffer to the Godot LSP server (port 6005 via `ncat`).
3. Use LSP features with the following default keymaps:
   - `gd`: Go to definition (`textDocument/definition`).
   - `K`: Show hover documentation (`textDocument/hover`).
   - `<leader>ca`: Open code actions (`textDocument/codeAction`).
   - `<C-x><C-o>`: Trigger code completion (`textDocument/completion`, in insert mode).
   - `<leader>cd`: Show diagnostics in a floating window (`diagnostic/open_float`).
   - `]d`: Go to next diagnostic (`diagnostic/goto_next`).
   - `[d`: Go to previous diagnostic (`diagnostic/goto_prev`).
4. Diagnostics appear as virtual text, signs, and underlines.

### 🛠 Commands

- `:GodotLspStart`: Start the Godot LSP client manually.
- `:GodotLspStatus`: Check if the Godot LSP server is reachable at `localhost:6005`.
- `:GodotLspAttachAll`: Attach all loaded GDScript buffers to the LSP client.

### ⚙ Configuration

Customize the plugin by passing options to `setup`:

```lua
require("godot-lsp").setup({
  cmd = { "ncat", "localhost", "6005" }, -- LSP command (default)
  filetypes = { "gdscript" },            -- Filetypes to trigger LSP (default)
  skip_godot_check = true,              -- Skip checking for Godot process
  debug_logging = false,                 -- Log debug info to ~/.cache/nvim/godot-lsp.log
  keymaps = {                           -- Customize LSP keymaps
    definition = "gd",                  -- Go to definition
    hover = "K",                        -- Show hover documentation
    code_action = "<leader>ca",         -- Code actions
    completion = "<C-x><C-o>",          -- Trigger completion (insert mode)
    diagnostic_open_float = "<leader>cd", -- Show diagnostics in floating window
    diagnostic_goto_next = "]d",        -- Go to next diagnostic
    diagnostic_goto_prev = "[d",        -- Go to previous diagnostic
    -- Set to nil or false to disable a keymap
  },
})
```

To disable a keymap, set it to `nil` or `false`:

```lua
keymaps = {
  code_action = nil, -- Disable code action keymap
}
```

### Debug Logging

Enable `debug_logging = true` to write debug messages (e.g., buffer attachment, TreeSitter status) to `~/.cache/nvim/godot-lsp.log`. Useful for troubleshooting.

## 🐞 Troubleshooting

- **LSP not starting**:
  - Ensure Godot is running with `--lsp` (`godot --editor --lsp --verbose`).
  - Verify `ncat` is installed and accessible.
  - Run `:GodotLspStatus` to check server connectivity.
  - Check `~/.cache/nvim/lsp.log` with `:LspLog`.
- **No syntax highlighting**:
  - Ensure `nvim-treesitter` is installed and `gdscript` parser is active (`:TSInstall gdscript`).
  - Run `:lua print(vim.inspect(require("nvim-treesitter.configs").get_module("highlight")))` to verify `enable = true`.
- **Telescope issues**:
  - If errors occur when opening files via `:Telescope find_files`, ensure `/after/ftplugin/gdscript.lua` does not start a duplicate LSP server.
  - Test with `:e path/to/file.gd` to isolate Telescope-related issues.
- **Slow or missing diagnostics**:
  - Diagnostics may be slow or persist for deleted files due to Godot LSP limitations.[](https://github.com/godotengine/godot/issues/87410)[](https://github.com/godotengine/godot/issues/43133)
  - Check `~/.cache/nvim/godot-lsp.log` with `debug_logging = true`.
- **Debug logs**:
  - Enable `debug_logging = true` and check `~/.cache/nvim/godot-lsp.log`.
  - Run `:lua print(vim.inspect(vim.lsp.get_active_clients()))` to verify one `godot_lsp` client.
- **Crashes during completion**:
  - Avoid triggering completion while running a game in the editor, as it may crash.[](https://github.com/godotengine/godot/issues/102036)

## 🤝 Contributing

Contributions are welcome! Submit issues or pull requests to [github.com/Mathijs-Bakker/godot-lsp.nvim](https://github.com/Mathijs-Bakker/godot-lsp.nvim).

## 📜 License

MIT License
