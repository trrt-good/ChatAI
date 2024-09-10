#!/bin/bash

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Directory variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERMINAL_INTEGRATION_DIR="$SCRIPT_DIR/terminal_integration"
VENV_DIR="$SCRIPT_DIR/env"

# Function definitions
command_exists() { command -v "$1" >/dev/null 2>&1; }
error_exit() { echo -e "${RED}Error: $1${NC}" >&2; exit 1; }
print_header() { echo -e "\n${BLUE}=== $1 ===${NC}\n"; }
print_options() { 
    local arr=("$@")
    for i in "${!arr[@]}"; do 
        echo -e "${CYAN}$((i+1))) ${arr[$i]}${NC}"
    done
}

# Detect OS
OS=$(case "$OSTYPE" in
  linux*) echo "linux" ;;
  darwin*) echo "macos" ;;
  *) error_exit "Unsupported operating system: $OSTYPE" ;;
esac)

# Check Python and create virtual environment
command_exists python3 || error_exit "Python 3 is not installed. Please install Python 3 and try again."
[ ! -d "$VENV_DIR" ] && echo "Creating virtual environment..." && python3 -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate" || error_exit "Failed to activate virtual environment"

# Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"
pip install groq openai anthropic || error_exit "Failed to install packages"

# Get supported terminals and text editors
SUPPORTED_TERMINALS=($(ls "$TERMINAL_INTEGRATION_DIR"))
SUPPORTED_EDITORS=()

# Ask user for terminal
print_header "Select a Terminal"
print_options "${SUPPORTED_TERMINALS[@]}"
while true; do
    read -p "Enter the number of your terminal: " terminal_choice
    if ((terminal_choice >= 1 && terminal_choice <= ${#SUPPORTED_TERMINALS[@]})); then
        terminal=${SUPPORTED_TERMINALS[$((terminal_choice - 1))]}
        break
    else
        echo -e "${YELLOW}Invalid choice. Please try again.${NC}"
    fi
done

# Get supported editors for the selected terminal
SUPPORTED_EDITORS=($(ls "$TERMINAL_INTEGRATION_DIR/$terminal"))

# Ask user for text editor
print_header "Select a Text Editor for $terminal"
print_options "${SUPPORTED_EDITORS[@]}"
while true; do
    read -p "Enter the number of your text editor: " editor_choice
    if ((editor_choice >= 1 && editor_choice <= ${#SUPPORTED_EDITORS[@]})); then
        editor=${SUPPORTED_EDITORS[$((editor_choice - 1))]}
        break
    else
        echo -e "${YELLOW}Invalid choice. Please try again.${NC}"
    fi
done

# Function to ask user if they want to install a package
ask_to_install() {
    read -p "Do you want to install $1? (y/n) " install_choice
    [[ $install_choice == [yY] ]]
}

# Install terminal and text editor if not already installed
for tool in "$terminal" "$editor"; do
    if [[ $OS == "macos" && $tool == "macos_terminal" ]]; then
        # Skip terminal check for macOS
        continue
    fi

    if ! command_exists "$tool"; then    
        if ask_to_install "$tool"; then
            echo -e "${YELLOW}Installing $tool...${NC}"
            case $OS in
                linux)
                    if command_exists apt-get; then sudo apt-get update && sudo apt-get install -y "$tool"
                    elif command_exists yum; then sudo yum install -y "$tool"
                    elif command_exists dnf; then sudo dnf install -y "$tool"
                    elif command_exists pacman; then sudo pacman -S --noconfirm "$tool"
                    else error_exit "Unsupported package manager. Please install $tool manually."
                    fi ;;
                macos)
                    command_exists brew && brew install "$tool" || 
                    error_exit "Homebrew is not installed. Please install Homebrew and try again." ;;
            esac
        else
            echo "Please install $tool manually and run this script again."; exit 1
        fi
    fi
done

# Terminal and editor specific parts
INTEGRATION_DIR="$TERMINAL_INTEGRATION_DIR/$terminal/$editor"

if [ "$terminal" = "kitty" ] && [ "$editor" = "micro" ]; then
    while true; do
        read -p "Enter directory to place the launch script: " launch_dir
        [ -d "$launch_dir" ] && break || echo -e "${YELLOW}Directory does not exist. Please enter a valid directory.${NC}"
    done

    # Create the new chatai.sh file
    cat > "$launch_dir/chatai.sh" <<EOL
#!/bin/bash
kitty --hold sh -c "micro $SCRIPT_DIR/history/newchat_\$(date +%Y-%m-%d_%H-%M-%S).md"
EOL

    chmod +x "$launch_dir/chatai.sh" || error_exit "Failed to make launch script executable"

    MICRO_CONFIG_DIR="$HOME/.config/micro"
    INIT_LUA="$MICRO_CONFIG_DIR/init.lua"
    if [ -f "$INIT_LUA" ]; then
        read -p "$INIT_LUA already exists. Replace it? (y/n) " replace
        [ "$replace" != "y" ] && { echo "Exiting without modifying init.lua"; exit 0; }
    fi

    mkdir -p "$MICRO_CONFIG_DIR"
    sed -e "s|<ENVIRONMENT_ACTIVATION>|$VENV_DIR/bin/activate|g" \
        -e "s|<RUN_SCRIPT>|$SCRIPT_DIR/run.py|g" \
        "$INTEGRATION_DIR/init.lua" > "$INIT_LUA" || error_exit "Failed to create init.lua"

    echo -e "${GREEN}Installation complete for Kitty terminal and Micro editor.${NC}"
elif [ "$terminal" = "macos_terminal" ] && [ "$editor" = "micro" ]; then
    while true; do
        read -p "Enter directory to place the launch script: " launch_dir
        [ -d "$launch_dir" ] && break || echo -e "${YELLOW}Directory does not exist. Please enter a valid directory.${NC}"
    done

    mkdir -p "$SCRIPT_DIR/history" || error_exit "Failed to create history directory"

    # Create the new chatai.sh file for macOS Terminal
    cat > "$launch_dir/chatai.sh" <<EOL
#!/bin/bash
open -a Terminal --new-window --command "micro $SCRIPT_DIR/history/newchat_\$(date +%Y-%m-%d_%H-%M-%S).md"
EOL

    chmod +x "$launch_dir/chatai.sh" || error_exit "Failed to make launch script executable"

    MICRO_CONFIG_DIR="$HOME/.config/micro"
    INIT_LUA="$MICRO_CONFIG_DIR/init.lua"
    if [ -f "$INIT_LUA" ]; then
        read -p "$INIT_LUA already exists. Replace it? (y/n) " replace
        [ "$replace" != "y" ] && { echo "Exiting without modifying init.lua"; exit 0; }
    fi

    mkdir -p "$MICRO_CONFIG_DIR"
    sed -e "s|<ENVIRONMENT_ACTIVATION>|$VENV_DIR/bin/activate|g" \
        -e "s|<RUN_SCRIPT>|$SCRIPT_DIR/run.py|g" \
        "$INTEGRATION_DIR/init.lua" > "$INIT_LUA" || error_exit "Failed to create init.lua"

    echo -e "${GREEN}Installation complete for macOS Terminal and Micro editor.${NC}"
else
    error_exit "No specific actions defined for $terminal and $editor combination."
fi

# Deactivate virtual environment
deactivate

mkdir -p "$SCRIPT_DIR/history" || error_exit "Failed to create history directory"
mkdir -p "$SCRIPT_DIR/logs" || error_exit "Failed to create logs directory"
touch "$SCRIPT_DIR/logs/chatai.log" || error_exit "Failed to create log file"

echo -e "${GREEN}Installation completed successfully.${NC}"

# Final instructions
print_header "Final Steps"
echo -e "${YELLOW}1. Add your API keys to config.json${NC}"
echo -e "${YELLOW}2. Set up a hotkey with your desktop environment/OS to run the script:${NC}"
echo -e "${CYAN}   $(readlink -f "$launch_dir/chatai.sh")${NC}"
echo -e "${YELLOW}3. (Optional) If you would like to use environment variables rather than the config for API keys, you can manually modify the launch script to set them${NC}"
echo -e "\n${GREEN}Enjoy using your new AI chat integration!${NC}"