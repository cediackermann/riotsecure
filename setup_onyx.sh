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
# Bootstrap: Homebrew first (installs Xcode CLT → git), then clone the repo
# ---------------------------------------------------------------------------
if ! command -v brew &>/dev/null; then
    _info "Installing Homebrew (this also installs git via Xcode CLT)..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo >> ~/.zprofile
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
    _success "Homebrew installed"
fi

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

    # Get IPs of devices currently visible on the network from the ARP table
    local ARP_IPS
    ARP_IPS=$(arp -a 2>/dev/null | grep -v incomplete | grep -oE '\(([0-9]{1,3}\.){3}[0-9]{1,3}\)' | tr -d '()')
    if [ -z "$ARP_IPS" ]; then
        echo "" >&2
        print_warning "No devices found in ARP table." >&2
    else
        local COUNT
        COUNT=$(echo "$ARP_IPS" | wc -l | tr -d ' ')
        echo "" >&2
        print_warning "Scanning $COUNT network devices for Ollama (port 11434)..." >&2

        local TMPFILE
        TMPFILE=$(mktemp)

        while IFS= read -r ip; do
            echo -e "  ${BLUE}→${NC} Checking $ip..." >&2
            ( nc -z -w 1 "$ip" 11434 2>/dev/null && echo "$ip" >> "$TMPFILE" ) &
        done <<< "$ARP_IPS"
        wait

        local FOUND=()
        while IFS= read -r ip; do
            FOUND+=("$ip")
        done < "$TMPFILE"
        rm -f "$TMPFILE"

        if [ ${#FOUND[@]} -eq 1 ]; then
            echo "${FOUND[0]}"
            return
        elif [ ${#FOUND[@]} -gt 1 ]; then
            echo "" >&2
            print_warning "Multiple hosts with Ollama found:" >&2
            for i in "${!FOUND[@]}"; do
                echo "  $((i+1))) ${FOUND[$i]}" >&2
            done
            echo "" >&2
            read -p "Select the Ollama host (1-${#FOUND[@]}): " pick <&2
            echo "${FOUND[$((pick-1))]}"
            return
        fi

        echo "" >&2
        print_warning "Ollama not found on any network device." >&2
    fi

    # Nothing found — ask the user directly
    echo "" >&2
    read -p "Enter the IP address of the Ollama device: " manual_ip <&2
    echo "$manual_ip"
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
