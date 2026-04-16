#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

ask_confirmation() {
    echo -e "${YELLOW}$1 [y/N]${NC}"
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

check_mac() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "This script is designed for macOS. Exiting."
        exit 1
    fi
}

# Check if running on macOS
check_mac

print_header "RIoT AI Cleanup Script"

echo -e "${RED}WARNING: This script will remove RIoT AI components from your system.${NC}"
echo ""
echo "You will be asked to confirm each step."
echo ""

if ! ask_confirmation "Do you want to proceed with cleanup?"; then
    print_warning "Cleanup cancelled"
    exit 0
fi

# =============================================================================
# STEP 1: Stop and Remove Onyx
# =============================================================================
print_header "STEP 1: Onyx Cleanup"

if [ -d ~/riotsecure/onyx_data ]; then
    echo "Found Onyx installation at ~/riotsecure/onyx_data"

    if ask_confirmation "Stop and remove Onyx containers and data?"; then
        cd ~/riotsecure/onyx_data 2>/dev/null

        if [ -f "docker-compose.yaml" ] || [ -f "docker-compose.yml" ]; then
            print_warning "Stopping Onyx containers..."
            docker compose down -v 2>/dev/null || docker-compose down -v 2>/dev/null
            print_success "Onyx containers stopped"
        fi

        cd ~/riotsecure
        print_warning "Removing onyx_data directory..."
        rm -rf ~/riotsecure/onyx_data
        print_success "Onyx data removed"
    else
        print_warning "Skipping Onyx removal"
    fi
else
    print_warning "Onyx data directory not found, skipping"
fi

# =============================================================================
# STEP 2: Remove Ollama Models
# =============================================================================
print_header "STEP 2: Ollama Models Cleanup"

if command -v ollama &> /dev/null; then
    RIOT_MODELS=$(ollama list 2>/dev/null | grep "^riot" | awk '{print $1}')

    if [ -n "$RIOT_MODELS" ]; then
        echo "Found RIoT models:"
        echo "$RIOT_MODELS"
        echo ""

        if ask_confirmation "Remove all RIoT models?"; then
            while IFS= read -r model; do
                if [ -n "$model" ]; then
                    print_warning "Removing model: $model"
                    ollama rm "$model" 2>/dev/null
                    print_success "Removed $model"
                fi
            done <<< "$RIOT_MODELS"
        else
            print_warning "Skipping Ollama models removal"
        fi
    else
        print_warning "No RIoT models found, skipping"
    fi

    # Optionally remove Ollama itself
    echo ""
    if ask_confirmation "Remove Ollama completely? (This will remove ALL models)"; then
        print_warning "Stopping Ollama service..."
        pkill -9 ollama 2>/dev/null

        print_warning "Removing Ollama data..."
        rm -rf ~/.ollama

        print_warning "Uninstalling Ollama..."
        if [ -f /usr/local/bin/ollama ]; then
            sudo rm /usr/local/bin/ollama
        fi
        if [ -f /opt/homebrew/bin/ollama ]; then
            brew uninstall ollama 2>/dev/null || sudo rm /opt/homebrew/bin/ollama
        fi

        print_success "Ollama removed"
    else
        print_warning "Keeping Ollama installed"
    fi
else
    print_warning "Ollama not found, skipping"
fi

# =============================================================================
# STEP 3: Docker Desktop
# =============================================================================
print_header "STEP 3: Docker Desktop Cleanup"

if [ -d "/Applications/Docker.app" ]; then
    echo "Docker Desktop is installed"
    echo ""
    echo -e "${YELLOW}Note: Docker Desktop may be used by other applications.${NC}"

    if ask_confirmation "Uninstall Docker Desktop?"; then
        print_warning "Quitting Docker Desktop..."
        osascript -e 'quit app "Docker"' 2>/dev/null
        sleep 3

        print_warning "Uninstalling Docker Desktop..."
        if command -v brew &> /dev/null; then
            brew uninstall --cask docker-desktop 2>/dev/null
        fi

        # Remove Docker data
        if ask_confirmation "Remove Docker data and containers? (WARNING: This affects all Docker usage)"; then
            rm -rf ~/Library/Containers/com.docker.docker
            rm -rf ~/Library/Application\ Support/Docker\ Desktop
            rm -rf ~/Library/Group\ Containers/group.com.docker
            rm -rf ~/.docker
            print_success "Docker data removed"
        fi

        print_success "Docker Desktop uninstalled"
    else
        print_warning "Keeping Docker Desktop"
    fi
else
    print_warning "Docker Desktop not found, skipping"
fi

# =============================================================================
# STEP 4: Repository
# =============================================================================
print_header "STEP 4: Repository Cleanup"

if [ -d ~/riotsecure ]; then
    echo "Found riotsecure repository at ~/riotsecure"

    # Check if there are uncommitted changes
    cd ~/riotsecure
    if [ -d .git ]; then
        if ! git diff-index --quiet HEAD -- 2>/dev/null; then
            print_warning "Repository has uncommitted changes!"
            git status --short
            echo ""
        fi
    fi

    if ask_confirmation "Remove the riotsecure repository?"; then
        cd ~
        print_warning "Removing repository..."
        rm -rf ~/riotsecure
        print_success "Repository removed"
    else
        print_warning "Keeping repository"
    fi
else
    print_warning "Repository not found, skipping"
fi

# =============================================================================
# STEP 5: Content Directory
# =============================================================================
print_header "STEP 5: Downloaded Content Cleanup"

if [ -d ~/riotsecure/content ]; then
    if ask_confirmation "Remove downloaded RAG content?"; then
        rm -rf ~/riotsecure/content
        print_success "Content removed"
    else
        print_warning "Keeping content"
    fi
fi

# =============================================================================
# STEP 6: Power Settings
# =============================================================================
print_header "STEP 6: Power Settings Cleanup"

if ask_confirmation "Restore default sleep settings?"; then
    print_warning "Restoring sleep settings..."
    sudo pmset -a sleep 10 disksleep 10
    print_success "Sleep settings restored to defaults (10 minutes)"
else
    print_warning "Keeping current power settings"
fi

# =============================================================================
# STEP 7: Homebrew (Optional)
# =============================================================================
print_header "STEP 7: Homebrew Cleanup (Optional)"

if command -v brew &> /dev/null; then
    echo -e "${YELLOW}Note: Homebrew may be used by many other applications.${NC}"
    echo -e "${YELLOW}Only remove if you're sure you don't need it.${NC}"
    echo ""

    if ask_confirmation "Uninstall Homebrew? (NOT RECOMMENDED)"; then
        print_warning "Uninstalling Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"

        # Remove Homebrew from shell profile
        if [ -f ~/.zprofile ]; then
            sed -i.bak '/homebrew/d' ~/.zprofile
            print_success "Removed Homebrew from .zprofile"
        fi

        print_success "Homebrew uninstalled"
    else
        print_warning "Keeping Homebrew"
    fi
fi

# =============================================================================
# Summary
# =============================================================================
print_header "Cleanup Complete"

echo -e "${GREEN}Cleanup process finished!${NC}"
echo ""
echo "What was done:"
echo "  • Reviewed and optionally removed Onyx"
echo "  • Reviewed and optionally removed Ollama models"
echo "  • Reviewed and optionally removed Docker Desktop"
echo "  • Reviewed and optionally removed repository"
echo "  • Reviewed and optionally restored power settings"
echo ""
echo "To reinstall RIoT AI, run:"
echo -e "  ${BLUE}bash <(curl -fsSL https://raw.githubusercontent.com/cediackermann/riotsecure/main/setup.sh)${NC}"
echo ""
