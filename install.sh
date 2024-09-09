#!/bin/bash

# At the beginning of the script
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
else
    IS_MACOS=false
fi

# Then, where you use sed, you can do:
if [ "$IS_MACOS" = true ]; then
    sed -e "s|<ENVIRONMENT_ACTIVATION>|$VENV_DIR/bin/activate|g" \
        -e "s|<RUN_SCRIPT>|$SCRIPT_DIR/run.py|g" \
        "$INTEGRATION_DIR/init.lua" > "$INIT_LUA.tmp" && mv "$INIT_LUA.tmp" "$INIT_LUA" || error_exit "Failed to create init.lua"
else
    sed -e "s|<ENVIRONMENT_ACTIVATION>|$VENV_DIR/bin/activate|g" \
        -e "s|<RUN_SCRIPT>|$SCRIPT_DIR/run.py|g" \
        "$INTEGRATION_DIR/init.lua" > "$INIT_LUA" || error_exit "Failed to create init.lua"
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print error and exit
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

# Check if Python exists
if ! command_exists python3; then
    error_exit "Python 3 is not installed. Please install Python 3 and try again."
fi

# Create and activate virtual environment
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR" || error_exit "Failed to create virtual environment"
fi

source "$VENV_DIR/bin/activate" || error_exit "Failed to activate virtual environment"

# Install required packages
echo "Installing required packages..."
pip install groq openai anthropic || error_exit "Failed to install packages"

# Function to get supported options
get_supported_options() {
    local dir="$1"
    if [ -d "$dir" ]; then
        ls "$dir"
    else
        echo "No options available"
    fi
}

# Ask user for terminal
while true; do
    read -p "What terminal are you using? " terminal
    if [ -d "$TERMINAL_INTEGRATION_DIR/$terminal" ]; then
        break
    else
        echo "Unsupported terminal. Supported terminals are:"
        get_supported_options "$TERMINAL_INTEGRATION_DIR"
    fi
done

# Ask user for text editor
while true; do
    read -p "What text editor are you using? " editor
    if [ -d "$TERMINAL_INTEGRATION_DIR/$terminal/$editor" ]; then
        break
    else
        echo "Unsupported text editor for $terminal. Supported editors are:"
        get_supported_options "$TERMINAL_INTEGRATION_DIR/$terminal"
    fi
done

# Terminal and editor specific parts
INTEGRATION_DIR="$TERMINAL_INTEGRATION_DIR/$terminal/$editor"

if [ "$terminal" = "kitty" ] && [ "$editor" = "micro" ]; then
    # Ask user for directory to put the launch script
    while true; do
        read -p "Enter directory to place the launch script: " launch_dir
        if [ -d "$launch_dir" ]; then
            break
        else
            echo "Directory does not exist. Please enter a valid directory."
        fi
    done

    # Create executable link
    ln -sf "$INTEGRATION_DIR/chatai.sh" "$launch_dir/chatai" || error_exit "Failed to create launch script link"
    chmod +x "$launch_dir/chatai" || error_exit "Failed to make launch script executable"

    # Check if init.lua exists
    MICRO_CONFIG_DIR="$HOME/.config/micro"
    INIT_LUA="$MICRO_CONFIG_DIR/init.lua"
    if [ -f "$INIT_LUA" ]; then
        read -p "$INIT_LUA already exists. Replace it? (y/n) " replace
        if [ "$replace" != "y" ]; then
            echo "Exiting without modifying init.lua"
            exit 0
        fi
    fi

    # Replace placeholders in init.lua
    mkdir -p "$MICRO_CONFIG_DIR"
    sed -e "s|<ENVIRONMENT_ACTIVATION>|$VENV_DIR/bin/activate|g" \
        -e "s|<RUN_SCRIPT>|$SCRIPT_DIR/run.py|g" \
        "$INTEGRATION_DIR/init.lua" > "$INIT_LUA" || error_exit "Failed to create init.lua"

    echo "Installation complete for Kitty terminal and Micro editor."
else
    error_exit "No specific actions defined for $terminal and $editor combination."
fi

# Deactivate virtual environment
deactivate

echo "Installation completed successfully."