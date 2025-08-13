# Troubleshooting

This document provides detailed steps to diagnose and resolve common issues with `godot-lsp.nvim`. If you encounter a problem, follow the relevant section below and check the debug logs at `~/.cache/nvim/godot-lsp.log` (enable with `debug_logging = true` in the plugin setup).

## General Issues

### LSP Not Starting

-   **Cause:** Godot may not be running with LSP enabled, or ncat is unavailable.
-   **Steps:**
    -   Ensure Godot is started with godot `--editor --lsp --verbose`.
    -   Verify `ncat` is installed (e.g., `brew install ncat` on macOS, `apt install ncat` on Linux).
    -   Run `:GodotLspStatus` to check server connectivity at `localhost:6005`.
    -   Check Neovim's LSP log with `:LspLog`.

### No Syntax Highlighting

-   **Cause:** nvim-treesitter or the gdscript parser may not be properly installed.
-   **Steps:**
    -   Ensure `nvim-treesitter` is installed and the gdscript parser is active with `:TSInstall gdscript`.
    -   Run `:lua print(vim.inspect(require("nvim-treesitter.configs").get_module("highlight")))` to verify `enable = true`.

### Slow or Missing Diagnostics

-   **Cause:** Godot LSP limitations may cause delays or persistent diagnostics for deleted files.
-   **Steps:**
    -   Check `~/.cache/nvim/godot-lsp.log` with `debug_logging = true`.
    -   Accept minor delays as a known Godot LSP constraint.

### Crashes During Completion

-   **Cause:** Triggering completion while running a game in the editor may overwhelm the LSP server.
-   **Steps:**
    -   Avoid using completion (`<C-x><C-o>`) during game runtime in Godot.

### External Editor Issues

-   **Cause:** The launch script or Godot configuration may be misconfigured.
-   **Steps:**
    -   Test the script manually:
        ```bash
        /Users/<your-username>/.local/bin/open-nvim-godot.sh "/path/to/test script.gd" 10 5
        ```
    -   Ensure `/Users/<your-username>/.local/bin` is in PATH (run `echo $PATH`).
    -   Verify script permissions: `ls -l /Users/<your-username>/.local/bin/open-nvim-godot.sh` (should show `-rwxr-xr-x`).
    -   Test Ghostty directly on macOS:
        ```bash 
        /Applications/Ghostty.app/Contents/MacOS/ghostty -- nvim "/path/to/test script.gd" +10:5
        ```
    -   For _Linux_, test with _gnome-terminal_ or _xterm_ if Ghostty isn't available.
    -   Ensure **Exec Path** in Godot uses the full path (e.g., `/Users/<your-username>/.local/bin/open-nvim-godot.sh`), not `~/.local/bin/open-nvim-godot.sh`.
    -   Check Godot's output console for errors.

### DAP Debugging Issues

-   **Cause:** nvim-dap or Godot's remote debugging may not be configured correctly.
-   **Steps:**
    -   Ensure `nvim-dap` and `nvim-dap-ui` are installed.
    -   Verify Godot is running with `--remote-debug localhost:6006` (e.g., `godot --remote-debug localhost:6006 --editor`).
    -   Check the program path in your DAP configuration (e.g., `/path/to/your/project.godot`).
    -   Enable `debug_logging` = true and inspect `~/.cache/nvim/godot-lsp.log`.

### Debug Logs

-   **How to Use:**
    -   Enable `debug_logging = true` in the setup configuration.
    -   Check `~/.cache/nvim/godot-lsp.log` for details on buffer attachment, TreeSitter status, or LSP errors.
    -   Run `:lua print(vim.inspect(vim.lsp.get_clients({ name = "godot_lsp" })))` to verify the godot_lsp client.

### Godot LSP Limitations

Godot's built-in LSP for GDScript is functional but less robust than servers like _clangd_ or _pyright_ due to its dynamic nature and partial implementation. Key supported features include _diagnostics, go-to-definition, hover,_ and _autocomplete_, while limitations include missing _type definition, code actions,_ and _formatting_. For a detailed breakdown, see [Godot LSP Capabilities](godot_lsp_capabilities.md). 

Workarounds:
-   Use `gd` instead of `gt` for `definitions`.
-   Install gdformat (`pip install gdtoolkit`) for formatting: `:!gdformat %`.

### Additional Notes

-   **Linux Compatibility:** Untested but should work with `ncat` and terminal emulators like `gnome-terminal` or `xterm`. Feedback is welcome!
-   **Windows Support:** Not planned due to lack of a Windows machine; contributions are encouraged.
-   **Community Help:** Report issues or suggest fixes at [github.com/Mathijs-Bakker/godot-lsp.nvim](https://github.com/Mathijs-Bakker/godot-lsp.nvim).
