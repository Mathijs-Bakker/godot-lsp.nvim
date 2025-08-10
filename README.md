# godot-lsp.nvim

A Neovim plugin to integrate Godot's Language Server Protocol (LSP) for GDScript, providing features like go-to-definition, hover documentation, code actions, diagnostics, and completion across multiple buffers. Supports TreeSitter syntax highlighting and automatic LSP attachment for all open GDScript buffers.

## 📑 Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [With lazy.nvim](#with-lazynvim)
  - [Install TreeSitter Parser](#install-treesitter-parser)
- [External Editor Setup](#external-editor-setup)
- [Usage](#usage)
  - [Commands](#commands)
  - [Configuration](#configuration)
  - [Debug Logging](#debug-logging)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## ✨ Features

- **LSP Integration**: Connects to Godot's LSP server via `ncat` for GDScript autocompletion, definitions, hover info, code actions, and diagnostics.
- **Multi-Buffer Support**: Seamlessly attaches multiple GDScript buffers to the same LSP client, enabling consistent LSP features across all open files.
- **TreeSitter Support**: Enables syntax highlighting for GDScript files using `nvim-treesitter`.
- **Automatic Buffer Attachment**: Attaches all GDScript buffers to the LSP client automatically.
- **Customizable Keymaps**: Configurable key bindings for LSP actions like go-to-definition, hover, and diagnostics navigation.
- **User Commands**: Commands to start the LSP, check server status, and attach buffers manually.
- **Debug Logging**: Optional logging to `~/.cache/nvim/godot-lsp.log` for troubleshooting.

## 🛠️ Requirements

- Neovim 0.9.0 or later
- `ncat` (Netcat) installed (`brew install ncat` on macOS, `apt install ncat` on Debian/Ubuntu)
- Godot 4.3 or later with LSP enabled (`godot --editor --lsp --verbose`)
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) for syntax highlighting

## 📦 Installation

Install using your preferred Neovim package manager.

### With [lazy.nvim](https://github.com/folke/lazy.nvim)

Add to your `init.lua`:

📜
```lua
require("lazy").setup({
  {
    "username/godot-lsp.nvim",
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
})
```

Run `:Lazy sync` to install.

### Install TreeSitter Parser

Ensure the `gdscript` parser is installed:

🖥️
```lua
:TSInstall gdscript
```

## ⚙️ External Editor Setup

To open GDScript files from Godot directly in Neovim (running in a terminal) at the exact line and column, use a launch script for consistent behavior and to handle file paths with spaces. Use the full path to the script to avoid issues with `~` expansion.

1. **Create a Launch Script**:
   - Save the following as `/Users/<your-username>/.local/bin/open-nvim-godot.sh` (ensure `/Users/<your-username>/.local/bin` is in your `PATH`):
     📜
     ```bash
     #!/bin/bash
     # /Users/<your-username>/.local/bin/open-nvim-godot.sh
     FILE="$1"
     LINE="$2"
     COL="$3"
     /Applications/Ghostty.app/Contents/MacOS/ghostty -- nvim "$FILE" +"$LINE:$COL"  # macOS with Ghostty
     # gnome-terminal -- nvim "$FILE" +"$LINE:$COL"  # Linux with gnome-terminal
     # xterm -e nvim "$FILE" +"$LINE:$COL"  # Linux with xterm
     ```
   - Make it executable:
     🖥️
     ```bash
     chmod +x /Users/<your-username>/.local/bin/open-nvim-godot.sh
     ```
   - Add `/Users/<your-username>/.local/bin` to `PATH` if needed:
     🖥️
     ```bash
     echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
     source ~/.zshrc
     ```

2. **Configure Godot**:
   - In Godot, go to **Editor > Editor Settings > Text Editor > External**.
   - Check **Use External Editor**.
   - Set **Exec Path**: `/Users/<your-username>/.local/bin/open-nvim-godot.sh`
   - Set **Exec Flags**: `"{file}" "{line}" "{col}"`
   - 📌 **Note**: Use the full path (e.g., `/Users/LukeSkywalker/.local/bin/open-nvim-godot.sh`) instead of `~/.local/bin/open-nvim-godot.sh` to avoid expansion issues.

3. **Open Scripts**:
   - Double-click a script in Godot’s **FileSystem** dock or use **File > Open in External Editor**.
   - Click a specific position in Godot’s script editor to set the cursor, then open in the external editor.
   - Neovim opens in Ghostty at the specified line and column, with LSP and TreeSitter features enabled.

4. **Optional: Reuse Neovim Instance**:
   - Start Neovim with a server:
     🖥️
     ```bash
     nvim --listen ~/.cache/nvim/server.pipe
     ```
   - Modify the script to use:
     📜
     ```bash
     #!/bin/bash
     FILE="$1"
     LINE="$2"
     COL="$3"
     NVIM_SERVER="$HOME/.cache/nvim/server.pipe"
     if [ -S "$NVIM_SERVER" ]; then
         nvim --server "$NVIM_SERVER" --remote "$FILE" +"$LINE:$COL"
     else
         /Applications/Ghostty.app/Contents/MacOS/ghostty -- nvim "$FILE" +"$LINE:$COL"
     fi
     ```
   - The script will open files in the existing instance, preserving multi-buffer support.

## 🚀 Usage

1. Start Godot with LSP enabled:
   🖥️
   ```bash
   godot --editor --lsp --verbose
   ```
2. Open one or more GDScript files (`.gd`) from Godot or Neovim. The plugin will:
   - Set `filetype = gdscript` for each buffer.
   - Enable TreeSitter syntax highlighting for all buffers.
   - Attach all GDScript buffers to the Godot LSP server (port 6005 via `ncat`).
3. Use LSP features with the following default keymaps:
   - `gd`: Go to definition (`textDocument/definition`).
   - `K`: Show hover documentation (`textDocument/hover`).
   - `<leader>ca`: Open code actions (`textDocument/codeAction`).
   - `<C-x><C-o>`: Trigger code completion (`textDocument/completion`, in insert mode).
   - `<leader>cd`: Show diagnostics in a floating window (`diagnostic/open_float`).
   - `]d`: Go to next diagnostic (`diagnostic/goto_next`).
   - `[d`: Go to previous diagnostic (`diagnostic/goto_prev`).
4. Diagnostics appear as virtual text, signs, and underlines across all open buffers.

### Commands

- `:GodotLspStart`: Start the Godot LSP client manually.
- `:GodotLspStatus`: Check if the Godot LSP server is reachable at `localhost:6005`.
- `:GodotLspAttachAll`: Attach all loaded GDScript buffers to the LSP client.

### Configuration

Customize the plugin by passing options to `setup`:

📜
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
    completion = "<C-x><C-o>",          -- Trigger completion (in insert mode)
    diagnostic_open_float = "<leader>cd", -- Show diagnostics in floating window
    diagnostic_goto_next = "]d",        -- Go to next diagnostic
    diagnostic_goto_prev = "[d",        -- Go to previous diagnostic
    -- Set to nil or false to disable a keymap
  },
})
```

To disable a keymap, set it to `nil` or `false`:

📜
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
  - Run `:lua print(vim.inspect(require("nvim-treesitter.configs).get_module("highlight")))` to verify `enable = true`.
- **Slow or missing diagnostics**:
  - Diagnostics may be slow or persist for deleted files due to Godot LSP limitations.
  - Check `~/.cache/nvim/godot-lsp.log` with `debug_logging = true`.
- **Crashes during completion**:
  - Avoid triggering completion while running a game in the editor, as it may crash.
- **External editor issues**:
  - Test the launch script manually:
    🖥️
    ```bash
    /Users/<your-username>/.local/bin/open-nvim-godot.sh "/path/to/test script.gd" 10 5
    ```
  - Ensure `/Users/<your-username>/.local/bin` is in `PATH` (`echo $PATH`).
  - Verify script permissions: `ls -l /Users/<your-username>/.local/bin/open-nvim-godot.sh` (should show `-rwxr-xr-x`).
  - Test Ghostty directly:
    🖥️
    ```bash
    /Applications/Ghostty.app/Contents/MacOS/ghostty -- nvim "/path/to/test script.gd" +10:5
    ```
  - If Ghostty fails, try the default Terminal:
    🖥️
    ```bash
    /Applications/Utilities/Terminal.app/Contents/MacOS/Terminal -a nvim "/path/to/test script.gd" +10:5
    ```
  - Ensure **Exec Path** uses the full path (`/Users/<your-username>/.local/bin/open-nvim-godot.sh`), not `~/.local/bin/open-nvim-godot.sh`.
  - Check Godot’s output console for errors when opening the external editor.
- **Debug logs**:
  - Enable `debug_logging = true` and check `~/.cache/nvim/godot-lsp.log`.
  - Run `:lua print(vim.inspect(vim.lsp.get_active_clients()))` to verify one `godot_lsp` client.

## 🤝 Contributing

Contributions are welcome! Submit issues or pull requests to [github.com/username/godot-lsp.nvim](https://github.com/username/godot-lsp.nvim).

## 📄 License

MIT License
# godot-lsp.nvim

A Neovim plugin to integrate Godot's Language Server Protocol (LSP) for GDScript, providing features like go-to-definition, hover documentation, code actions, diagnostics, and completion across multiple buffers. Supports TreeSitter syntax highlighting and automatic LSP attachment for all open GDScript buffers.

## 📑 Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
  - [With lazy.nvim](#with-lazynvim)
  - [Install TreeSitter Parser](#install-treesitter-parser)
- [External Editor Setup](#external-editor-setup)
- [Usage](#usage)
  - [Commands](#commands)
  - [Configuration](#configuration)
  - [Debug Logging](#debug-logging)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## ✨ Features

- **LSP Integration**: Connects to Godot's LSP server via `ncat` for GDScript autocompletion, definitions, hover info, code actions, and diagnostics.
- **Multi-Buffer Support**: Seamlessly attaches multiple GDScript buffers to the same LSP client, enabling consistent LSP features across all open files.
- **TreeSitter Support**: Enables syntax highlighting for GDScript files using `nvim-treesitter`.
- **Automatic Buffer Attachment**: Attaches all GDScript buffers to the LSP client automatically.
- **Customizable Keymaps**: Configurable key bindings for LSP actions like go-to-definition, hover, and diagnostics navigation.
- **User Commands**: Commands to start the LSP, check server status, and attach buffers manually.
- **Debug Logging**: Optional logging to `~/.cache/nvim/godot-lsp.log` for troubleshooting.

## 🛠️ Requirements

- Neovim 0.9.0 or later
- `ncat` (Netcat) installed (`brew install ncat` on macOS, `apt install ncat` on Debian/Ubuntu)
- Godot 4.3 or later with LSP enabled (`godot --editor --lsp --verbose`)
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) for syntax highlighting

## 📦 Installation

Install using your preferred Neovim package manager.

### With [lazy.nvim](https://github.com/folke/lazy.nvim)

Add to your `init.lua`:

📜
```lua
require("lazy").setup({
  {
    "username/godot-lsp.nvim",
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
})
```

Run `:Lazy sync` to install.

### Install TreeSitter Parser

Ensure the `gdscript` parser is installed:

🖥️
```lua
:TSInstall gdscript
```

## ⚙️ External Editor Setup

To open GDScript files from Godot directly in Neovim (running in a terminal) at the exact line and column, use a launch script for consistent behavior and to handle file paths with spaces. Use the full path to the script to avoid issues with `~` expansion.

1. **Create a Launch Script**:
   - Save the following as `/Users/<your-username>/.local/bin/open-nvim-godot.sh` (ensure `/Users/<your-username>/.local/bin` is in your `PATH`):
     📜
     ```bash
     #!/bin/bash
     # /Users/<your-username>/.local/bin/open-nvim-godot.sh
     FILE="$1"
     LINE="$2"
     COL="$3"
     /Applications/Ghostty.app/Contents/MacOS/ghostty -- nvim "$FILE" +"$LINE:$COL"  # macOS with Ghostty
     # gnome-terminal -- nvim "$FILE" +"$LINE:$COL"  # Linux with gnome-terminal
     # xterm -e nvim "$FILE" +"$LINE:$COL"  # Linux with xterm
     ```
   - Make it executable:
     🖥️
     ```bash
     chmod +x /Users/<your-username>/.local/bin/open-nvim-godot.sh
     ```
   - Add `/Users/<your-username>/.local/bin` to `PATH` if needed:
     🖥️
     ```bash
     echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
     source ~/.zshrc
     ```

2. **Configure Godot**:
   - In Godot, go to **Editor > Editor Settings > Text Editor > External**.
   - Check **Use External Editor**.
   - Set **Exec Path**: `/Users/<your-username>/.local/bin/open-nvim-godot.sh`
   - Set **Exec Flags**: `"{file}" "{line}" "{col}"`
   - 📌 **Note**: Use the full path (e.g., `/Users/LukeSkywalker/.local/bin/open-nvim-godot.sh`) instead of `~/.local/bin/open-nvim-godot.sh` to avoid expansion issues.

3. **Open Scripts**:
   - Double-click a script in Godot’s **FileSystem** dock or use **File > Open in External Editor**.
   - Click a specific position in Godot’s script editor to set the cursor, then open in the external editor.
   - Neovim opens in Ghostty at the specified line and column, with LSP and TreeSitter features enabled.

4. **Optional: Reuse Neovim Instance**:
   - Start Neovim with a server:
     🖥️
     ```bash
     nvim --listen ~/.cache/nvim/server.pipe
     ```
   - Modify the script to use:
     📜
     ```bash
     #!/bin/bash
     FILE="$1"
     LINE="$2"
     COL="$3"
     NVIM_SERVER="$HOME/.cache/nvim/server.pipe"
     if [ -S "$NVIM_SERVER" ]; then
         nvim --server "$NVIM_SERVER" --remote "$FILE" +"$LINE:$COL"
     else
         /Applications/Ghostty.app/Contents/MacOS/ghostty -- nvim "$FILE" +"$LINE:$COL"
     fi
     ```
   - The script will open files in the existing instance, preserving multi-buffer support.

## 🚀 Usage

1. Start Godot with LSP enabled:
   🖥️
   ```bash
   godot --editor --lsp --verbose
   ```
2. Open one or more GDScript files (`.gd`) from Godot or Neovim. The plugin will:
   - Set `filetype = gdscript` for each buffer.
   - Enable TreeSitter syntax highlighting for all buffers.
   - Attach all GDScript buffers to the Godot LSP server (port 6005 via `ncat`).
3. Use LSP features with the following default keymaps:
   - `gd`: Go to definition (`textDocument/definition`).
   - `K`: Show hover documentation (`textDocument/hover`).
   - `<leader>ca`: Open code actions (`textDocument/codeAction`).
   - `<C-x><C-o>`: Trigger code completion (`textDocument/completion`, in insert mode).
   - `<leader>cd`: Show diagnostics in a floating window (`diagnostic/open_float`).
   - `]d`: Go to next diagnostic (`diagnostic/goto_next`).
   - `[d`: Go to previous diagnostic (`diagnostic/goto_prev`).
4. Diagnostics appear as virtual text, signs, and underlines across all open buffers.

### Commands

- `:GodotLspStart`: Start the Godot LSP client manually.
- `:GodotLspStatus`: Check if the Godot LSP server is reachable at `localhost:6005`.
- `:GodotLspAttachAll`: Attach all loaded GDScript buffers to the LSP client.

### Configuration

Customize the plugin by passing options to `setup`:

📜
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
    completion = "<C-x><C-o>",          -- Trigger completion (in insert mode)
    diagnostic_open_float = "<leader>cd", -- Show diagnostics in floating window
    diagnostic_goto_next = "]d",        -- Go to next diagnostic
    diagnostic_goto_prev = "[d",        -- Go to previous diagnostic
    -- Set to nil or false to disable a keymap
  },
})
```

To disable a keymap, set it to `nil` or `false`:

📜
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
  - Run `:lua print(vim.inspect(require("nvim-treesitter.configs).get_module("highlight")))` to verify `enable = true`.
- **Slow or missing diagnostics**:
  - Diagnostics may be slow or persist for deleted files due to Godot LSP limitations.
  - Check `~/.cache/nvim/godot-lsp.log` with `debug_logging = true`.
- **Crashes during completion**:
  - Avoid triggering completion while running a game in the editor, as it may crash.
- **External editor issues**:
  - Test the launch script manually:
    🖥️
    ```bash
    /Users/<your-username>/.local/bin/open-nvim-godot.sh "/path/to/test script.gd" 10 5
    ```
  - Ensure `/Users/<your-username>/.local/bin` is in `PATH` (`echo $PATH`).
  - Verify script permissions: `ls -l /Users/<your-username>/.local/bin/open-nvim-godot.sh` (should show `-rwxr-xr-x`).
  - Test Ghostty directly:
    🖥️
    ```bash
    /Applications/Ghostty.app/Contents/MacOS/ghostty -- nvim "/path/to/test script.gd" +10:5
    ```
  - If Ghostty fails, try the default Terminal:
    🖥️
    ```bash
    /Applications/Utilities/Terminal.app/Contents/MacOS/Terminal -a nvim "/path/to/test script.gd" +10:5
    ```
  - Ensure **Exec Path** uses the full path (`/Users/<your-username>/.local/bin/open-nvim-godot.sh`), not `~/.local/bin/open-nvim-godot.sh`.
  - Check Godot’s output console for errors when opening the external editor.
- **Debug logs**:
  - Enable `debug_logging = true` and check `~/.cache/nvim/godot-lsp.log`.
  - Run `:lua print(vim.inspect(vim.lsp.get_active_clients()))` to verify one `godot_lsp` client.

## 🤝 Contributing

Contributions are welcome! Submit issues or pull requests to [github.com/username/godot-lsp.nvim](https://github.com/username/godot-lsp.nvim).

## 📄 License

MIT License
