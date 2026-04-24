#!/bin/bash
# Setup script for the Onyx device.
# Run this on the machine that will host the Onyx web interface.
# Docker is required on this device; Ollama is NOT installed here.
#
# Usage (one-liner):
#   bash <(curl -fsSL https://raw.githubusercontent.com/cediackermann/riotsecure/main/setup_onyx.sh)
#   bash <(curl -fsSL https://raw.githubusercontent.com/cediackermann/riotsecure/main/setup_onyx.sh) --ollama-host <IP>

set -e

# Minimal helpers needed before the repo is cloned
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
_info()    { echo -e "${BLUE}$1${NC}"; }
_success() { echo -e "${GREEN}✓ $1${NC}"; }
_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
_error()   { echo -e "${RED}✗ $1${NC}"; exit 1; }

[[ "$OSTYPE" != "darwin"* ]] && _error "This script is designed for macOS."

# Parse arguments before cloning so --ollama-host is available throughout
OLLAMA_HOST_OVERRIDE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --ollama-host)
            OLLAMA_HOST_OVERRIDE="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 [--ollama-host <IP or hostname>]"
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Clone or update the repo first so step files are available
# ---------------------------------------------------------------------------
_info "Setting up riotsecure repository..."
if [ -d ~/riotsecure ]; then
    _warning "Repository already exists — updating..."
    git -C ~/riotsecure pull
else
    git clone https://github.com/cediackermann/riotsecure.git ~/riotsecure
fi
_success "Repository ready at ~/riotsecure"

# Source all shared step files from the cloned repo
REPO="$HOME/riotsecure"
source "$REPO/steps/common.sh"
source "$REPO/steps/preflight.sh"
source "$REPO/steps/step_homebrew.sh"
source "$REPO/steps/step_docker.sh"
source "$REPO/steps/step_onyx.sh"
source "$REPO/steps/step_webconfig.sh"
source "$REPO/steps/step_rag.sh"

# ---------------------------------------------------------------------------
# Detect where Ollama is running
# ---------------------------------------------------------------------------
detect_ollama_host() {
    if curl -sf --connect-timeout 2 http://host.docker.internal:11434 >/dev/null 2>&1; then
        echo "host.docker.internal"
        return
    fi

    local LOCAL_IP
    LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")
    if [ -z "$LOCAL_IP" ]; then
        echo ""
        return
    fi

    local SUBNET
    SUBNET=$(echo "$LOCAL_IP" | cut -d. -f1-3)

    print_warning "Ollama not found locally — scanning ${SUBNET}.0/24 for Ollama..."

    local FOUND=()
    for i in $(seq 1 254); do
        if nc -z -w 1 "${SUBNET}.${i}" 11434 2>/dev/null; then
            FOUND+=("${SUBNET}.${i}")
        fi
    done

    if [ ${#FOUND[@]} -eq 1 ]; then
        echo "${FOUND[0]}"
    elif [ ${#FOUND[@]} -gt 1 ]; then
        echo "" >&2
        print_warning "Multiple hosts with Ollama found:" >&2
        for i in "${!FOUND[@]}"; do
            echo "  $((i+1))) ${FOUND[$i]}" >&2
        done
        echo "" >&2
        read -p "Select the Ollama host (1-${#FOUND[@]}): " pick >&2
        echo "${FOUND[$((pick-1))]}"
    else
        echo ""
    fi
}

# ---------------------------------------------------------------------------
# Main setup
# ---------------------------------------------------------------------------
echo ""
echo -e "${BLUE}RIoT Secure — Onyx Device Setup${NC}"
echo ""
echo "Estimated installation time: 15-30 minutes"
echo ""
echo "The following will be installed/configured:"
echo "  • Homebrew (package manager)"
echo "  • Docker Desktop (containerization)"
echo "  • Onyx (web interface)"
echo ""

preflight_checks

install_homebrew
install_docker
install_onyx

# Resolve Ollama host after Docker is running so host.docker.internal works
if [ -n "$OLLAMA_HOST_OVERRIDE" ]; then
    OLLAMA_HOST="$OLLAMA_HOST_OVERRIDE"
    echo -e "Using provided Ollama host: ${BLUE}${OLLAMA_HOST}${NC}"
else
    print_warning "Detecting Ollama host..."
    OLLAMA_HOST=$(detect_ollama_host)

    if [ -z "$OLLAMA_HOST" ]; then
        print_warning "Could not detect Ollama automatically."
        read -p "Enter the IP address or hostname of the Ollama device: " OLLAMA_HOST
    fi

    if [ "$OLLAMA_HOST" = "host.docker.internal" ]; then
        print_success "Ollama detected on this machine (single-device mode)"
    else
        print_success "Ollama detected at: ${OLLAMA_HOST}"
    fi
fi

web_config "$OLLAMA_HOST"
rag_upload

# =============================================================================
# Done
# =============================================================================
print_step "Onyx Device Setup Complete!"

echo ""
echo -e "${GREEN}✓ All automated steps completed successfully!${NC}"
echo ""
echo -e "Access the web interface at: ${BLUE}http://localhost:3000${NC}"

LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "")
if [ -n "$LOCAL_IP" ]; then
    echo -e "From other devices on the network: ${BLUE}http://${LOCAL_IP}:3000${NC}"
fi

echo ""
echo "Useful commands:"
echo "  - View Onyx logs:    cd ~/riotsecure/onyx_data && docker compose logs -f"
echo "  - Restart Onyx:      cd ~/riotsecure/onyx_data/deployment && docker compose restart"
echo ""
