#!/bin/bash

# Determine the OS and architecture
OS=$(uname -s)
ARCH=$(uname -m)

# Function to check if a command is available
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required commands
if ! command_exists curl; then
    echo "Error: curl is not installed."
    exit 1
fi

TARGET_FILE_NAME="https://github.com/malamtime/cli/releases/latest/download/cli_"

cd /tmp

# Set the download URL based on the OS and architecture
if [[ "$OS" == "Darwin" ]]; then
    TARGET_FILE_NAME="${TARGET_FILE_NAME}${OS}"
    if [[ "$ARCH" == "x86_64" ]]; then
        URL="${TARGET_FILE_NAME}_amd64_v1.zip"
    elif [[ "$ARCH" == "arm64" ]]; then
        URL="${TARGET_FILE_NAME}_arm64.zip"
    else
        echo "Unsupported architecture: $ARCH on macOS"
        exit 1
    fi
    if ! command_exists unzip; then
        echo "Error: unzip is not installed."
        exit 1
    fi
elif [[ "$OS" == "Linux" ]]; then
    TARGET_FILE_NAME="${TARGET_FILE_NAME}${OS}"
    if [[ "$ARCH" == "x86_64" ]]; then
        URL="${TARGET_FILE_NAME}_x86_64.tar.gz"
    elif [[ "$ARCH" == "aarch64" ]]; then
        URL="${TARGET_FILE_NAME}_arm64.tar.gz"
    else
        echo "Unsupported architecture: $ARCH on Linux"
        exit 1
    fi
    if ! command_exists tar; then
        echo "Error: tar is not installed."
        exit 1
    fi
elif [[ "$OS" == "MINGW64_NT" ]] || [[ "$OS" == "MSYS_NT" ]] || [[ "$OS" == "CYGWIN_NT" ]]; then
    TARGET_FILE_NAME="${TARGET_FILE_NAME}Windows"
    if [[ "$ARCH" == "x86_64" ]]; then
        URL="${TARGET_FILE_NAME}_x86_64.zip"
    elif [[ "$ARCH" == "aarch64" ]]; then
        URL="${TARGET_FILE_NAME}_arm64.zip"
    else
        echo "Unsupported architecture: $ARCH on Windows"
        exit 1
    fi
    if ! command_exists unzip; then
        echo "Error: unzip is not installed."
        exit 1
    fi
else
    echo "Unsupported OS: $OS"
    exit 1
fi

# Download the file
FILENAME=$(basename "$URL")
curl -LO "$URL"

# Check if the download was successful
if [ ! -f "$FILENAME" ]; then
    echo "Error: Failed to download $FILENAME"
    exit 1
fi

# Extract the file
if [[ "$FILENAME" == *.zip ]]; then
    rm "$FILENAME"
    unzip "$FILENAME" > /dev/null
elif [[ "$FILENAME" == *.tar.gz ]]; then
    rm "$FILENAME"
    tar zxvf "$FILENAME" > /dev/null
else
    echo "Unsupported file type: $FILENAME"
    exit 1
fi

# Check if the shelltime file exists
if [ ! -f "shelltime" ]; then
    echo "Error: shelltime binary not found after extraction"
    exit 1
fi

# Check if $HOME/.shelltime/bin exists, create if not
if [ ! -d "$HOME/.shelltime/bin" ]; then
    echo "Creating $HOME/.shelltime/bin directory..."
    mkdir -p "$HOME/.shelltime/bin"
    if [ $? -eq 0 ]; then
        echo "Directory created successfully."
    else
        echo "Failed to create directory. Please check your permissions."
        exit 1
    fi
else
    echo "$HOME/.shelltime/bin directory already exists."
fi

# Move the binary to the appropriate location
if [[ "$OS" == "Darwin" ]] || [[ "$OS" == "Linux" ]]; then
    mv shelltime "$HOME/.shelltime/bin/"
# elif [[ "$OS" == "MINGW64_NT" ]] || [[ "$OS" == "MSYS_NT" ]] || [[ "$OS" == "CYGWIN_NT" ]]; then
    # mv shelltime /c/Windows/System32/
fi

# Add $HOME/.shelltime/bin to user path
if [[ "$OS" == "Darwin" ]] || [[ "$OS" == "Linux" ]]; then
    # For Zsh
    if ! grep -q '$HOME/.shelltime/bin' "$HOME/.zshrc"; then
        echo 'export PATH="$HOME/.shelltime/bin:$PATH"' >> "$HOME/.zshrc"
        echo "Updated .zshrc to include $HOME/.shelltime/bin in PATH"
    fi

    # For Fish
    if ! grep -q '$HOME/.shelltime/bin' "$HOME/.config/fish/config.fish"; then
        echo 'set -gx PATH $HOME/.shelltime/bin $PATH' >> "$HOME/.config/fish/config.fish"
        echo "Updated config.fish to include $HOME/.shelltime/bin in PATH"
    fi

    echo "Please restart your shell or run 'source ~/.zshrc' (for Zsh) or 'source ~/.config/fish/config.fish' (for Fish) to apply the changes."
fi

# Clean up
rm -f "$FILENAME"
# rm -rf shelltime


# HELP WANTED
# I don't know where the `/bin` folder in windows. so i don't know where should the binaries be installed.
# if you know, please let me know.

# Success message
echo "Installation successful! You can try the command by running 'shelltime -h'."

if [[ "$OS" == "MINGW64_NT" ]] || [[ "$OS" == "MSYS_NT" ]] || [[ "$OS" == "CYGWIN_NT" ]]; then
	echo "Please note that the binaries are not installed yet. please move `/tmp/shelltime` to your `/bin/` folder manually."
	echo "btw if you know where should the binaries be installed, please raise an issue or pull request. (https://github.com/shelltime/cli)."
fi


# STEP 2
# insert a preexec and postexec script to user configuration, including `zsh` and `fish`

# Define the path
hooks_path="$HOME/.shelltime/hooks"

# Check if the directory exists
if [ ! -d "$hooks_path" ]; then
    echo "The directory $hooks_path does not exist."
    echo "Creating the directory..."

    # Create the directory and its parent directories if they don't exist
    mkdir -p "$hooks_path"

    # Check if the creation was successful
    if [ $? -eq 0 ]; then
        echo "Directory created successfully."
    else
        echo "Failed to create the directory. Please check your permissions."
        exit 1
    fi
fi


# Function to check and delete .bak files
check_and_delete_bak() {
    local file="$1"
    if [ -f "${hooks_path}/${file}.bak" ]; then
        echo "Deleting ${file}.bak..."
        rm "${hooks_path}/${file}.bak"
    fi
}

# Function to check, rename, and download files
process_file() {
    local file="$1"
    local url="$2"

    # Check if the file exists and rename it
    if [ -f "${hooks_path}/${file}" ]; then
        echo "Renaming existing ${file} to ${file}.bak..."
        mv "${hooks_path}/${file}" "${hooks_path}/${file}.bak"
    fi

    # Download the new file
    echo "Downloading new ${file}..."
    curl -sSL "${url}" -o "${hooks_path}/${file}"
}


# Function to add source line to config file if not already present
add_source_to_config() {
    local config_file="$1"
    local source_file="$2"
    local source_line="source ${source_file}"

    if ! grep -qF "${source_line}" "${config_file}"; then
        echo "Adding source line to ${config_file}..."
        echo "${source_line}" >> "${config_file}"
    else
        echo "Source line already exists in ${config_file}."
    fi
}

# Ensure hooks_path exists
mkdir -p "$hooks_path"

# Check and delete .bak files
check_and_delete_bak "zsh.zsh"
check_and_delete_bak "fish.fish"

# Process zsh.zsh
process_file "zsh.zsh" "https://raw.githubusercontent.com/malamtime/installation/master/hooks/zsh.zsh"

# Process fish.fish
process_file "fish.fish" "https://raw.githubusercontent.com/malamtime/installation/master/hooks/fish.fish"

# Add source lines to config files
add_source_to_config "$HOME/.zshrc" "${hooks_path}/zsh.zsh"
add_source_to_config "$HOME/.config/fish/config.fish" "${hooks_path}/fish.fish"

echo "\n"
echo "======================================================="
echo "\n"

# Final message
echo "To complete the setup, please follow these steps:"
echo "1. Visit https://shelltime.xyz to obtain an open token."
echo "2. Run the following command in your terminal:"
echo "   shelltime init --token=TOKEN"
echo "   (Replace TOKEN with the actual token you received)"
echo "3. Source your shell configuration file:"
echo "   For Zsh users: source ~/.zshrc"
echo "   For Fish users: source ~/.config/fish/config.fish"
echo "Only after completing these steps will shelltime be fully functional."
