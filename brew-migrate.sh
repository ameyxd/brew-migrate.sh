#!/bin/bash

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Temporary files
TEMP_DIR="/tmp"
MANUAL_APPS="$TEMP_DIR/manual_apps.txt"
BREW_ALL="$TEMP_DIR/brew_all.txt"
BREW_INSTALLED="$TEMP_DIR/brew_installed.txt"
OUTPUT_FILE="$HOME/brew_migratable_apps.txt"

# Function to display usage information
show_usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -r    Force refresh of app and brew lists"
    echo "  -i    Install migratable apps with brew after identification"
    echo "  -h    Show this help message"
    exit 1
}

# Parse command line options
REFRESH=false
INSTALL=false

while getopts "rih" opt; do
    case "$opt" in
        r) REFRESH=true ;;
        i) INSTALL=true ;;
        h) show_usage ;;
        *) show_usage ;;
    esac
done

# Function to check if lists need refreshing
need_refresh() {
    if [ "$REFRESH" = true ]; then
        return 0
    fi
    
    # Check if any of the files are missing
    for file in "$MANUAL_APPS" "$BREW_ALL" "$BREW_INSTALLED"; do
        if [ ! -f "$file" ]; then
            return 0
        fi
    done
    
    # Check if files are older than today
    # Use stat command compatible with both macOS and Linux
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS version
        LAST_MODIFIED=$(stat -f "%Sm" -t "%Y-%m-%d" "$BREW_ALL" 2>/dev/null)
    else
        # Linux version
        LAST_MODIFIED=$(stat -c "%y" "$BREW_ALL" 2>/dev/null | cut -d " " -f 1)
    fi
    TODAY=$(date +"%Y-%m-%d")
    
    if [ "$LAST_MODIFIED" != "$TODAY" ]; then
        return 0
    fi
    
    return 1
}

# Function to gather app and brew information
gather_info() {
    echo -e "${BLUE}Gathering information about installed applications and available brew packages...${NC}"
    
    # Find all applications in /Applications and ~/Applications
    echo "Finding manually installed applications..."
    find /Applications ~/Applications -maxdepth 1 -type d -name "*.app" > "$MANUAL_APPS"
    
    # Get list of all available brew formulae and casks
    echo "Getting list of all available Homebrew packages..."
    brew search /./ > "$BREW_ALL"
    
    # Get list of already installed brew packages
    echo "Getting list of already installed Homebrew packages..."
    brew list > "$BREW_INSTALLED"
    
    echo -e "${GREEN}Information gathering complete.${NC}"
}

# Function to find migratable apps
find_migratable_apps() {
    echo -e "${BLUE}Finding applications that can be migrated to Homebrew...${NC}"
    
    # Empty the output file
    > "$OUTPUT_FILE"
    
    # Process each application
    local count=0
    
    while IFS= read -r app_path; do
        app_name=$(basename "$app_path" .app)
        
        # Sanitize the app name for Homebrew search
        search_term=$(echo "$app_name" | sed -e 's/ /-/g' -e 's/\./-/g' -e 's/@.*//' | tr '[:upper:]' '[:lower:]')
        
        # Look for matches in brew
        if grep -i "$search_term" "$BREW_ALL" | grep -v -f "$BREW_INSTALLED" > /dev/null; then
            # Get potential brew packages
            potential_packages=$(grep -i "$search_term" "$BREW_ALL" | grep -v -f "$BREW_INSTALLED")
            
            # Check if we have an exact match (more reliable)
            exact_match=""
            while IFS= read -r package; do
                package_lower=$(echo "$package" | tr '[:upper:]' '[:lower:]')
                search_term_lower=$(echo "$search_term" | tr '[:upper:]' '[:lower:]')
                
                if [ "$package_lower" = "$search_term_lower" ] || [ "$package_lower" = "${search_term_lower}.app" ]; then
                    exact_match="$package"
                    break
                fi
            done <<< "$potential_packages"
            
            # If we have an exact match, use it; otherwise, list all potential matches
            if [ -n "$exact_match" ]; then
                echo "$app_path:$exact_match" >> "$OUTPUT_FILE"
                count=$((count + 1))
            else
                # Multiple potential matches, list the first one with a note
                first_match=$(echo "$potential_packages" | head -1)
                echo "$app_path:$first_match # Multiple potential matches available" >> "$OUTPUT_FILE"
                count=$((count + 1))
            fi
        fi
    done < "$MANUAL_APPS"
    
    echo -e "${GREEN}Found $count application(s) that can be migrated to Homebrew.${NC}"
    echo -e "${BLUE}Results saved to $OUTPUT_FILE${NC}"
}

# Function to install migratable apps with brew
install_with_brew() {
    if [ ! -s "$OUTPUT_FILE" ]; then
        echo -e "${YELLOW}No migratable applications found. Nothing to install.${NC}"
        return
    fi
    
    echo -e "${BLUE}Preparing to install applications with Homebrew...${NC}"
    echo -e "${YELLOW}WARNING: This will install applications via Homebrew. Existing app data should be preserved, but it's recommended to backup important data first.${NC}"
    echo -e "${YELLOW}It's also recommended to move the original application to trash before installing with Homebrew.${NC}"
    
    read -p "Do you want to continue? (y/n): " choice
    case "$choice" in
        y|Y)
            echo "Proceeding with installation..."
            ;;
        *)
            echo "Installation aborted."
            return
            ;;
    esac
    
    # Install each application
    while IFS=: read -r app_path brew_package remainder; do
        # Extract the first package if there are comments or multiple packages
        brew_package=$(echo "$brew_package" | awk '{print $1}')
        
        app_name=$(basename "$app_path" .app)
        echo -e "${BLUE}Processing $app_name...${NC}"
        
        echo -e "${YELLOW}Please move the original application '$app_name' to trash before continuing.${NC}"
        read -p "Have you moved the original application to trash? (y/n): " moved
        if [[ "$moved" != "y" && "$moved" != "Y" ]]; then
            echo -e "${YELLOW}Skipping installation of $app_name.${NC}"
            continue
        fi
        
        # Check if it's a cask by searching brew cask info
        if brew info --cask "$brew_package" &>/dev/null; then
            echo "Installing as cask: $brew_package"
            brew install --cask "$brew_package"
        else
            echo "Installing as formula: $brew_package"
            brew install "$brew_package"
        fi
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Successfully installed $brew_package${NC}"
        else
            echo -e "${RED}Failed to install $brew_package${NC}"
        fi
    done < "$OUTPUT_FILE"
    
    echo -e "${GREEN}Installation process completed.${NC}"
}

# Main script execution
echo -e "${BLUE}Brew Migration Assistant${NC}"

# Check if we need to refresh our data
if need_refresh; then
    gather_info
else
    echo -e "${BLUE}Using existing application and brew data. Use -r to force refresh.${NC}"
fi

# Find migratable applications
find_migratable_apps

# Display results
if [ -s "$OUTPUT_FILE" ]; then
    echo -e "${BLUE}Applications that can be migrated to Homebrew:${NC}"
    cat "$OUTPUT_FILE" | while IFS=: read -r app_path brew_package remainder; do
        app_name=$(basename "$app_path" .app)
        echo -e "${GREEN}$app_name${NC} -> $brew_package"
    done
else
    echo -e "${YELLOW}No migratable applications found.${NC}"
fi

# Install with brew if requested
if [ "$INSTALL" = true ]; then
    install_with_brew
fi

echo -e "${BLUE}Script execution completed.${NC}"
