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
      "ghostty"        # Ghostty (cross-platform)
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
    # Check for running Godot instance and attempt remote reload
    if pgrep -f "godot.*--editor" > /dev/null; then
      # Attempt to send a remote command (e.g., via debug port if configured)
      # Note: This requires Godot to be started with --remote-debug
      # For now, this is a placeholder; Godot doesn't support direct reload via CLI
      echo "Attempting to reload $FILE in existing Godot instance..."
      # Fallback to script execution if remote reload isn't supported
      DIR="$(dirname "$0")"
      godot --script "$DIR/reload.gd" -- "$FILE"
    else
      echo "No running Godot editor instance detected. Starting new instance to reload $FILE..."
      DIR="$(dirname "$0")"
      godot --script "$DIR/reload.gd" -- "$FILE"
    fi
    ;;
  *)
    echo "Unknown action: $ACTION"
    exit 1
    ;;
esac
