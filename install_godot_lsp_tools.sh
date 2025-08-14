#!/bin/bash

# Define installation directory
INSTALL_DIR="$HOME/.local/bin"

# Create directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
  mkdir -p "$INSTALL_DIR"
  if [ $? -ne 0 ]; then
    echo "Failed to create directory $INSTALL_DIR. Please check permissions."
    exit 1
  fi
fi

# Define file paths
OPEN_NVM_SCRIPT="$INSTALL_DIR/open-nvim-godot.sh"
RELOAD_GD="$INSTALL_DIR/reload.gd"

# Content for open-nvim-godot.sh
cat << 'EOF' > "$OPEN_NVM_SCRIPT"
#!/bin/bash
FILE="$1"
LINE="$2"
COL="$3"
ACTION="$4"

# Check if ACTION is provided
if [ -z "$ACTION" ]; then
  echo "Error: No action specified. Usage: $0 <file> <line> <col> <action> (e.g., 'reload' or 'open')"
  exit 1
fi

# Determine the platform
case "$(uname -s)" in
  Darwin) # macOS
    PLATFORM="macos"
    ;;
  Linux)
    PLATFORM="linux"
    ;;
  *)
    echo "Unsupported platform: $(uname -s)"
    exit 1
    ;;
esac

# Function to find an available terminal, respecting PREFERRED_TERMINAL
find_terminal() {
  local preferred_terminal="$PREFERRED_TERMINAL"
  local terminals=()

  # Define terminals based on platform
  if [ "$PLATFORM" = "linux" ]; then
    terminals=(
      "kitty"          # Kitty (cross-platform)
      "alacritty"      # Alacritty (cross-platform)
      "wezterm"        # Wezterm (cross-platform)
      "konsole"        # Konsole (Linux)
      "xterm"          # xterm (Linux)
      "guake"          # Guake (Linux)
      "gnome-terminal" # Gnome Terminal (Linux)
      "ghostty"        # Ghostty (cross-platform)
    )
  elif [ "$PLATFORM" = "macos" ]; then
    terminals=(
      "warp"           # Warp (macOS)
      "alacritty"      # Alacritty (cross-platform)
      "hyper"          # Hyper (cross-platform)
      "wezterm"        # Wezterm (cross-platform)
      "iterm2"         # iTerm2 (macOS)
      "open -a Terminal" # macOS Terminal
      "/Applications/Ghostty.app/Contents/MacOS/ghostty" # Full path for Ghostty
    )
  fi

  # If a preferred terminal is set, check it first
  if [ -n "$preferred_terminal" ]; then
    for term in "$preferred_terminal" "${terminals[@]}"; do
      if [ -x "$term" ] || command -v "$term" >/dev/null 2>&1 || [[ "$term" == "open -a Terminal" && "$PLATFORM" == "macos" ]]; then
        echo "$term"
        return 0
      fi
    done
  else
    # No preference set, check in defined order
    for term in "${terminals[@]}"; do
      if [ -x "$term" ] || command -v "$term" >/dev/null 2>&1 || [[ "$term" == "open -a Terminal" && "$PLATFORM" == "macos" ]]; then
        echo "$term"
        return 0
      fi
    done
  fi
  echo "No supported terminal found. Available terminals: $(echo "${terminals[@]}" | tr ' ' ', ')"
  return 1
}

# Set terminal command
TERMINAL=$(find_terminal)
if [ "$TERMINAL" = "No supported terminal found" ]; then
  echo "$TERMINAL. Please install one of: $(echo "${terminals[@]}" | tr ' ' ', ')"
  exit 1
fi

# Adjust command based on terminal
case "$TERMINAL" in
  "kitty")
    TERM_CMD="kitty -e nvim"
    ;;
  "alacritty")
    TERM_CMD="alacritty -e nvim"
    ;;
  "wezterm")
    TERM_CMD="wezterm start -- nvim"
    ;;
  "konsole")
    TERM_CMD="konsole -e nvim"
    ;;
  "xterm")
    TERM_CMD="xterm -e nvim"
    ;;
  "guake")
    TERM_CMD="guake -e 'nvim $FILE +$LINE:$COL'" # Guake requires special handling
    ;;
  "gnome-terminal")
    TERM_CMD="gnome-terminal -- nvim"
    ;;
  "warp")
    TERM_CMD="warp -- nvim" # Assuming Warp supports command-line args; adjust if needed
    ;;
  "hyper")
    TERM_CMD="hyper -e nvim" # Adjust if Hyper requires different syntax
    ;;
  "iterm2")
    TERM_CMD="open -a iTerm2 -- nvim"
    ;;
  "open -a Terminal")
    TERM_CMD="open -a Terminal -- nvim"
    ;;
  "/Applications/Ghostty.app/Contents/MacOS/ghostty")
    TERM_CMD="/Applications/Ghostty.app/Contents/MacOS/ghostty -- nvim"
    ;;
esac

case "$ACTION" in
  "open")
    $TERM_CMD "$FILE" +"$LINE:$COL"
    ;;
  "reload")
    # Check for running Godot instance
    if pgrep -f "godot.*--editor" > /dev/null; then
      echo "Detected a running Godot editor instance, but this script cannot reload it directly."
      echo "A Godot plugin is required to reload scripts in the existing instance. Launching a new instance as fallback..."
    else
      echo "No running Godot editor instance detected. Starting new instance to reload $FILE..."
    fi
    DIR="$(dirname "$0")"
    # Avoid launching a new instance during test; use a dry run flag if needed
    if [ "$DRY_RUN" != "true" ]; then
      /Applications/Godot.app/Contents/MacOS/godot --script "$DIR/reload.gd" -- "$FILE"
    fi
    ;;
  *)
    echo "Unknown action: $ACTION"
    exit 1
    ;;
esac
EOF

# Content for reload.gd
cat << 'EOF' > "$RELOAD_GD"
extends MainLoop

var has_run = false

func _initialize():
    pass  # Initialization can be empty

func _iteration(_delta):
    if not has_run:
        var cmd_args = OS.get_cmdline_args()
        if cmd_args.size() > 1:  # Skip the first arg (script path) and take the file path
            var file_path = cmd_args[1]
            var script = load(file_path)
            if script:
                print("Reloaded: ", file_path)
            else:
                print("Failed to reload: ", file_path)
        else:
            print("No file path provided as argument.")
        has_run = true
    return false  # Exit the loop after the first iteration

func _finalize():
    pass  # Cleanup, if any
EOF

# Set executable permissions
chmod +x "$OPEN_NVM_SCRIPT"
if [ $? -ne 0 ]; then
  echo "Failed to set executable permission for $OPEN_NVM_SCRIPT."
  exit 1
fi

# Test the script with a dummy action, using DRY_RUN to avoid Godot launch
echo "Testing $OPEN_NVM_SCRIPT with dry run..."
DRY_RUN=true "$OPEN_NVM_SCRIPT" /tmp/dummy.gd 1 1 reload
if [ $? -ne 0 ]; then
  echo "Test run of $OPEN_NVM_SCRIPT failed. Check output above for details (e.g., terminal or path issues)."
  exit 1
fi

# Verify installation
if [ -f "$OPEN_NVM_SCRIPT" ] && [ -f "$RELOAD_GD" ]; then
  echo "Installation successful! Files are located at:"
  echo "  - $OPEN_NVM_SCRIPT"
  echo "  - $RELOAD_GD"
  echo "Note: Ensure one of the following terminals is installed:"
  echo "  - Linux: Kitty, Alacritty, Wezterm, Konsole, Xterm, Guake, Gnome Terminal, or Ghostty"
  echo "    - Install with 'sudo apt install kitty alacritty wezterm konsole xterm guake gnome-terminal ghostty' (Debian/Ubuntu), etc."
  echo "  - macOS: Warp, Alacritty, Hyper, Wezterm, iTerm2, Terminal, or Ghostty"
  echo "    - iTerm2 and Terminal are preinstalled; install Warp, Alacritty, Hyper, Wezterm, or Ghostty if preferred."
  echo "To set your preferred terminal (e.g., Ghostty), add 'export PREFERRED_TERMINAL=\"/Applications/Ghostty.app/Contents/MacOS/ghostty\"' to your ~/.bashrc or ~/.zshrc and run 'source ~/.bashrc'."
  echo "Please ensure Godot is in your PATH or use the full path (/Applications/Godot.app/Contents/MacOS/godot) and test the setup."
  echo "Note: This script launches a new instance to reload. For in-instance reloading, a Godot plugin is required."
else
  echo "Installation failed. Please check the script and try again."
  exit 1
fi
