#!/bin/bash

set -e

# Source shared helpers if running from the repo; otherwise define inline.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/steps/common.sh" ]; then
    source "$SCRIPT_DIR/steps/common.sh"
else
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
    print_header()      { echo -e "\n${BLUE}===================================================${NC}\n${BLUE}$1${NC}\n${BLUE}===================================================${NC}\n"; }
    print_success()     { echo -e "${GREEN}✓ $1${NC}"; }
    print_warning()     { echo -e "${YELLOW}⚠ $1${NC}"; }
    print_error()       { echo -e "${RED}✗ $1${NC}"; }
    ask_confirmation()  { echo -e "${YELLOW}$1 [y/N]${NC}"; read -r response; [[ "$response" =~ ^[Yy]$ ]]; }
    check_mac()         { [[ "$OSTYPE" != "darwin"* ]] && { echo -e "${RED}✗ macOS only${NC}"; exit 1; }; }
fi

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

    echo ""
    if ask_confirmation "Remove Ollama completely? (This will remove ALL models)"; then
        print_warning "Stopping Ollama service..."
        pkill -9 ollama 2>/dev/null || true

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
        osascript -e 'quit app "Docker"' 2>/dev/null || true
        sleep 3

        print_warning "Uninstalling Docker Desktop..."
        if command -v brew &> /dev/null; then
            brew uninstall --cask docker-desktop 2>/dev/null || true
        fi

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

    cd ~/riotsecure
    if [ -d .git ] && ! git diff-index --quiet HEAD -- 2>/dev/null; then
        print_warning "Repository has uncommitted changes!"
        git status --short
        echo ""
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
# STEP 5: Power Settings
# =============================================================================
print_header "STEP 5: Power Settings Cleanup"

if ask_confirmation "Restore default sleep settings?"; then
    print_warning "Restoring sleep settings..."
    sudo pmset -a sleep 10 disksleep 10
    print_success "Sleep settings restored to defaults (10 minutes)"
else
    print_warning "Keeping current power settings"
fi

# =============================================================================
# STEP 6: Homebrew (Optional)
# =============================================================================
print_header "STEP 6: Homebrew Cleanup (Optional)"

if command -v brew &> /dev/null; then
    echo -e "${YELLOW}Note: Homebrew may be used by many other applications.${NC}"
    echo -e "${YELLOW}Only remove if you're sure you don't need it.${NC}"
    echo ""

    if ask_confirmation "Uninstall Homebrew? (NOT RECOMMENDED)"; then
        print_warning "Uninstalling Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"

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
echo "To reinstall, choose the setup that matches your configuration:"
echo ""
echo -e "  Single device:   ${BLUE}bash <(curl -fsSL https://raw.githubusercontent.com/cediackermann/riotsecure/main/setup.sh)${NC}"
echo -e "  Ollama device:   ${BLUE}bash <(curl -fsSL https://raw.githubusercontent.com/cediackermann/riotsecure/main/setup_ollama.sh)${NC}"
echo -e "  Onyx device:     ${BLUE}bash <(curl -fsSL https://raw.githubusercontent.com/cediackermann/riotsecure/main/setup_onyx.sh)${NC}"
echo ""
