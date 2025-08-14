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
      "alacritty"      # Alacritty (cross-platform)
      "ghostty"        # Ghostty (cross-platform)
      "gnome-terminal" # Gnome Terminal (Linux)
      "guake"          # Guake (Linux)
      "kitty"          # Kitty (cross-platform)
      "konsole"        # Konsole (Linux)
      "wezterm"        # Wezterm (cross-platform)
      "xterm"          # xterm (Linux)
    )
  elif [ "$PLATFORM" = "macos" ]; then
    terminals=(
      "alacritty"      # Alacritty (cross-platform)
      "ghostty"        # Ghostty (cross-platform)
      "hyper"          # Hyper (cross-platform)
      "iterm2"         # iTerm2 (macOS)
      "kitty"          # Kitty (cross-platform)
      "open -a Terminal" # macOS Terminal
      "warp"           # Warp (macOS)
      "wezterm"        # Wezterm (cross-platform)
    )
  fi

  # If a preferred terminal is set, check it first
  if [ -n "$preferred_terminal" ]; then
    for term in "$preferred_terminal" "${terminals[@]}"; do
      if command -v "$term" >/dev/null 2>&1 || [[ "$term" == "open -a Terminal" && "$PLATFORM" == "macos" ]]; then
        echo "$term"
        return 0
      fi
    done
  else
    # No preference set, check in defined order
    for term in "${terminals[@]}"; do
      if command -v "$term" >/dev/null 2>&1 || [[ "$term" == "open -a Terminal" && "$PLATFORM" == "macos" ]]; then
        echo "$term"
        return 0
      fi
    done
  fi
  echo "No supported terminal found"
  return 1
}

# Set terminal command
TERMINAL=$(find_terminal)
if [[ "$TERMINAL" == "No supported terminal found" ]]; then
  echo "Error: No supported terminal emulator detected. Please install one (e.g., Kitty, Alacritty, Wezterm, Konsole, Xterm, Guake, Gnome Terminal on Linux; Warp, Alacritty, Hyper, Wezterm, iTerm2, Terminal on macOS) or set PREFERRED_TERMINAL."
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
  "ghostty")
    TERM_CMD="ghostty -- nvim"
    ;;
esac

case "$ACTION" in
  "open")
    $TERM_CMD "$FILE" +"$LINE:$COL"
    ;;
  "reload")
    DIR="$(dirname "$0")"
    godot --script "$DIR/reload.gd" -- "$FILE"
    ;;
  *)
    echo "Unknown action: $ACTION"
    exit 1
    ;;
esac
EOF

# Content for reload.gd
cat << 'EOF' > "$RELOAD_GD"
tool
extends EditorScript

func _run():
    var file_path = ARGV[0]
    var script = load(file_path)
    if script:
        print("Reloaded: ", file_path)
    else:
        print("Failed to reload: ", file_path)
EOF

# Set executable permissions
chmod +x "$OPEN_NVM_SCRIPT"
if [ $? -ne 0 ]; then
  echo "Failed to set executable permission for $OPEN_NVM_SCRIPT."
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
  echo "To set your preferred terminal (e.g., Guake), add 'export PREFERRED_TERMINAL=\"guake\"' to your ~/.bashrc or ~/.zshrc and run 'source ~/.bashrc'."
  echo "Please ensure Godot is in your PATH and test the setup."
else
  echo "Installation failed. Please check the script and try again."
  exit 1
fi
