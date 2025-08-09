# Neovim Godot LSP Plugin
A Neovim plugin to integrate with Godot's Language Server Protocol (LSP) for GDScript, supporting multiple buffers in a single Neovim instance.

## Features

- Connects to Godot's LSP server (default port 6005).
- Supports multiple GDScript buffers in one Neovim instance via a shared LSP client.
- Automatically detects GDScript files and starts the LSP.
- Provides commands `:GodotLspStart` and `:GodotLspStatus` for manual control.
- Includes default LSP keybindings for navigation and code actions.

## Requirements

- Neovim 0.5.0 or later.
- `nvim-lspconfig` plugin.
- `ncat` (install via `brew install nmap` on macOS).
- Godot 4.x with LSP enabled (run with `--lsp` or enable in Editor Settings).

## Installation

**Using lazy.nvim**
```lua
require("lazy").setup({
  {
    "username/godot-lsp.nvim",
    config = function()
      require("godot-lsp").setup()
    end,
  },
})
```

**Using packer.nvim**
```lua
use {
  "username/godot-lsp.nvim",
  config = function()
    require("godot-lsp").setup()
  end,
}
```

## Usage

1. Start Godot with LSP enabled:
```bash
godot --editor --lsp
```
1. Or enable the LSP server in Godot's Editor Settings under Language Server.
1. Open a GDScript file (`.gd`) in Neovim. The plugin automatically detects and connects to the Godot LSP server.
Use the following commands:
`:GodotLspStart` - Manually start the LSP client.
`:GodotLspStatus` - Check if the Godot LSP server is running.


Default keybindings:
`gd`: Go to definition.
`K`: Show hover documentation.
`<leader>ca`: Code actions.



## Configuration
You can customize the LSP settings by modifying your Neovim configuration. For example, to change the port:
```lua
require("godot-lsp").setup({
  cmd = { "ncat", "localhost", "6008" }, -- For Godot 3.x
})
```

## Notes

- Only one Neovim instance can connect to Godot's LSP server at a time due to the single TCP port limitation. For multiple instances, consider running multiple Godot instances with different ports or using a proxy (not included).
- Ensure Godot is running with the LSP server enabled before opening Neovim.

## Troubleshooting

- Use `:LspInfo` to check the LSP client status.
- If the LSP doesn't connect, verify the port (6005 for Godot 4, 6008 for Godot 3) and ensure `ncat` is installed.
- Run `:GodotLspStatus` to confirm if Godot's LSP server is active.

## License
MIT
